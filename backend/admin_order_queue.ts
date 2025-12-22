/**
 * Admin Live Order Queue - Read Logic
 * 
 * Provides real-time order monitoring for admin dashboard.
 * Uses Firestore snapshot listeners for live updates.
 * 
 * NOTE: This is read-only logic. Order mutations are handled elsewhere.
 */

import { 
  Firestore, 
  Query,
  QuerySnapshot,
  DocumentData,
  Timestamp 
} from 'firebase-admin/firestore';

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

type OrderStatus = 'pending' | 'confirmed' | 'preparing' | 'ready' | 'completed' | 'cancelled';

interface OrderQueueItem {
  orderId: string;
  userId: string;
  userName: string;
  
  items: {
    itemName: string;
    quantity: number;
    price: number;
  }[];
  
  totalAmount: number;
  
  slotId: string;
  estimatedPickupTime: Timestamp;
  
  status: OrderStatus;
  placedAt: Timestamp;
  confirmedAt: Timestamp | null;
  readyAt: Timestamp | null;
  completedAt: Timestamp | null;
  
  pickupVerified: boolean;
  pickupVerifiedAt: Timestamp | null;
  
  cancellationReason: string | null;
}

interface OrdersByStatus {
  pending: OrderQueueItem[];      // Just placed, awaiting confirmation
  confirmed: OrderQueueItem[];    // Confirmed, not yet being prepared
  preparing: OrderQueueItem[];    // Currently being prepared
  ready: OrderQueueItem[];        // Ready for pickup
  completed: OrderQueueItem[];    // Picked up (for reference)
  cancelled: OrderQueueItem[];    // Cancelled orders
}

interface QueueStats {
  total: number;
  pending: number;
  confirmed: number;
  preparing: number;
  ready: number;
  completed: number;
  cancelled: number;
  activeOrders: number;  // pending + confirmed + preparing + ready
}

// ============================================================================
// MAIN QUERY FUNCTIONS
// ============================================================================

/**
 * Fetches all orders for today (snapshot - no real-time).
 * Useful for initial load or one-time queries.
 * 
 * @param db - Firestore instance
 * @param statusFilter - Optional: filter by specific status
 * @returns Array of orders sorted by placedAt (oldest first)
 */
export async function fetchTodaysOrders(
  db: Firestore,
  statusFilter?: OrderStatus
): Promise<OrderQueueItem[]> {
  
  const todayStart = getTodayStartTimestamp();
  const todayEnd = getTodayEndTimestamp();

  // Build query
  let query: Query<DocumentData> = db.collection('orders')
    .where('placedAt', '>=', todayStart)
    .where('placedAt', '<', todayEnd)
    .orderBy('placedAt', 'asc');  // Oldest orders first

  // Apply status filter if provided
  if (statusFilter) {
    query = db.collection('orders')
      .where('placedAt', '>=', todayStart)
      .where('placedAt', '<', todayEnd)
      .where('status', '==', statusFilter)
      .orderBy('placedAt', 'asc');
  }

  // TODO: Add pagination support for high-volume days
  // Current implementation loads all orders - may not scale beyond ~500 orders/day

  const snapshot = await query.get();

  if (snapshot.empty) {
    return [];
  }

  // Map documents to typed objects
  const orders: OrderQueueItem[] = snapshot.docs.map(doc => ({
    orderId: doc.id,
    ...doc.data()
  } as OrderQueueItem));

  return orders;
}

/**
 * Fetches orders grouped by status.
 * Useful for admin dashboard sections (Pending, Preparing, Ready, etc.)
 * 
 * @param db - Firestore instance
 * @returns Orders organized by status
 */
export async function fetchOrdersByStatus(
  db: Firestore
): Promise<OrdersByStatus> {
  
  // Fetch all today's orders
  const allOrders = await fetchTodaysOrders(db);

  // Group by status
  const grouped: OrdersByStatus = {
    pending: [],
    confirmed: [],
    preparing: [],
    ready: [],
    completed: [],
    cancelled: []
  };

  for (const order of allOrders) {
    grouped[order.status].push(order);
  }

  return grouped;
}

/**
 * Calculates queue statistics for dashboard metrics.
 * 
 * @param orders - Orders grouped by status
 * @returns Summary statistics
 */
