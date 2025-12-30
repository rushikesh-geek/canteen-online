/**
 * Cloud Functions: Canteen Notification System
 * 
 * Comprehensive notification system for the canteen app.
 * Handles all order status changes and payment notifications.
 * 
 * Notification Types:
 * - ORDER_CONFIRMED: Order confirmed by admin
 * - ORDER_PREPARING: Kitchen started preparing
 * - ORDER_READY: Order ready for pickup
 * - ORDER_COMPLETED: Order picked up
 * - ORDER_CANCELLED: Order cancelled
 * - WALLET_CREDITED: Money added to wallet
 * - WALLET_DEBITED: Payment made
 * - NEW_ORDER: (Admin) New order received
 * - PAYMENT_RECEIVED: (Admin) Payment received
 * 
 * Deployment: firebase deploy --only functions
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
  paymentStatus?: string;
  slotId: string;
  estimatedPickupTime: Timestamp;
  totalAmount: number;
  items: {
    itemName: string;
    quantity: number;
    price: number;
  }[];
  placedAt: Timestamp;
  orderType?: string;
}

interface UserData {
  userId: string;
  name: string;
  email: string;
  fcmToken?: string;
  role: string;
  notificationsEnabled?: boolean;
}

interface WalletTransactionData {
  userId: string;
  type: 'credit' | 'debit';
  amount: number;
  description: string;
  balanceAfter: number;
  createdAt: Timestamp;
}

// ============================================================================
// CLOUD FUNCTION: Order Status Change Handler (All Status Changes)
// ============================================================================

/**
 * Comprehensive order status notification handler.
 * Sends FCM notifications for all order status transitions.
 */
export const notifyOrderStatusChange = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data() as OrderData;
    const afterData = change.after.data() as OrderData;
    const orderId = context.params.orderId;

    // Check if status actually changed
    if (beforeData.status === afterData.status) {
      return null;
    }

    console.log(`Order ${orderId}: Status change ${beforeData.status} → ${afterData.status}`);

    // Get notification content based on status transition
    const notificationContent = getOrderStatusNotification(
      afterData.status,
      afterData.items,
      afterData.estimatedPickupTime
    );

    if (!notificationContent) {
      console.log(`Order ${orderId}: No notification configured for status ${afterData.status}`);
      return null;
    }

    // Fetch user's FCM token
    const fcmToken = await getUserFCMToken(afterData.userId);
    
    if (!fcmToken) {
      console.warn(`Order ${orderId}: User ${afterData.userId} has no FCM token`);
      // Store notification in Firestore for in-app display
      await storeNotification(afterData.userId, {
        type: `ORDER_${afterData.status.toUpperCase()}`,
        title: notificationContent.title,
        body: notificationContent.body,
        data: { orderId, status: afterData.status },
      });
      return null;
    }

    // Send FCM notification
    return sendFCMNotification(fcmToken, {
      title: notificationContent.title,
      body: notificationContent.body,
      data: {
        orderId: orderId,
        type: `ORDER_${afterData.status.toUpperCase()}`,
        status: afterData.status,
        timestamp: Timestamp.now().toMillis().toString(),
      },
    });
  });

/**
 * Notify student when a new order is placed (confirmation)
 */
export const notifyNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snapshot, context) => {
    const orderData = snapshot.data() as OrderData;
    const orderId = context.params.orderId;

    console.log(`New order created: ${orderId}`);

    // Notify the student
    const fcmToken = await getUserFCMToken(orderData.userId);
    
    const pickupTime = formatPickupTime(orderData.estimatedPickupTime);
    
    if (fcmToken) {
      await sendFCMNotification(fcmToken, {
        title: '📝 Order Placed',
        body: `Your order has been placed. Estimated pickup: ${pickupTime}`,
        data: {
          orderId: orderId,
          type: 'ORDER_PLACED',
          timestamp: Timestamp.now().toMillis().toString(),
        },
      });
    }

    // Store notification for in-app display
    await storeNotification(orderData.userId, {
      type: 'ORDER_PLACED',
      title: '📝 Order Placed',
      body: `Your order has been placed. Estimated pickup: ${pickupTime}`,
      data: { orderId },
    });

    // Notify admins about new order
    await notifyAdmins({
      title: '🆕 New Order',
      body: `${orderData.userName} - ${buildItemsSummary(orderData.items)} (₹${orderData.totalAmount})`,
      data: {
        orderId: orderId,
        type: 'NEW_ORDER',
        userId: orderData.userId,
        userName: orderData.userName,
      },
    });

    return null;
  });

