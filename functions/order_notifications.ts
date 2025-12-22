/**
 * Cloud Function: Notify Student on Order Ready
 * 
 * Triggers when an order document is updated in Firestore.
 * Sends FCM notification to student when order status changes to READY.
 * 
 * Deployment: firebase deploy --only functions:notifyOrderReady
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { Timestamp } from 'firebase-admin/firestore';

// Initialize Firebase Admin (only once per function deployment)
admin.initializeApp();

// ============================================================================
// TYPE DEFINITIONS
// ============================================================================

interface OrderData {
  orderId: string;
  userId: string;
  userName: string;
  status: 'pending' | 'confirmed' | 'preparing' | 'ready' | 'completed' | 'cancelled';
  slotId: string;
  estimatedPickupTime: Timestamp;
  items: {
    itemName: string;
    quantity: number;
    price: number;
  }[];
  placedAt: Timestamp;
}

interface UserData {
  userId: string;
  name: string;
  email: string;
  fcmToken?: string;  // Device token for push notifications
  role: string;
}

// ============================================================================
// CLOUD FUNCTION: Order Status Change Handler
// ============================================================================

/**
 * Firestore trigger that runs when any order document is updated.
 * 
 * TRIGGER PATTERN:
 * - Runs on every order document write (create, update, delete)
 * - We filter for specific status transitions inside the function
 * - More efficient than client-side listeners for notifications
 * 
 * SECURITY:
 * - Runs with admin privileges (bypasses Firestore security rules)
 * - No user authentication needed - triggered by database events
 */
export const notifyOrderReady = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    
    // STEP 1: Extract before and after states
    const beforeData = change.before.data() as OrderData;
    const afterData = change.after.data() as OrderData;
    const orderId = context.params.orderId;

    // STEP 2: Check if status changed from PREPARING → READY
    // This is the only transition we care about for this notification
    if (beforeData.status !== 'preparing' || afterData.status !== 'ready') {
      // Status didn't change to ready, or wasn't preparing before
      // Exit early to save execution time
      console.log(`Order ${orderId}: Status change ${beforeData.status} → ${afterData.status}, skipping notification`);
      return null;
    }

    console.log(`Order ${orderId}: Status changed to READY, sending notification to user ${afterData.userId}`);

    // STEP 3: Fetch user's FCM device token
    let fcmToken: string | undefined;
    
    try {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(afterData.userId)
        .get();

      if (!userDoc.exists) {
        console.error(`Order ${orderId}: User ${afterData.userId} not found in database`);
        // TODO: Add fallback notification method (email/SMS) if user exists but no FCM token
        return null;
      }

      const userData = userDoc.data() as UserData;
      fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.warn(`Order ${orderId}: User ${afterData.userId} has no FCM token registered`);
        // TODO: Handle users without FCM token
        // Options:
        // 1. Store notification in database for later retrieval
        // 2. Send email notification as fallback
        // 3. Flag user for re-registration
        return null;
      }

    } catch (error) {
      console.error(`Order ${orderId}: Error fetching user data:`, error);
      return null;
    }

    // STEP 4: Build notification payload
    const pickupTime = formatPickupTime(afterData.estimatedPickupTime);
    const itemsSummary = buildItemsSummary(afterData.items);
    
    const notification = {
      title: '🍽️ Your Order is Ready!',
      body: `${itemsSummary} - Pickup by ${pickupTime}`,
    };

    // Data payload (available to app even when notification is not tapped)
    const data = {
      orderId: orderId,
      type: 'ORDER_READY',
      slotId: afterData.slotId,
      pickupTime: afterData.estimatedPickupTime.toMillis().toString(),
      // Include timestamp for client-side sorting
      timestamp: Timestamp.now().toMillis().toString()
    };

    // STEP 5: Send notification via FCM
    try {
      const message = {
        token: fcmToken,
        notification: notification,
        data: data,
        // Android-specific options
        android: {
          priority: 'high' as const,
          notification: {
            sound: 'default',
            channelId: 'order_updates',  // App must create this channel
            priority: 'high' as const,
            // TODO: Add custom sound for ready notification if desired
          }
        },
        // iOS-specific options
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,  // Increment app badge
              // TODO: Define badge count strategy (increment vs. total pending orders)
            }
          }
        }
      };

      const response = await admin.messaging().send(message);
      console.log(`Order ${orderId}: Notification sent successfully. Response:`, response);

      // TODO: Log notification delivery to database for analytics
      // Could track: sent_at, delivered_at, opened_at, etc.

      return response;

    } catch (error: any) {
      // FCM send failed - log error
      console.error(`Order ${orderId}: Failed to send notification:`, error);

      // Common FCM errors:
      // - Invalid token (user uninstalled app)
      // - Token expired
      // - Network issues
      
      if (error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered') {
        console.warn(`Order ${orderId}: Invalid FCM token for user ${afterData.userId}, should remove from database`);
        // TODO: Remove invalid FCM token from user document
        // await admin.firestore().collection('users').doc(afterData.userId).update({
        //   fcmToken: admin.firestore.FieldValue.delete()
        // });
      }

      // For hackathon: simple logging is enough
      // Production: retry queue, alerting, etc.
      return null;
    }
  });

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Formats pickup time for notification display.
 * Example: "2:30 PM"
 */