export function calculateQueueStats(orders: OrdersByStatus): QueueStats {
  return {
    total: Object.values(orders).flat().length,
    pending: orders.pending.length,
    confirmed: orders.confirmed.length,
    preparing: orders.preparing.length,
    ready: orders.ready.length,
    completed: orders.completed.length,
    cancelled: orders.cancelled.length,
    activeOrders: orders.pending.length + orders.confirmed.length + 
                  orders.preparing.length + orders.ready.length
  };
}

// ============================================================================
// REAL-TIME LISTENER FUNCTIONS
// ============================================================================

/**
 * Sets up a real-time listener for today's orders.
 * 
 * HOW IT WORKS:
 * - Firestore onSnapshot() creates a persistent connection
 * - Any changes to matching documents trigger the callback
 * - Changes include: new orders, status updates, deletions
 * - Listener remains active until unsubscribe() is called
 * 
 * PERFORMANCE:
 * - Initial snapshot loads all matching documents
 * - Subsequent updates only send changed documents
 * - Bandwidth-efficient for real-time monitoring
 * 
 * @param db - Firestore instance
 * @param callback - Function called whenever orders change
 * @param statusFilter - Optional: only listen to specific status
 * @returns Unsubscribe function to stop listening
 */
export function listenToTodaysOrders(
  db: Firestore,
  callback: (orders: OrderQueueItem[], error?: Error) => void,
  statusFilter?: OrderStatus
): () => void {
  
  const todayStart = getTodayStartTimestamp();
  const todayEnd = getTodayEndTimestamp();

  // Build query (same as fetch, but with listener)
  let query: Query<DocumentData> = db.collection('orders')
    .where('placedAt', '>=', todayStart)
    .where('placedAt', '<', todayEnd)
    .orderBy('placedAt', 'asc');

  if (statusFilter) {
    query = db.collection('orders')
      .where('placedAt', '>=', todayStart)
      .where('placedAt', '<', todayEnd)
      .where('status', '==', statusFilter)
      .orderBy('placedAt', 'asc');
  }

  // Set up real-time listener
  const unsubscribe = query.onSnapshot(
    (snapshot: QuerySnapshot<DocumentData>) => {
      // Map documents to typed objects
      const orders: OrderQueueItem[] = snapshot.docs.map(doc => ({
        orderId: doc.id,
        ...doc.data()
      } as OrderQueueItem));

      // Call the callback with updated orders
      callback(orders);
    },
    (error: Error) => {
      // Handle errors (permissions, network issues, etc.)
      console.error('Real-time listener error:', error);
      callback([], error);
    }
  );

  // Return unsubscribe function
  // IMPORTANT: Must be called when component unmounts or listener is no longer needed
  return unsubscribe;
}

/**
 * Sets up real-time listeners for all status groups.
 * Useful for dashboard with separate sections for each status.
 * 
 * UPDATES TRIGGERED BY:
 * - New order placed → callback fires with new order in 'pending'
 * - Status changed → order moves from one group to another
 * - Order cancelled → appears in 'cancelled' group
 * - Order completed → moves to 'completed' group
 * 
 * @param db - Firestore instance
 * @param callback - Called with grouped orders whenever any order changes
 * @returns Unsubscribe function to stop all listeners
 */
export function listenToOrdersByStatus(
  db: Firestore,
  callback: (orders: OrdersByStatus, error?: Error) => void
): () => void {
  
  // We'll collect all orders and group them
  // Using a single listener is more efficient than 6 separate listeners
  const todayStart = getTodayStartTimestamp();
  const todayEnd = getTodayEndTimestamp();

  const query = db.collection('orders')
    .where('placedAt', '>=', todayStart)
    .where('placedAt', '<', todayEnd)
    .orderBy('placedAt', 'asc');

  const unsubscribe = query.onSnapshot(
    (snapshot: QuerySnapshot<DocumentData>) => {
      const allOrders: OrderQueueItem[] = snapshot.docs.map(doc => ({
        orderId: doc.id,
        ...doc.data()
      } as OrderQueueItem));

      // Group by status
      const grouped: OrdersByStatus = {
        pending: [],
        confirmed: [],
        preparing: [],
        ready: [],
        completed: [],
        cancelled: []
      };

      for (const order of allOrders) {
        grouped[order.status].push(order);
      }

      // Call callback with grouped orders
      callback(grouped);
    },
    (error: Error) => {
      console.error('Real-time listener error:', error);
      
      // Return empty groups on error
      const emptyGroups: OrdersByStatus = {
        pending: [],
        confirmed: [],
        preparing: [],
        ready: [],
        completed: [],
        cancelled: []
      };
      
      callback(emptyGroups, error);
    }
  );

  return unsubscribe;
}

