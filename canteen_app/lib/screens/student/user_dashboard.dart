import 'dart:async';
import 'package:flutter/material.dart';
import 'package:canteen_app/screens/student/student_screens.dart';
import 'package:canteen_app/screens/student/wallet_screen.dart';
import 'package:canteen_app/screens/notification_screen.dart';
import 'package:canteen_app/services/notification_service.dart';

/// User Dashboard Screen
/// 
/// Provides persistent navigation for student users with:
/// - Menu tab for browsing and ordering food
/// - Wallet tab for balance, payment QR, and transactions
/// - My Orders tab for order history and tracking
/// 
/// Uses IndexedStack to preserve screen state during tab switches
/// Prevents random screen changes caused by async rebuilds
class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _currentIndex = 0;
  final NotificationService _notificationService = NotificationService();
  StreamSubscription? _notificationSubscription;
  int _unreadCount = 0;

  // Screen list - keeps state alive with IndexedStack
  final List<Widget> _screens = const [
    MenuScreen(),
    WalletScreen(),
    OrderStatusScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  void _listenToNotifications() {
    // Listen for new notifications to show in-app banner
    _notificationSubscription = _notificationService.onNotification.listen((notification) {
      if (mounted) {
        _showNotificationBanner(notification);
        _loadUnreadCount();
      }
    });

    // Listen for unread count changes
    _notificationService.onUnreadCountChange.listen((count) {
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    });
  }

  void _showNotificationBanner(AppNotification notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              notification.body,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        backgroundColor: _getNotificationColor(notification.type),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          },
        ),
      ),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.orderReady:
        return Colors.green;
      case NotificationType.orderCancelled:
        return Colors.red;
      case NotificationType.lowBalance:
        return Colors.orange;
      case NotificationType.walletCredited:
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0 ? AppBar(
        title: const Text('Canteen'),
        automaticallyImplyLeading: false,
        actions: [
          // Notification icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationScreen()),
                  );
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
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
                      _unreadCount > 9 ? '9+' : _unreadCount.toString(),
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
          ),
        ],
      ) : null,
      // IndexedStack maintains state of all screens
      // Prevents rebuild issues when switching tabs
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
            tooltip: 'Browse and order food',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
            tooltip: 'View balance and payment QR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'My Orders',
            tooltip: 'View order history and status',
          ),
        ],
      ),
    );
  }
}
