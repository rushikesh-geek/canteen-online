/// Notification Service for Canteen App
///
/// Handles all push notification functionality:
/// - FCM token management
/// - Local notifications
/// - In-app notification display
/// - Notification history storage
///
/// Notification Types:
/// - ORDER_CONFIRMED: Order has been confirmed by admin
/// - ORDER_PREPARING: Kitchen has started preparing the order
/// - ORDER_READY: Order is ready for pickup
/// - ORDER_COMPLETED: Order has been picked up
/// - ORDER_CANCELLED: Order was cancelled
/// - WALLET_CREDITED: Money added to wallet
/// - WALLET_DEBITED: Payment made from wallet
/// - LOW_BALANCE: Wallet balance is low
/// - NEW_ORDER: (Admin) New order received
/// - PAYMENT_RECEIVED: (Admin) Payment received

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// NOTIFICATION TYPES
// ============================================================================

enum NotificationType {
  // Student notifications
  orderConfirmed,
  orderPreparing,
  orderReady,
  orderCompleted,
  orderCancelled,
  walletCredited,
  walletDebited,
  lowBalance,
  
  // Admin notifications
  newOrder,
  paymentReceived,
  
  // General
  general,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    required this.timestamp,
    this.isRead = false,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      type: _parseNotificationType(map['type'] as String? ?? 'general'),
      title: map['title'] as String? ?? 'Notification',
      body: map['body'] as String? ?? '',
      data: map['data'] as Map<String, dynamic>? ?? {},
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'order_confirmed':
      case 'orderconfirmed':
        return NotificationType.orderConfirmed;
      case 'order_preparing':
      case 'orderpreparing':
        return NotificationType.orderPreparing;
      case 'order_ready':
      case 'orderready':
        return NotificationType.orderReady;
      case 'order_completed':
      case 'ordercompleted':
        return NotificationType.orderCompleted;
      case 'order_cancelled':
      case 'ordercancelled':
        return NotificationType.orderCancelled;
      case 'wallet_credited':
      case 'walletcredited':
        return NotificationType.walletCredited;
      case 'wallet_debited':
      case 'walletdebited':
        return NotificationType.walletDebited;
      case 'low_balance':
      case 'lowbalance':
        return NotificationType.lowBalance;
      case 'new_order':
      case 'neworder':
        return NotificationType.newOrder;
      case 'payment_received':
      case 'paymentreceived':
        return NotificationType.paymentReceived;
      default:
        return NotificationType.general;
    }
  }
}

