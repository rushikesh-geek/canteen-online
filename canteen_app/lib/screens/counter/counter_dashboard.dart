/// Counter Dashboard - ERP Style Point of Sale
/// 
/// Dedicated dashboard for counter staff to:
/// - Create orders from available dishes
/// - Accept wallet QR payments
/// - Accept UPI/Cash payments
/// - View counter orders and statistics
/// - Quick checkout flow
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:canteen_app/theme/app_theme.dart';
import 'package:canteen_app/screens/counter/pos_screen.dart';
import 'package:canteen_app/screens/counter/counter_orders_screen.dart';
import 'package:canteen_app/screens/counter/counter_reports_screen.dart';

class CounterDashboard extends StatefulWidget {
  const CounterDashboard({super.key});

  @override
  State<CounterDashboard> createState() => _CounterDashboardState();
}

class _CounterDashboardState extends State<CounterDashboard> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = const [
    POSScreen(),           // Point of Sale - Main screen
    CounterOrdersScreen(), // Today's counter orders
    CounterReportsScreen(), // Sales reports
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🍽️ Counter Terminal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Quick stats
          StreamBuilder<QuerySnapshot>(
            stream: _getTodayCounterOrdersStream(),
            builder: (context, snapshot) {
              int count = 0;
              double total = 0;
              if (snapshot.hasData) {
                count = snapshot.data!.docs.length;
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  total += (data['totalAmount'] as num?)?.toDouble() ?? 0;
                }
              }
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$count orders • ₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.lightOrange,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale, color: AppTheme.deepOrange),
            label: 'New Order',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppTheme.deepOrange),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: AppTheme.deepOrange),
            label: 'Reports',
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getTodayCounterOrdersStream() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    return FirebaseFirestore.instance
        .collection('orders')
        .where('orderType', isEqualTo: 'counter')
        .where('placedAt', isGreaterThan: Timestamp.fromDate(todayStart))
        .snapshots();
  }
}
