/**
 * Order Creation Flow
 * 
 * Handles atomic order placement with slot assignment and capacity checks.
 * This code is designed to be wrapped in a Cloud Function or called from client.
 * 
 * NOTE: For demo purposes, this can run client-side with Firestore SDK.
 * For production, move to Cloud Functions for better security.
 */

import { 
  Firestore, 
  Transaction, 
  Timestamp,
  DocumentReference 
} from 'firebase-admin/firestore';

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

interface OrderItem {
  itemName: string;
  quantity: number;
  price: number;
}

interface CreateOrderRequest {
  userId: string;
  userName: string;
  items: OrderItem[];
  preferredSlotId?: string;  // Optional - if user selected specific slot
}

interface CreateOrderResponse {
  success: boolean;
  orderId?: string;
  slotId?: string;
  estimatedPickupTime?: Timestamp;
  message: string;
  error?: {
    code: string;
    reason: string;
  };
}

interface OrderSlot {
  slotId: string;
  date: string;
  startTime: Timestamp;
  endTime: Timestamp;
  maxCapacity: number;
  currentCount: number;
  status: 'open' | 'full' | 'closed';
  autoClosedAt: Timestamp | null;
  manuallyClosedBy: string | null;
  createdAt: Timestamp;
}

interface GlobalSettings {
  orderingPaused: boolean;
  pausedByAdminId: string | null;
  pauseReason: string | null;
  canteenOpenTime: string;
  canteenCloseTime: string;
  lastOrderTime: string;
  maxConcurrentOrders: number;
  slotBufferTimeMinutes: number;
}

// ============================================================================
// MAIN ORDER CREATION FUNCTION
// ============================================================================

/**
 * Creates a new order with atomic slot assignment.
 * 
 * Flow:
 * 1. Pre-check global cut-off conditions
 * 2. Find available slot
 * 3. Use Firestore transaction to atomically:
 *    - Re-check slot capacity
 *    - Increment slot counter
 *    - Create order document
 * 4. Return success or clear failure reason
 */
export async function createOrder(
  db: Firestore,
  request: CreateOrderRequest
): Promise<CreateOrderResponse> {
  
  // STEP 1: Validate input
  if (!request.userId || !request.userName || !request.items || request.items.length === 0) {
    return {
      success: false,
      message: 'Invalid order data. Please check your order and try again.',
      error: {
        code: 'INVALID_INPUT',
        reason: 'Missing required fields'
      }
    };
  }

  // STEP 2: Check global cut-off conditions (non-transactional pre-check)
  const cutoffCheck = await checkGlobalCutoff(db);
  if (!cutoffCheck.isOpen) {
    return {
      success: false,
      message: cutoffCheck.message,
      error: {
        code: cutoffCheck.reason,
        reason: cutoffCheck.message
      }
    };
  }

  // STEP 3: Find available slot
  let targetSlot: OrderSlot | null = null;
  
  if (request.preferredSlotId) {
    // User specified a slot - validate it
    targetSlot = await getSlotById(db, request.preferredSlotId);
    
    if (!targetSlot) {
      return {
        success: false,
        message: 'Selected slot not found. Please choose another time.',
        error: {
          code: 'SLOT_NOT_FOUND',
          reason: 'Invalid slot ID'
        }
      };
    }
    
    // Check if preferred slot is viable (not past, not too soon)
    const slotCheck = checkSlotViability(targetSlot);
    if (!slotCheck.isViable) {
      // Fall back to next available slot
      targetSlot = await findNextAvailableSlot(db);
    }
  } else {
    // Auto-assign to next available slot
    targetSlot = await findNextAvailableSlot(db);
  }

  // No slots available
  if (!targetSlot) {
    return {
      success: false,
      message: 'No pickup slots available. Please try again later.',
      error: {
        code: 'NO_AVAILABLE_SLOTS',
        reason: 'All slots are full or closed'
      }
    };
  }

  // STEP 4: Attempt to create order with transaction
  // This ensures atomicity and handles race conditions
  try {
    const result = await db.runTransaction(async (transaction) => {
      return await createOrderTransaction(db, transaction, request, targetSlot!);
    });

    return result;

  } catch (error: any) {
    // Transaction failed - check if it's a retry-able error
    if (error.code === 'SLOT_FULL_RACE') {
      // Slot filled up during our check - try next slot
      const nextSlot = await findNextAvailableSlot(db, targetSlot.slotId);
      
      if (!nextSlot) {
        return {
          success: false,
          message: 'All slots filled up. Please try again in a few minutes.',
          error: {
            code: 'ALL_SLOTS_FULL',
            reason: 'Race condition: slots filled during order placement'
          }
        };
      }

      // TODO: Add max retry limit to prevent infinite loops
      // Retry with next slot
      try {
        const retryResult = await db.runTransaction(async (transaction) => {
          return await createOrderTransaction(db, transaction, request, nextSlot);
        });
        return retryResult;
      } catch (retryError: any) {
        return {
          success: false,
          message: 'Unable to place order. Please try again.',
          error: {
            code: 'TRANSACTION_FAILED',
            reason: retryError.message || 'Transaction failed after retry'
          }
        };
      }
    }

    // Unexpected error
    console.error('Order creation failed:', error);
    return {
      success: false,
      message: 'An error occurred while placing your order. Please try again.',
      error: {
        code: 'UNKNOWN_ERROR',
        reason: error.message || 'Unknown error'
      }
    };
  }
}