/**
 * Notify on wallet transaction
 */
export const notifyWalletTransaction = functions.firestore
  .document('wallet_transactions/{transactionId}')
  .onCreate(async (snapshot, context) => {
    const txData = snapshot.data() as WalletTransactionData;
    const transactionId = context.params.transactionId;

    console.log(`New wallet transaction: ${transactionId}`);

    const fcmToken = await getUserFCMToken(txData.userId);
    
    const isCredit = txData.type === 'credit';
    const title = isCredit ? '💰 Money Added' : '💳 Payment Made';
    const body = isCredit 
      ? `₹${txData.amount.toFixed(2)} added to wallet. Balance: ₹${txData.balanceAfter.toFixed(2)}`
      : `₹${txData.amount.toFixed(2)} paid. ${txData.description}`;

    // Store notification for in-app
    await storeNotification(txData.userId, {
      type: isCredit ? 'WALLET_CREDITED' : 'WALLET_DEBITED',
      title: title,
      body: body,
      data: { 
        transactionId, 
        amount: txData.amount,
        balanceAfter: txData.balanceAfter,
      },
    });

    if (fcmToken) {
      await sendFCMNotification(fcmToken, {
        title: title,
        body: body,
        data: {
          transactionId: transactionId,
          type: isCredit ? 'WALLET_CREDITED' : 'WALLET_DEBITED',
          timestamp: Timestamp.now().toMillis().toString(),
        },
      });
    }

    // Check for low balance warning
    if (txData.balanceAfter < 50 && !isCredit) {
      await storeNotification(txData.userId, {
        type: 'LOW_BALANCE',
        title: '⚠️ Low Wallet Balance',
        body: `Your wallet balance is ₹${txData.balanceAfter.toFixed(2)}. Add money to continue ordering.`,
        data: { balance: txData.balanceAfter },
      });

      if (fcmToken) {
        await sendFCMNotification(fcmToken, {
          title: '⚠️ Low Wallet Balance',
          body: `Your wallet balance is ₹${txData.balanceAfter.toFixed(2)}. Add money to continue ordering.`,
          data: {
            type: 'LOW_BALANCE',
            balance: txData.balanceAfter.toString(),
            timestamp: Timestamp.now().toMillis().toString(),
          },
        });
      }
    }

    return null;
  });

// Legacy function - kept for backward compatibility
// The new notifyOrderStatusChange handles all status transitions including ready
export const notifyOrderReady = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data() as OrderData;
    const afterData = change.after.data() as OrderData;
    const orderId = context.params.orderId;

    // Only handle preparing → ready transition
    if (beforeData.status !== 'preparing' || afterData.status !== 'ready') {
      return null;
    }

    console.log(`Order ${orderId}: Legacy notifyOrderReady triggered`);

    // Get user FCM token
    const fcmToken = await getUserFCMToken(afterData.userId);

    if (!fcmToken) {
      console.warn(`Order ${orderId}: User ${afterData.userId} has no FCM token`);
      return null;
    }

    // Build notification
    const pickupTime = formatPickupTime(afterData.estimatedPickupTime);
    const itemsSummary = buildItemsSummary(afterData.items);

    const content = {
      title: '🍽️ Your Order is Ready!',
      body: `${itemsSummary} - Pickup by ${pickupTime}`,
      data: {
        orderId: orderId,
        type: 'ORDER_READY',
        slotId: afterData.slotId,
        pickupTime: afterData.estimatedPickupTime.toMillis().toString(),
        timestamp: Timestamp.now().toMillis().toString(),
      },
    };

    // Send notification
    await sendFCMNotification(fcmToken, content);
    await storeNotification(afterData.userId, {
      type: 'ORDER_READY',
      title: content.title,
      body: content.body,
      data: { orderId: orderId },
    });

    return null;
  });

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Get user's FCM token from Firestore
 */