// ============================================================================
// NOTIFICATION SERVICE
// ============================================================================

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream controllers for in-app notifications
  final StreamController<AppNotification> _notificationController = 
      StreamController<AppNotification>.broadcast();
  
  Stream<AppNotification> get onNotification => _notificationController.stream;
  
  // Unread count stream
  final StreamController<int> _unreadCountController = 
      StreamController<int>.broadcast();
  
  Stream<int> get onUnreadCountChange => _unreadCountController.stream;
  
  String? _fcmToken;
  StreamSubscription? _tokenRefreshSubscription;
  
  // ============================================================================
  // INITIALIZATION
  // ============================================================================
  
  /// Initialize notification service
  /// Call this after Firebase.initializeApp() and user authentication
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('📱 NotificationService: Web platform - limited FCM support');
      return;
    }
    
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint('📱 NotificationService: Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Get FCM token
        await _getFCMToken();
        
        // Listen for token refresh
        _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(_handleTokenRefresh);
        
        // Configure message handlers
        _configureMessageHandlers();
        
        debugPrint('📱 NotificationService: Initialized successfully');
      } else {
        debugPrint('📱 NotificationService: Permission denied');
      }
    } catch (e) {
      debugPrint('📱 NotificationService: Initialization error: $e');
    }
  }
  
  /// Get FCM token and save to user document
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('📱 NotificationService: FCM Token: ${_fcmToken?.substring(0, 20)}...');
      
      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
      }
    } catch (e) {
      debugPrint('📱 NotificationService: Error getting FCM token: $e');
    }
  }
  
  /// Handle token refresh
  void _handleTokenRefresh(String newToken) async {
    debugPrint('📱 NotificationService: Token refreshed');
    _fcmToken = newToken;
    await _saveTokenToFirestore(newToken);
  }
  
  /// Save FCM token to user's Firestore document
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'notificationsEnabled': true,
      });
      debugPrint('📱 NotificationService: Token saved to Firestore');
    } catch (e) {
      debugPrint('📱 NotificationService: Error saving token: $e');
    }
  }
  
  /// Configure FCM message handlers
  void _configureMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Background message tap (when app is in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Check for initial message (app opened from notification)
    _checkInitialMessage();
  }
  
  /// Handle foreground messages (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📱 NotificationService: Foreground message received');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');
    
    final notification = _parseRemoteMessage(message);
    _notificationController.add(notification);
    
    // Store notification in Firestore
    _storeNotification(notification);
  }
  
  /// Handle when user taps notification (app was in background)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 NotificationService: Message opened app');
    
    final notification = _parseRemoteMessage(message);
    _notificationController.add(notification);
    
    // Navigate based on notification type
    _handleNotificationTap(notification);
  }
  
  /// Check if app was opened from notification
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    
    if (initialMessage != null) {
      debugPrint('📱 NotificationService: App opened from notification');
      final notification = _parseRemoteMessage(initialMessage);
      _handleNotificationTap(notification);
    }
  }
  
  /// Parse RemoteMessage to AppNotification
  AppNotification _parseRemoteMessage(RemoteMessage message) {
    return AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: AppNotification._parseNotificationType(message.data['type'] ?? 'general'),
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      data: message.data,
      timestamp: DateTime.now(),
      isRead: false,
    );
  }
  
  /// Handle notification tap navigation
  void _handleNotificationTap(AppNotification notification) {
    // Navigation is handled by the app based on notification type
    // The notification is added to the stream for the UI to handle
    debugPrint('📱 NotificationService: Handling tap for type: ${notification.type}');
  }
  
  // ============================================================================
  // NOTIFICATION STORAGE
  // ============================================================================
  
  /// Store notification in Firestore for history
  Future<void> _storeNotification(AppNotification notification) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
      
      // Update unread count
      _updateUnreadCount();
    } catch (e) {
      debugPrint('📱 NotificationService: Error storing notification: $e');
    }
  }
  
  /// Get notification history stream
  Stream<List<AppNotification>> getNotificationHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
            .toList());
  }
  
  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      
      _updateUnreadCount();
    } catch (e) {
      debugPrint('📱 NotificationService: Error marking as read: $e');
    }
  }
  
  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final batch = _firestore.batch();
      final unreadDocs = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
      _unreadCountController.add(0);
    } catch (e) {
      debugPrint('📱 NotificationService: Error marking all as read: $e');
    }
  }
  
  /// Get unread notification count
  Future<int> getUnreadCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
  
  /// Update unread count stream
  Future<void> _updateUnreadCount() async {
    final count = await getUnreadCount();
    _unreadCountController.add(count);
  }
  
  // ============================================================================
  // LOCAL NOTIFICATION CREATION (For in-app events)
  // ============================================================================
  
  /// Create and store a local notification
  Future<void> createLocalNotification({
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      body: body,
      data: data,
      timestamp: DateTime.now(),
      isRead: false,
    );
    
    // Add to stream for in-app display
    _notificationController.add(notification);
    
    // Store in Firestore
    await _storeNotification(notification);
  }
  
  // ============================================================================
  // NOTIFICATION HELPERS FOR SPECIFIC EVENTS
  // ============================================================================
  
  /// Notify about order status change
  Future<void> notifyOrderStatusChange({
    required String orderId,
    required String status,
    String? pickupTime,
    List<Map<String, dynamic>>? items,
  }) async {
    NotificationType type;
    String title;
    String body;
    
    switch (status.toLowerCase()) {
      case 'confirmed':
        type = NotificationType.orderConfirmed;
        title = '✅ Order Confirmed';
        body = 'Your order has been confirmed.${pickupTime != null ? ' Pickup at $pickupTime' : ''}';
        break;
      case 'preparing':
        type = NotificationType.orderPreparing;
        title = '👨‍🍳 Order Being Prepared';
        body = 'Your order is now being prepared by the kitchen.';
        break;
      case 'ready':
        type = NotificationType.orderReady;
        title = '🍽️ Order Ready!';
        body = 'Your order is ready for pickup!${pickupTime != null ? ' Pickup by $pickupTime' : ''}';
        break;
      case 'completed':
        type = NotificationType.orderCompleted;
        title = '🎉 Order Completed';
        body = 'Thank you for your order! Enjoy your meal.';
        break;
      case 'cancelled':
        type = NotificationType.orderCancelled;
        title = '❌ Order Cancelled';
        body = 'Your order has been cancelled. Any payment will be refunded.';
        break;
      default:
        return; // Unknown status, don't notify
    }
    
    await createLocalNotification(
      type: type,
      title: title,
      body: body,
      data: {
        'orderId': orderId,
        'status': status,
        if (pickupTime != null) 'pickupTime': pickupTime,
      },
    );
  }
  
  /// Notify about wallet transaction
  Future<void> notifyWalletTransaction({
    required String transactionType, // 'credit' or 'debit'
    required double amount,
    String? description,
    double? newBalance,
  }) async {
    final isCredit = transactionType.toLowerCase() == 'credit';
    
    await createLocalNotification(
      type: isCredit ? NotificationType.walletCredited : NotificationType.walletDebited,
      title: isCredit ? '💰 Money Added' : '💳 Payment Made',
      body: isCredit 
          ? '₹${amount.toStringAsFixed(2)} added to your wallet.${newBalance != null ? ' New balance: ₹${newBalance.toStringAsFixed(2)}' : ''}'
          : '₹${amount.toStringAsFixed(2)} paid.${description != null ? ' $description' : ''}',
      data: {
        'transactionType': transactionType,
        'amount': amount,
        if (newBalance != null) 'newBalance': newBalance,
        if (description != null) 'description': description,
      },
    );
  }
  
  /// Notify about low wallet balance
  Future<void> notifyLowBalance({
    required double balance,
    double threshold = 50.0,
  }) async {
    if (balance > threshold) return;
    
    await createLocalNotification(
      type: NotificationType.lowBalance,
      title: '⚠️ Low Wallet Balance',
      body: 'Your wallet balance is ₹${balance.toStringAsFixed(2)}. Add money to continue placing orders.',
      data: {
        'balance': balance,
        'threshold': threshold,
      },
    );
  }
  
  /// Notify admin about new order
  Future<void> notifyNewOrder({
    required String orderId,
    required String studentName,
    required double amount,
    required List<Map<String, dynamic>> items,
  }) async {
    final itemsSummary = items.take(2).map((i) => '${i['quantity']}× ${i['itemName']}').join(', ');
    
    await createLocalNotification(
      type: NotificationType.newOrder,
      title: '🆕 New Order Received',
      body: '$studentName - $itemsSummary (₹${amount.toStringAsFixed(2)})',
      data: {
        'orderId': orderId,
        'studentName': studentName,
        'amount': amount,
      },
    );
  }
  
  /// Notify admin about payment received
  Future<void> notifyPaymentReceived({
    required String studentName,
    required double amount,
    required String paymentMethod,
    String? orderId,
  }) async {
    await createLocalNotification(
      type: NotificationType.paymentReceived,
      title: '💵 Payment Received',
      body: '₹${amount.toStringAsFixed(2)} from $studentName via $paymentMethod',
      data: {
        'studentName': studentName,
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (orderId != null) 'orderId': orderId,
      },
    );
  }
  
  // ============================================================================
  // TOPIC SUBSCRIPTION (For admin notifications)
  // ============================================================================
  
  /// Subscribe to admin notifications topic
  Future<void> subscribeToAdminNotifications() async {
    if (kIsWeb) return;
    
    try {
      await _messaging.subscribeToTopic('admin_notifications');
      debugPrint('📱 NotificationService: Subscribed to admin_notifications');
    } catch (e) {
      debugPrint('📱 NotificationService: Error subscribing to topic: $e');
    }
  }
  
  /// Unsubscribe from admin notifications topic
  Future<void> unsubscribeFromAdminNotifications() async {
    if (kIsWeb) return;
    
    try {
      await _messaging.unsubscribeFromTopic('admin_notifications');
      debugPrint('📱 NotificationService: Unsubscribed from admin_notifications');
    } catch (e) {
      debugPrint('📱 NotificationService: Error unsubscribing from topic: $e');
    }
  }
  
  // ============================================================================
  // CLEANUP
  // ============================================================================
  
  /// Clean up resources
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _notificationController.close();
    _unreadCountController.close();
  }
  
  /// Remove FCM token (on logout)
  Future<void> removeToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
        'notificationsEnabled': false,
      });
      
      await _messaging.deleteToken();
      _fcmToken = null;
      
      debugPrint('📱 NotificationService: Token removed');
    } catch (e) {
      debugPrint('📱 NotificationService: Error removing token: $e');
    }
  }
}