/**
 * Sets up a real-time listener for ACTIVE orders only.
 * Active = pending, confirmed, preparing, or ready (excludes completed/cancelled).
 * 
 * This is more efficient than listening to all orders when you only care about
 * orders that need attention.
 * 
 * NOTE: Firestore doesn't support "NOT IN" queries efficiently, so we listen
 * to all orders and filter client-side. For high volumes, consider separate
 * listeners per active status.
 * 
 * @param db - Firestore instance
 * @param callback - Called with active orders
 * @returns Unsubscribe function
 */
export function listenToActiveOrders(
  db: Firestore,
  callback: (orders: OrderQueueItem[], error?: Error) => void
): () => void {
  
  const todayStart = getTodayStartTimestamp();
  const todayEnd = getTodayEndTimestamp();

  // TODO: For better performance with high order volume, consider using
  // separate listeners for each active status and merging results
  
  const query = db.collection('orders')
    .where('placedAt', '>=', todayStart)
    .where('placedAt', '<', todayEnd)
    .orderBy('placedAt', 'asc');

  const unsubscribe = query.onSnapshot(
    (snapshot: QuerySnapshot<DocumentData>) => {
      const allOrders: OrderQueueItem[] = snapshot.docs.map(doc => ({
        orderId: doc.id,
        ...doc.data()
      } as OrderQueueItem));

      // Filter to active orders only
      const activeOrders = allOrders.filter(order => 
        order.status === 'pending' ||
        order.status === 'confirmed' ||
        order.status === 'preparing' ||
        order.status === 'ready'
      );

      callback(activeOrders);
    },
    (error: Error) => {
      console.error('Real-time listener error:', error);
      callback([], error);
    }
  );

  return unsubscribe;
}

/**
 * Listens to a single order by ID.
 * Useful for order detail views that need real-time status updates.
 * 
 * @param db - Firestore instance
 * @param orderId - The order ID to listen to
 * @param callback - Called when order changes
 * @returns Unsubscribe function
 */
