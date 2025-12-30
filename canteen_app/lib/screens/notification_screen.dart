/// Notification Screen
///
/// Displays notification history with filtering and management options.
/// Used by both students and admins to view their notifications.

import 'package:flutter/material.dart';
import 'package:canteen_app/services/notification_service.dart';
import 'package:canteen_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  String _filter = 'all'; // 'all', 'unread', 'orders', 'wallet'

  @override
  void initState() {
    super.initState();
    // Mark all as read when screen is opened
    Future.delayed(const Duration(seconds: 2), () {
      _notificationService.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'unread', child: Text('Unread')),
              const PopupMenuItem(value: 'orders', child: Text('Orders')),
              const PopupMenuItem(value: 'wallet', child: Text('Wallet')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _notificationService.markAllAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 20),
                    SizedBox(width: 8),
                    Text('Mark all as read'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getNotificationHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          var notifications = snapshot.data ?? [];

          // Apply filter
          notifications = _applyFilter(notifications);

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _filter == 'all' 
                        ? 'No notifications yet'
                        : 'No ${_filter} notifications',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see updates about your orders and wallet here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Group notifications by date
          final groupedNotifications = _groupByDate(notifications);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groupedNotifications.length,
            itemBuilder: (context, index) {
              final group = groupedNotifications[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      group.dateLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  // Notifications for this date
                  ...group.notifications.map((notification) => 
                    _buildNotificationTile(notification)
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<AppNotification> _applyFilter(List<AppNotification> notifications) {
    switch (_filter) {
      case 'unread':
        return notifications.where((n) => !n.isRead).toList();
      case 'orders':
        return notifications.where((n) => 
          n.type == NotificationType.orderConfirmed ||
          n.type == NotificationType.orderPreparing ||
          n.type == NotificationType.orderReady ||
          n.type == NotificationType.orderCompleted ||
          n.type == NotificationType.orderCancelled ||
          n.type == NotificationType.newOrder
        ).toList();
      case 'wallet':
        return notifications.where((n) => 
          n.type == NotificationType.walletCredited ||
          n.type == NotificationType.walletDebited ||
          n.type == NotificationType.lowBalance ||
          n.type == NotificationType.paymentReceived
        ).toList();
      default:
        return notifications;
    }
  }

  List<_NotificationGroup> _groupByDate(List<AppNotification> notifications) {
    final Map<String, List<AppNotification>> grouped = {};
    
    for (final notification in notifications) {
      final dateKey = _getDateKey(notification.timestamp);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(notification);
    }
    
    return grouped.entries.map((e) => _NotificationGroup(
      dateLabel: e.key,
      notifications: e.value,
    )).toList();
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) {
      return 'Today';
    } else if (notificationDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // Day name
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Widget _buildNotificationTile(AppNotification notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey.shade200 : Colors.blue.shade100,
        ),
      ),
      child: ListTile(
        onTap: () => _handleNotificationTap(notification),
        leading: _buildNotificationIcon(notification),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(notification.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        trailing: notification.isRead 
            ? null 
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildNotificationIcon(AppNotification notification) {
    IconData icon;
    Color color;
    
    switch (notification.type) {
      case NotificationType.orderConfirmed:
        icon = Icons.check_circle;
        color = AppTheme.infoBlue;
        break;
      case NotificationType.orderPreparing:
        icon = Icons.restaurant;
        color = AppTheme.warningAmber;
        break;
      case NotificationType.orderReady:
        icon = Icons.notifications_active;
        color = AppTheme.successGreen;
        break;
      case NotificationType.orderCompleted:
        icon = Icons.done_all;
        color = AppTheme.textSecondary;
        break;
      case NotificationType.orderCancelled:
        icon = Icons.cancel;
        color = AppTheme.errorRed;
        break;
      case NotificationType.walletCredited:
        icon = Icons.add_circle;
        color = AppTheme.successGreen;
        break;
      case NotificationType.walletDebited:
        icon = Icons.remove_circle;
        color = AppTheme.warningAmber;
        break;
      case NotificationType.lowBalance:
        icon = Icons.warning;
        color = AppTheme.warningAmber;
        break;
      case NotificationType.newOrder:
        icon = Icons.receipt_long;
        color = AppTheme.infoBlue;
        break;
      case NotificationType.paymentReceived:
        icon = Icons.payments;
        color = AppTheme.successGreen;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('h:mm a').format(time);
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    // Mark as read
    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
    }

    // Navigate based on notification type
    final orderId = notification.data['orderId'] as String?;
    
    switch (notification.type) {
      case NotificationType.orderConfirmed:
      case NotificationType.orderPreparing:
      case NotificationType.orderReady:
      case NotificationType.orderCompleted:
      case NotificationType.orderCancelled:
      case NotificationType.newOrder:
        if (orderId != null) {
          // Show order details dialog
          _showOrderDetails(orderId);
        }
        break;
      case NotificationType.walletCredited:
      case NotificationType.walletDebited:
      case NotificationType.lowBalance:
      case NotificationType.paymentReceived:
        // Navigate to wallet screen
        Navigator.pop(context);
        // User should be on wallet tab
        break;
      default:
        // Just mark as read
        break;
    }
  }

  void _showOrderDetails(String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${orderId.substring(orderId.length - 6).toUpperCase()}'),
        content: const Text('View full order details in the Orders tab.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _NotificationGroup {
  final String dateLabel;
  final List<AppNotification> notifications;

  _NotificationGroup({
    required this.dateLabel,
    required this.notifications,
  });
}