// ============================================================================
// NOTIFICATION WIDGETS
// ============================================================================

/// In-app notification banner widget
class NotificationBanner extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationBanner({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getBorderColor()),
          ),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;
    
    switch (notification.type) {
      case NotificationType.orderConfirmed:
        icon = Icons.check_circle;
        color = Colors.blue;
        break;
      case NotificationType.orderPreparing:
        icon = Icons.restaurant;
        color = Colors.orange;
        break;
      case NotificationType.orderReady:
        icon = Icons.notifications_active;
        color = Colors.green;
        break;
      case NotificationType.orderCompleted:
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case NotificationType.orderCancelled:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case NotificationType.walletCredited:
        icon = Icons.add_circle;
        color = Colors.green;
        break;
      case NotificationType.walletDebited:
        icon = Icons.remove_circle;
        color = Colors.orange;
        break;
      case NotificationType.lowBalance:
        icon = Icons.warning;
        color = Colors.amber;
        break;
      case NotificationType.newOrder:
        icon = Icons.receipt_long;
        color = Colors.blue;
        break;
      case NotificationType.paymentReceived:
        icon = Icons.payments;
        color = Colors.green;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getBackgroundColor() {
    switch (notification.type) {
      case NotificationType.orderReady:
        return Colors.green.shade50;
      case NotificationType.orderCancelled:
        return Colors.red.shade50;
      case NotificationType.lowBalance:
        return Colors.amber.shade50;
      default:
        return Colors.white;
    }
  }

  Color _getBorderColor() {
    switch (notification.type) {
      case NotificationType.orderReady:
        return Colors.green.shade200;
      case NotificationType.orderCancelled:
        return Colors.red.shade200;
      case NotificationType.lowBalance:
        return Colors.amber.shade200;
      default:
        return Colors.grey.shade200;
    }
  }
}

/// Notification icon with badge for app bar
class NotificationIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const NotificationIconButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService().onUnreadCountChange,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: onTap,
              tooltip: 'Notifications',
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 9 ? '9+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