function formatPickupTime(timestamp: Timestamp): string {
  const date = timestamp.toDate();
  const hours = date.getHours();
  const minutes = date.getMinutes();
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 || 12;
  const displayMinutes = minutes.toString().padStart(2, '0');
  
  return `${displayHours}:${displayMinutes} ${ampm}`;
}

/**
 * Builds a short summary of order items for notification.
 * Example: "2x Dosa, 1x Chai, 1x Samosa"
 * 
 * Limits to 3 items to keep notification concise.
 */
function buildItemsSummary(items: OrderData['items']): string {
  const MAX_ITEMS = 3;
  
  const itemStrings = items
    .slice(0, MAX_ITEMS)
    .map(item => `${item.quantity}x ${item.itemName}`);
  
  if (items.length > MAX_ITEMS) {
    itemStrings.push(`+${items.length - MAX_ITEMS} more`);
  }
  
  return itemStrings.join(', ');
}

// ============================================================================
// ADDITIONAL NOTIFICATION FUNCTIONS (Optional)
// ============================================================================

/**
 * Optional: Notify when order is confirmed (PENDING → CONFIRMED).
 * Can be enabled by uncommenting and deploying.
 */
/*
export const notifyOrderConfirmed = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    
    const beforeData = change.before.data() as OrderData;
    const afterData = change.after.data() as OrderData;
    const orderId = context.params.orderId;

    // Check for PENDING → CONFIRMED transition
    if (beforeData.status !== 'pending' || afterData.status !== 'confirmed') {
      return null;
    }

    // Fetch user FCM token
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(afterData.userId)
      .get();

    if (!userDoc.exists) {
      return null;
    }

    const userData = userDoc.data() as UserData;
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      return null;
    }

    // Send notification
    const pickupTime = formatPickupTime(afterData.estimatedPickupTime);
    
    const message = {
      token: fcmToken,
      notification: {
        title: '✅ Order Confirmed',
        body: `Your order has been confirmed. Pickup at ${pickupTime}`,
      },
      data: {
        orderId: orderId,
        type: 'ORDER_CONFIRMED',
        pickupTime: afterData.estimatedPickupTime.toMillis().toString()
      }
    };

    try {
      await admin.messaging().send(message);
      console.log(`Order ${orderId}: Confirmation notification sent`);
    } catch (error) {
      console.error(`Order ${orderId}: Failed to send confirmation:`, error);
    }

    return null;
  });
*/

// ============================================================================
// FIRESTORE SCHEMA ADDITION NEEDED
// ============================================================================

/*
 * Add to users collection schema:
 * 
 * {
 *   userId: string,
 *   name: string,
 *   email: string,
 *   phoneNumber: string,
 *   role: string,
 *   rfidTag: string | null,
 *   
 *   // NEW FIELDS FOR NOTIFICATIONS:
 *   fcmToken: string | null,           // Device FCM registration token
 *   fcmTokenUpdatedAt: timestamp,      // When token was last updated
 *   notificationsEnabled: boolean,     // User preference
 *   
 *   createdAt: timestamp,
 *   isActive: boolean
 * }
 * 
 * Client app must:
 * 1. Request notification permission from user
 * 2. Get FCM token using Firebase Messaging SDK
 * 3. Save token to user document on login/app start
 * 4. Update token when it refreshes (FCM tokens can change)
 */

// ============================================================================
// DEPLOYMENT NOTES
// ============================================================================

/*
 * BEFORE DEPLOYING:
 * 
 * 1. Install dependencies:
 *    cd functions
 *    npm install firebase-functions firebase-admin
 * 
 * 2. Set Firebase project:
 *    firebase use <project-id>
 * 
 * 3. Deploy function:
 *    firebase deploy --only functions:notifyOrderReady
 * 
 * 4. Configure FCM in Firebase Console:
 *    - Enable Cloud Messaging API
 *    - Generate FCM server key (if not using Admin SDK)
 * 
 * 5. Test notification:
 *    - Place test order
 *    - Manually update status from 'preparing' to 'ready' in Firestore console
 *    - Check function logs: firebase functions:log
 * 
 * MONITORING:
 * - View logs: firebase functions:log --only notifyOrderReady
 * - Check execution count in Firebase Console → Functions
 * - Monitor FCM delivery in Firebase Console → Cloud Messaging
 * 
 * TODO: Add function timeout and memory configuration if needed
 * functions.firestore.document().onUpdate({ timeoutSeconds: 60, memory: '256MB' })
 */
