import 'package:flutter/material.dart';
import 'package:canteen_app/screens/student/student_screens.dart';
import 'package:canteen_app/screens/student/wallet_screen.dart';

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

  // Screen list - keeps state alive with IndexedStack
  final List<Widget> _screens = const [
    MenuScreen(),
    WalletScreen(),
    OrderStatusScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