async function getUserFCMToken(userId: string): Promise<string | undefined> {
  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      console.warn(`User ${userId} not found`);
      return undefined;
    }

    const userData = userDoc.data() as UserData;
    return userData.fcmToken;
  } catch (error) {
    console.error(`Error fetching user ${userId}:`, error);
    return undefined;
  }
}

/**
 * Send FCM push notification
 */
async function sendFCMNotification(
  token: string,
  content: {
    title: string;
    body: string;
    data: Record<string, string>;
  }
): Promise<string | null> {
  try {
    const message = {
      token: token,
      notification: {
        title: content.title,
        body: content.body,
      },
      data: content.data,
      android: {
        priority: 'high' as const,
        notification: {
          sound: 'default',
          channelId: 'order_updates',
          priority: 'high' as const,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`FCM notification sent: ${response}`);
    return response;
  } catch (error: any) {
    console.error(`FCM send error:`, error);
    
    // Handle invalid token
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      console.warn(`Invalid FCM token, should be removed`);
    }
    
    return null;
  }
}

/**
 * Store notification in Firestore for in-app display
 */
async function storeNotification(
  userId: string,
  notification: {
    type: string;
    title: string;
    body: string;
    data: Record<string, any>;
  }
): Promise<void> {
  try {
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add({
        ...notification,
        timestamp: Timestamp.now(),
        isRead: false,
      });
    console.log(`Notification stored for user ${userId}`);
  } catch (error) {
    console.error(`Error storing notification:`, error);
  }
}

/**
 * Notify all admin users
 */
async function notifyAdmins(notification: {
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<void> {
  try {
    // Get all admin users
    const adminsSnapshot = await admin.firestore()
      .collection('users')
      .where('role', 'in', ['admin', 'counter'])
      .get();

    const tokens: string[] = [];
    const adminIds: string[] = [];

    adminsSnapshot.docs.forEach((doc) => {
      const userData = doc.data() as UserData;
      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
      adminIds.push(doc.id);
    });

    // Store notification for each admin
    for (const adminId of adminIds) {
      await storeNotification(adminId, {
        type: notification.data.type || 'ADMIN_NOTIFICATION',
        title: notification.title,
        body: notification.body,
        data: notification.data,
      });
    }

    // Send FCM to all admins with tokens
    if (tokens.length > 0) {
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data,
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Admin notifications: ${response.successCount} sent, ${response.failureCount} failed`);
    }
  } catch (error) {
    console.error(`Error notifying admins:`, error);
  }
}

/**
 * Get notification content based on order status
 */
function getOrderStatusNotification(
  status: string,
  items: OrderData['items'],
  pickupTime: Timestamp
): { title: string; body: string } | null {
  const itemsSummary = buildItemsSummary(items);
  const timeStr = formatPickupTime(pickupTime);

  switch (status) {
    case 'confirmed':
      return {
        title: '✅ Order Confirmed',
        body: `Your order has been confirmed. Pickup at ${timeStr}`,
      };
    case 'preparing':
      return {
        title: '👨‍🍳 Order Being Prepared',
        body: `${itemsSummary} - Kitchen has started preparing your order`,
      };
    case 'ready':
      return {
        title: '🍽️ Order Ready!',
        body: `${itemsSummary} - Pickup by ${timeStr}`,
      };
    case 'completed':
      return {
        title: '🎉 Order Completed',
        body: 'Thank you for your order! Enjoy your meal.',
      };
    case 'cancelled':
      return {
        title: '❌ Order Cancelled',
        body: 'Your order has been cancelled. Any payment will be refunded.',
      };
    default:
      return null;
  }
}

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
// DEPLOYMENT NOTES
// ============================================================================

/*
 * DEPLOYING:
 * 
 * 1. Install dependencies:
 *    cd functions
 *    npm install firebase-functions firebase-admin
 * 
 * 2. Set Firebase project:
 *    firebase use <project-id>
 * 
 * 3. Deploy all functions:
 *    firebase deploy --only functions
 * 
 * 4. Or deploy individual functions:
 *    firebase deploy --only functions:notifyOrderStatusChange
 *    firebase deploy --only functions:notifyNewOrder
 *    firebase deploy --only functions:notifyWalletTransaction
 * 
 * MONITORING:
 * - View logs: firebase functions:log
 * - Check execution in Firebase Console → Functions
 * - Monitor FCM in Firebase Console → Cloud Messaging
 */