export function listenToSingleOrder(
  db: Firestore,
  orderId: string,
  callback: (order: OrderQueueItem | null, error?: Error) => void
): () => void {
  
  const orderRef = db.collection('orders').doc(orderId);

  const unsubscribe = orderRef.onSnapshot(
    (doc) => {
      if (!doc.exists) {
        callback(null);
        return;
      }

      const order: OrderQueueItem = {
        orderId: doc.id,
        ...doc.data()
      } as OrderQueueItem;

      callback(order);
    },
    (error: Error) => {
      console.error('Order listener error:', error);
      callback(null, error);
    }
  );

  return unsubscribe;
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * Gets timestamp for start of today (00:00:00).
 */
function getTodayStartTimestamp(): Timestamp {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
  return Timestamp.fromDate(todayStart);
}

/**
 * Gets timestamp for end of today (23:59:59.999).
 */
function getTodayEndTimestamp(): Timestamp {
  const now = new Date();
  const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
  return Timestamp.fromDate(todayEnd);
}

/**
 * Formats order for display (helper for UI layer).
 * This is optional - UI can format however it needs.
 */
export function formatOrderForDisplay(order: OrderQueueItem): {
  orderNumber: string;
  customerName: string;
  itemsSummary: string;
  pickupTime: string;
  status: string;
  waitTime: string;
} {
  // Generate short order number (last 6 chars of ID)
  const orderNumber = '#' + order.orderId.substring(order.orderId.length - 6).toUpperCase();

  // Create items summary (e.g., "2x Dosa, 1x Chai")
  const itemsSummary = order.items
    .map(item => `${item.quantity}x ${item.itemName}`)
    .join(', ');

  // Format pickup time
  const pickupTime = formatTimestamp(order.estimatedPickupTime);

  // Calculate wait time
  const waitTime = calculateWaitTime(order.placedAt);

  // Format status for display
  const statusDisplay = formatStatus(order.status);

  return {
    orderNumber,
    customerName: order.userName,
    itemsSummary,
    pickupTime,
    status: statusDisplay,
    waitTime
  };
}

/**
 * Formats a Timestamp to human-readable time.
 */
function formatTimestamp(timestamp: Timestamp): string {
  const date = timestamp.toDate();
  const hours = date.getHours();
  const minutes = date.getMinutes();
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 || 12;
  const displayMinutes = minutes.toString().padStart(2, '0');
  
  return `${displayHours}:${displayMinutes} ${ampm}`;
}

/**
 * Calculates time elapsed since order was placed.
 */
function calculateWaitTime(placedAt: Timestamp): string {
  const now = Timestamp.now();
  const diffMs = now.toMillis() - placedAt.toMillis();
  const diffMinutes = Math.floor(diffMs / 60000);

  if (diffMinutes < 1) {
    return 'Just now';
  } else if (diffMinutes === 1) {
    return '1 min ago';
  } else if (diffMinutes < 60) {
    return `${diffMinutes} mins ago`;
  } else {
    const hours = Math.floor(diffMinutes / 60);
    const mins = diffMinutes % 60;
    return `${hours}h ${mins}m ago`;
  }
}

/**
 * Formats status enum for display.
 */
function formatStatus(status: OrderStatus): string {
  const statusMap: Record<OrderStatus, string> = {
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'preparing': 'Preparing',
    'ready': 'Ready for Pickup',
    'completed': 'Completed',
    'cancelled': 'Cancelled'
  };

  return statusMap[status] || status;
}

// ============================================================================
// FIRESTORE INDEX REQUIREMENTS
// ============================================================================

/*
 * REQUIRED INDEXES (add to firestore.indexes.json):
 * 
 * 1. Query orders by date and status:
 *    Collection: orders
 *    Fields: placedAt (Ascending), status (Ascending)
 * 
 * 2. Query orders by date only:
 *    Collection: orders  
 *    Fields: placedAt (Ascending)
 * 
 * 3. Query active orders efficiently (if using separate status queries):
 *    Collection: orders
 *    Fields: status (Ascending), placedAt (Ascending)
 * 
 * Firestore will prompt to create these indexes when queries are first run.
 * 
 * TODO: Add composite index for (date, status, placedAt) if filtering by
 * date range AND status becomes a common pattern.
 */

// ============================================================================
// USAGE EXAMPLES (for documentation)
// ============================================================================

/*
// Example 1: Fetch orders once
const orders = await fetchTodaysOrders(db);
console.log(`Total orders today: ${orders.length}`);

// Example 2: Fetch orders by status
const ordersByStatus = await fetchOrdersByStatus(db);
const stats = calculateQueueStats(ordersByStatus);
console.log(`Active orders: ${stats.activeOrders}`);

// Example 3: Real-time listener for all orders
const unsubscribe = listenToTodaysOrders(db, (orders, error) => {
  if (error) {
    console.error('Error:', error);
    return;
  }
  
  console.log(`Orders updated: ${orders.length} total`);
  // Update UI with new orders
});

// Clean up when done
unsubscribe();

// Example 4: Real-time listener for orders grouped by status
const unsubscribe2 = listenToOrdersByStatus(db, (grouped, error) => {
  if (error) {
    console.error('Error:', error);
    return;
  }
  
  console.log(`Preparing: ${grouped.preparing.length}`);
  console.log(`Ready: ${grouped.ready.length}`);
  // Update dashboard sections
});

// Example 5: Listen to active orders only
const unsubscribe3 = listenToActiveOrders(db, (activeOrders) => {
  console.log(`Active orders: ${activeOrders.length}`);
  // Show only orders that need attention
});

// Example 6: Listen to single order details
const unsubscribe4 = listenToSingleOrder(db, 'order123', (order) => {
  if (order) {
    console.log(`Order status: ${order.status}`);
  }
});
*/

// ============================================================================
// EXPORTS
// ============================================================================

export {
  OrderStatus,
  OrderQueueItem,
  OrdersByStatus,
  QueueStats
};