// ============================================================================
// TRANSACTION LOGIC
// ============================================================================

/**
 * Creates order inside a Firestore transaction.
 * 
 * CRITICAL: This function must be idempotent and handle race conditions.
 * Multiple transactions may attempt to book the same slot simultaneously.
 */
async function createOrderTransaction(
  db: Firestore,
  transaction: Transaction,
  request: CreateOrderRequest,
  targetSlot: OrderSlot
): Promise<CreateOrderResponse> {
  
  // Re-fetch slot inside transaction for latest state
  const slotRef = db.collection('orderSlots').doc(targetSlot.slotId);
  const slotDoc = await transaction.get(slotRef);
  
  if (!slotDoc.exists) {
    throw {
      code: 'SLOT_NOT_FOUND',
      message: 'Slot disappeared during transaction'
    };
  }

  const freshSlot = slotDoc.data() as OrderSlot;

  // DOUBLE-CHECK: Verify slot still has capacity
  if (freshSlot.currentCount >= freshSlot.maxCapacity) {
    throw {
      code: 'SLOT_FULL_RACE',
      message: 'Slot filled up during order placement'
    };
  }

  // DOUBLE-CHECK: Verify slot is still open
  if (freshSlot.status === 'closed') {
    throw {
      code: 'SLOT_CLOSED',
      message: 'Slot was closed during order placement'
    };
  }

  // Calculate total amount
  const totalAmount = request.items.reduce((sum, item) => {
    return sum + (item.price * item.quantity);
  }, 0);

  // Create new order document
  const orderRef = db.collection('orders').doc();
  const now = Timestamp.now();

  const newOrder = {
    orderId: orderRef.id,
    userId: request.userId,
    userName: request.userName,
    
    items: request.items,
    totalAmount: totalAmount,
    
    slotId: freshSlot.slotId,
    estimatedPickupTime: freshSlot.startTime,
    
    status: 'pending',
    placedAt: now,
    confirmedAt: null,
    readyAt: null,
    completedAt: null,
    
    pickupVerified: false,
    pickupVerifiedAt: null,
    
    cancellationReason: null
  };

  // Update slot count
  const newSlotCount = freshSlot.currentCount + 1;
  const slotUpdates: Partial<OrderSlot> = {
    currentCount: newSlotCount
  };

  // Auto-close slot if it reached capacity
  if (newSlotCount >= freshSlot.maxCapacity) {
    slotUpdates.status = 'full';
    slotUpdates.autoClosedAt = now;
  }

  // Atomic writes
  transaction.set(orderRef, newOrder);
  transaction.update(slotRef, slotUpdates);

  // Return success response
  return {
    success: true,
    orderId: orderRef.id,
    slotId: freshSlot.slotId,
    estimatedPickupTime: freshSlot.startTime,
    message: `Order placed successfully! Pickup at ${formatTime(freshSlot.startTime)}`
  };
}

// ============================================================================
// HELPER FUNCTIONS - CUT-OFF CHECKS
// ============================================================================

/**
 * Checks global system-level conditions before allowing order placement.
 * This is a non-transactional pre-check for performance.
 */
async function checkGlobalCutoff(db: Firestore): Promise<{
  isOpen: boolean;
  reason: string;
  message: string;
}> {
  
  // Fetch global settings
  const settingsRef = db.collection('globalSettings').doc('config');
  const settingsDoc = await settingsRef.get();
  
  if (!settingsDoc.exists) {
    // TODO: Create default settings if document doesn't exist
    console.warn('Global settings not found. Using defaults.');
    // For now, assume system is open
    return {
      isOpen: true,
      reason: 'DEFAULT',
      message: 'System operational'
    };
  }

  const settings = settingsDoc.data() as GlobalSettings;

  // CHECK 1: Manual admin pause
  if (settings.orderingPaused) {
    return {
      isOpen: false,
      reason: 'ADMIN_PAUSED',
      message: settings.pauseReason || 'Ordering temporarily paused. Please try again later.'
    };
  }

  // CHECK 2: Operating hours
  const now = new Date();
  const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
  
  if (currentTime < settings.canteenOpenTime) {
    return {
      isOpen: false,
      reason: 'NOT_OPEN_YET',
      message: `Canteen opens at ${settings.canteenOpenTime}. Come back soon!`
    };
  }

  if (currentTime >= settings.lastOrderTime) {
    return {
      isOpen: false,
      reason: 'CLOSED_FOR_DAY',
      message: `Order placement closed for today. We reopen at ${settings.canteenOpenTime} tomorrow.`
    };
  }

  // CHECK 3: Overall kitchen capacity
  const activeOrdersSnapshot = await db.collection('orders')
    .where('status', 'in', ['pending', 'preparing'])
    .get();
  
  const activeOrderCount = activeOrdersSnapshot.size;

  if (activeOrderCount >= settings.maxConcurrentOrders) {
    return {
      isOpen: false,
      reason: 'KITCHEN_OVERLOADED',
      message: 'Kitchen at full capacity. Please try again in 10-15 minutes.'
    };
  }

  // All checks passed
  return {
    isOpen: true,
    reason: 'AVAILABLE',
    message: 'System accepting orders'
  };
}

/**
 * Checks if a specific slot is viable for order assignment.
 * Does NOT check capacity (that's done in transaction).
 */
function checkSlotViability(slot: OrderSlot): {
  isViable: boolean;
  reason: string;
} {
  
  const now = Timestamp.now();

  // Check 1: Slot is in the past
  if (slot.startTime.toMillis() < now.toMillis()) {
    return {
      isViable: false,
      reason: 'SLOT_EXPIRED'
    };
  }

  // Check 2: Slot is too soon (buffer time)
  // TODO: Make buffer time configurable from globalSettings
  const bufferMinutes = 15;
  const bufferMillis = bufferMinutes * 60 * 1000;
  const cutoffTime = slot.startTime.toMillis() - bufferMillis;

  if (now.toMillis() > cutoffTime) {
    return {
      isViable: false,
      reason: 'SLOT_TOO_SOON'
    };
  }

  // Check 3: Manually closed
  if (slot.status === 'closed' && slot.manuallyClosedBy !== null) {
    return {
      isViable: false,
      reason: 'MANUALLY_CLOSED'
    };
  }

  return {
    isViable: true,
    reason: 'VIABLE'
  };
}

// ============================================================================
// HELPER FUNCTIONS - SLOT QUERIES
// ============================================================================

/**
 * Retrieves a slot by ID.
 */
async function getSlotById(db: Firestore, slotId: string): Promise<OrderSlot | null> {
  const slotRef = db.collection('orderSlots').doc(slotId);
  const slotDoc = await slotRef.get();
  
  if (!slotDoc.exists) {
    return null;
  }

  return {
    slotId: slotDoc.id,
    ...slotDoc.data()
  } as OrderSlot;
}

/**
 * Finds the next available slot that:
 * - Is today or future
 * - Hasn't started yet (or is within buffer time)
 * - Has available capacity
 * - Is open status
 */
async function findNextAvailableSlot(
  db: Firestore,
  afterSlotId?: string
): Promise<OrderSlot | null> {
  
  const now = Timestamp.now();
  const today = getTodayDateString();

  // Query for open slots starting from now
  // TODO: Add index on (date, startTime, status, currentCount)
  let query = db.collection('orderSlots')
    .where('date', '>=', today)
    .where('status', '==', 'open')
    .orderBy('date', 'asc')
    .orderBy('startTime', 'asc')
    .limit(10);  // Get first 10 slots to check

  const snapshot = await query.get();

  if (snapshot.empty) {
    return null;
  }

  // Find first slot that meets all criteria
  let skipUntilAfter = afterSlotId ? true : false;

  for (const doc of snapshot.docs) {
    const slot = {
      slotId: doc.id,
      ...doc.data()
    } as OrderSlot;

    // Skip slots until we pass the afterSlotId
    if (skipUntilAfter) {
      if (slot.slotId === afterSlotId) {
        skipUntilAfter = false;
      }
      continue;
    }

    // Check viability
    const viability = checkSlotViability(slot);
    if (!viability.isViable) {
      continue;
    }

    // Check capacity (pre-check, will re-check in transaction)
    if (slot.currentCount >= slot.maxCapacity) {
      continue;
    }

    // Found a good slot
    return slot;
  }

  // No available slots found
  return null;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Formats a timestamp for display.
 * Example: "2:30 PM"
 */
function formatTime(timestamp: Timestamp): string {
  const date = timestamp.toDate();
  const hours = date.getHours();
  const minutes = date.getMinutes();
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 || 12;
  const displayMinutes = minutes.toString().padStart(2, '0');
  
  return `${displayHours}:${displayMinutes} ${ampm}`;
}

/**
 * Gets today's date as YYYY-MM-DD string.
 */
function getTodayDateString(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = (now.getMonth() + 1).toString().padStart(2, '0');
  const day = now.getDate().toString().padStart(2, '0');
  
  return `${year}-${month}-${day}`;
}

// ============================================================================
// EXPORTS
// ============================================================================

export {
  CreateOrderRequest,
  CreateOrderResponse,
  OrderItem,
  OrderSlot,
  GlobalSettings
};
