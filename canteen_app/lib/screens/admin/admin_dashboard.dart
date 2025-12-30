/**
 * Admin App Screens
 * 
 * Minimal Flutter UI for canteen staff to manage orders.
 * Real-time order queue with status updates.
 * 
 * TODO: Add proper styling, filters, search functionality
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'slot_management.dart';
import 'counter_screen.dart';
import 'user_management_screen.dart';
import 'package:canteen_app/screens/notification_screen.dart';
import 'package:canteen_app/services/notification_service.dart';

// ============================================================================
// SCREEN 1: Live Order Queue Dashboard
// ============================================================================

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  // Filter by status (default: show active orders only)
  String selectedFilter = 'active'; // 'active', 'all', 'pending', 'preparing', 'ready'
  
  // Filter by order source
  String orderTypeFilter = 'all'; // 'all', 'app', 'counter'
  
  int _unreadCount = 0;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToAdminNotifications();
    _loadUnreadCount();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToAdminNotifications() async {
    await _notificationService.subscribeToAdminNotifications();
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
    _notificationSubscription = _notificationService.onNotification.listen((notification) {
      if (mounted) {
        _showNotificationBanner(notification);
        _loadUnreadCount();
      }
    });

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
            Text(notification.body, style: const TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: notification.type == NotificationType.newOrder 
            ? Colors.blue 
            : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
          // Counter operations - QR scan & wallet payments
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Counter (Scan & Pay)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CounterScreen()),
              );
            },
          ),
          // Menu management button (Admin only)
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Manage Menu',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MenuManagementScreen()),
              );
            },
          ),
          // Slot management button (Admin only)
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'Manage Slots',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SlotManagementScreen()),
              );
            },
          ),
          // User management button (Admin only)
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Manage Users & Roles',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserManagementScreen()),
              );
            },
          ),
          // Filter dropdown
          PopupMenuButton<String>(
            initialValue: selectedFilter,
            onSelected: (value) {
              setState(() {
                selectedFilter = value;
              });
            },
            icon: const Icon(Icons.filter_list),
            tooltip: 'Status Filter',
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'active', child: Text('Active Orders')),
              const PopupMenuItem(value: 'all', child: Text('All Orders')),
              const PopupMenuItem(value: 'pending', child: Text('Pending Only')),
              const PopupMenuItem(value: 'preparing', child: Text('Preparing Only')),
              const PopupMenuItem(value: 'ready', child: Text('Ready Only')),
            ],
          ),
          // Order Type Filter
          PopupMenuButton<String>(
            initialValue: orderTypeFilter,
            onSelected: (value) {
              setState(() {
                orderTypeFilter = value;
              });
            },
            icon: Icon(
              orderTypeFilter == 'all' 
                  ? Icons.all_inclusive 
                  : orderTypeFilter == 'counter' 
                      ? Icons.point_of_sale 
                      : Icons.phone_android,
            ),
            tooltip: 'Order Source',
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    const Text('All Orders'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'app',
                child: Row(
                  children: [
                    Icon(Icons.phone_android, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    const Text('App Orders'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'counter',
                child: Row(
                  children: [
                    Icon(Icons.point_of_sale, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    const Text('Counter Orders'),
                  ],
                ),
              ),
            ],
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // AuthGate will automatically redirect to LoginScreen
            },
          ),        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Real-time listener for today's orders
        // This automatically updates when orders change status
        stream: _buildOrderQuery(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Apply client-side filtering to avoid composite index
          final orders = _filterOrders(snapshot.data!.docs);

          if (orders.isEmpty) {
            return const Center(child: Text('No orders to display'));
          }

          // Group orders by status for better visualization
          final grouped = _groupOrdersByStatus(orders);

          return ListView(
            children: [
              // Stats summary
              _buildStatsSummary(grouped),
              
              const Divider(),
              
              // Order sections
              if (grouped['pending']!.isNotEmpty)
                _buildOrderSection('Pending', grouped['pending']!, Colors.orange),
              
              if (grouped['confirmed']!.isNotEmpty)
                _buildOrderSection('Confirmed', grouped['confirmed']!, Colors.blue),
              
              if (grouped['preparing']!.isNotEmpty)
                _buildOrderSection('Preparing', grouped['preparing']!, Colors.purple),
              
              if (grouped['ready']!.isNotEmpty)
                _buildOrderSection('Ready for Pickup', grouped['ready']!, Colors.green),
              
              if (selectedFilter == 'all') ...[
                if (grouped['completed']!.isNotEmpty)
                  _buildOrderSection('Completed', grouped['completed']!, Colors.grey),
                
                if (grouped['cancelled']!.isNotEmpty)
                  _buildOrderSection('Cancelled', grouped['cancelled']!, Colors.red),
              ],
            ],
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _buildOrderQuery() {
    // Simple query - filter and sort client-side to avoid composite index
    return _firestore.collection('orders').snapshots();
  }
  
  /// Filter orders client-side to avoid Firestore composite index requirements
  List<DocumentSnapshot> _filterOrders(List<DocumentSnapshot> orders) {
    final todayStart = _getTodayStart();
    
    // Filter today's orders
    var filtered = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final placedAt = data['placedAt'] as Timestamp?;
      if (placedAt == null) return false;
      return placedAt.compareTo(todayStart) > 0;
    }).toList();
    
    // Apply order type filter (app vs counter)
    if (orderTypeFilter != 'all') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final orderType = data['orderType'] as String? ?? 'app';
        if (orderTypeFilter == 'counter') {
          return orderType == 'counter';
        } else {
          return orderType != 'counter'; // 'app' or null means app order
        }
      }).toList();
    }
    
    // Apply status filter
    if (selectedFilter != 'active' && selectedFilter != 'all') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] == selectedFilter;
      }).toList();
    }
    
    // Sort by placedAt ascending (FIFO)
    filtered.sort((a, b) {
      final aTime = ((a.data() as Map<String, dynamic>)['placedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final bTime = ((b.data() as Map<String, dynamic>)['placedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return aTime.compareTo(bTime);
    });
    
    return filtered;
  }

  Map<String, List<DocumentSnapshot>> _groupOrdersByStatus(List<DocumentSnapshot> orders) {
    final grouped = {
      'pending': <DocumentSnapshot>[],
      'confirmed': <DocumentSnapshot>[],
      'preparing': <DocumentSnapshot>[],
      'ready': <DocumentSnapshot>[],
      'completed': <DocumentSnapshot>[],
      'cancelled': <DocumentSnapshot>[],
    };

    for (final order in orders) {
      final data = order.data() as Map<String, dynamic>;
      final status = data['status'] as String;
      
      // Filter for active orders if needed
      if (selectedFilter == 'active') {
        if (status == 'pending' || status == 'confirmed' || 
            status == 'preparing' || status == 'ready') {
          grouped[status]!.add(order);
        }
      } else {
        grouped[status]!.add(order);
      }
    }

    return grouped;
  }

  Widget _buildStatsSummary(Map<String, List<DocumentSnapshot>> grouped) {
    final activeCount = grouped['pending']!.length + 
                       grouped['confirmed']!.length + 
                       grouped['preparing']!.length + 
                       grouped['ready']!.length;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('Active', activeCount, Colors.blue),
          _buildStatCard('Pending', grouped['pending']!.length, Colors.orange),
          _buildStatCard('Preparing', grouped['preparing']!.length, Colors.purple),
          _buildStatCard('Ready', grouped['ready']!.length, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildOrderSection(String title, List<DocumentSnapshot> orders, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${orders.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ...orders.map((order) => _buildOrderCard(order, color)),
      ],
    );
  }

  Widget _buildOrderCard(DocumentSnapshot orderDoc, Color accentColor) {
    final data = orderDoc.data() as Map<String, dynamic>;
    final orderId = orderDoc.id;
    final userName = data['userName'] as String;
    final items = data['items'] as List<dynamic>;
    final status = data['status'] as String;
    final placedAt = (data['placedAt'] as Timestamp).toDate();
    final orderType = data['orderType'] as String? ?? 'app';
    final isCounterOrder = orderType == 'counter';
    
    // Handle both String and Timestamp formats (backward compatibility)
    // Counter orders don't have estimatedPickupTime - they're served immediately
    String pickupTimeStr;
    if (isCounterOrder) {
      pickupTimeStr = 'Served immediately';
    } else if (data['estimatedPickupTime'] is Timestamp) {
      pickupTimeStr = _formatTime((data['estimatedPickupTime'] as Timestamp).toDate());
    } else if (data['estimatedPickupTime'] is String) {
      pickupTimeStr = data['estimatedPickupTime'] as String;
    } else {
      pickupTimeStr = 'Not set';
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: accentColor.withOpacity(0.2),
          child: Text(
            _getWaitTime(placedAt),
            style: TextStyle(color: accentColor, fontSize: 12),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isCounterOrder ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCounterOrder ? Colors.orange : Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCounterOrder ? Icons.point_of_sale : Icons.phone_android,
                    size: 12,
                    color: isCounterOrder ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCounterOrder ? 'Counter' : 'App',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isCounterOrder ? Colors.orange : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_buildItemsSummary(items)),
            Row(
              children: [
                Icon(
                  isCounterOrder ? Icons.check_circle : Icons.schedule,
                  size: 12,
                  color: isCounterOrder ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isCounterOrder ? pickupTimeStr : 'Pickup: $pickupTimeStr',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCounterOrder ? Colors.green : Colors.grey[700],
                    fontWeight: isCounterOrder ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order source and payment info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCounterOrder ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCounterOrder ? Icons.point_of_sale : Icons.phone_android,
                            size: 14,
                            color: isCounterOrder ? Colors.orange : Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCounterOrder ? 'Counter Order' : 'App Order',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isCounterOrder ? Colors.orange : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (data['paymentMethod'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPaymentMethodColor(data['paymentMethod'] as String).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getPaymentMethodIcon(data['paymentMethod'] as String),
                              size: 14,
                              color: _getPaymentMethodColor(data['paymentMethod'] as String),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              data['paymentMethod'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _getPaymentMethodColor(data['paymentMethod'] as String),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Full order details
                const Text('Order Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((item) => Text(
                  '${item['quantity']}× ${item['itemName']} - ₹${item['price'] * item['quantity']}',
                )),
                const Divider(),
                Text('Order ID: #${orderId.substring(orderId.length - 6).toUpperCase()}'),
                Text('Placed: ${_formatDateTime(placedAt)}'),
                if (data['totalAmount'] != null)
                  Text('Total: ₹${data['totalAmount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // Action buttons (not shown for counter orders as they're already completed)
                if (isCounterOrder && status == 'completed')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Counter order - Served immediately',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                else
                  _buildActionButtons(orderDoc, status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DocumentSnapshot orderDoc, String currentStatus) {
    return Wrap(
      spacing: 8,
      children: [
        // Confirm order (pending → confirmed)
        if (currentStatus == 'pending')
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirm'),
            onPressed: () => _updateOrderStatus(orderDoc, 'confirmed'),
          ),
        
        // Start preparing (confirmed → preparing)
        if (currentStatus == 'confirmed')
          ElevatedButton.icon(
            icon: const Icon(Icons.restaurant, size: 16),
            label: const Text('Start Preparing'),
            onPressed: () => _updateOrderStatus(orderDoc, 'preparing'),
          ),
        
        // Mark ready (preparing → ready)
        if (currentStatus == 'preparing')
          ElevatedButton.icon(
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('Mark Ready'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => _updateOrderStatus(orderDoc, 'ready'),
          ),
        
        // Mark completed (ready → completed)
        if (currentStatus == 'ready')
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Mark Completed'),
            onPressed: () => _updateOrderStatus(orderDoc, 'completed'),
          ),
        
        // Cancel order (any status → cancelled)
        if (currentStatus != 'completed' && currentStatus != 'cancelled')
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _showCancelDialog(orderDoc),
          ),
      ],
    );
  }

  Future<void> _updateOrderStatus(DocumentSnapshot orderDoc, String newStatus) async {
    try {
      final updates = <String, dynamic>{
        'status': newStatus,
      };

      // Add timestamp for specific status transitions
      final now = Timestamp.now();
      if (newStatus == 'confirmed') {
        updates['confirmedAt'] = now;
      } else if (newStatus == 'ready') {
        updates['readyAt'] = now;
        // This triggers the Cloud Function to send FCM notification
      } else if (newStatus == 'completed') {
        updates['completedAt'] = now;
      }

      await orderDoc.reference.update(updates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to $newStatus')),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _showCancelDialog(DocumentSnapshot orderDoc) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const TextField(
          decoration: InputDecoration(
            labelText: 'Cancellation Reason (optional)',
            hintText: 'e.g., Item unavailable',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'No reason provided'),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (reason != null) {
      await orderDoc.reference.update({
        'status': 'cancelled',
        'cancellationReason': reason,
      });

      // TODO: Decrement slot currentCount when order is cancelled
      // This should ideally be done in a Cloud Function or transaction
    }
  }

  String _buildItemsSummary(List<dynamic> items) {
    return items
        .map((item) => '${item['quantity']}× ${item['itemName']}')
        .join(', ');
  }

  String _getWaitTime(DateTime placedAt) {
    final diff = DateTime.now().difference(placedAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else {
      return '${diff.inHours}h';
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  String _formatDateTime(DateTime time) {
    return '${time.day}/${time.month} ${_formatTime(time)}';
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'WALLET':
        return Colors.green;
      case 'UPI':
        return Colors.purple;
      case 'CASH':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toUpperCase()) {
      case 'WALLET':
        return Icons.account_balance_wallet;
      case 'UPI':
        return Icons.qr_code;
      case 'CASH':
        return Icons.payments;
      default:
        return Icons.payment;
    }
  }

  Timestamp _getTodayStart() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    return Timestamp.fromDate(todayStart);
  }
}

// ============================================================================
// TODO: IMPROVEMENTS FOR PRODUCTION
// ============================================================================

/*
 * 1. Search & Filters:
 *    - Search orders by user name or order ID
 *    - Filter by time range (last hour, last 2 hours, all day)
 *    - Filter by slot time
 * 
 * 2. Bulk Actions:
 *    - Select multiple orders
 *    - Bulk status update
 *    - Bulk cancel
 * 
 * 3. Order Details:
 *    - Full order timeline view
 *    - Show order modifications/notes
 *    - Show user contact info for issues
 * 
 * 4. Analytics Dashboard:
 *    - Real-time charts (orders per hour)
 *    - Average wait time display
 *    - Slot utilization graph
 * 
 * 5. Notifications:
 *    - Sound alert for new orders
 *    - Badge count on app icon
 *    - Desktop notifications for admin panel
 * 
 * 6. Slot Management:
 *    - Create slots for tomorrow
 *    - Edit slot capacity
 *    - Manually close/reopen slots
 *    - Clone yesterday's slots
 * 
 * 7. Error Handling:
 *    - Handle network failures gracefully
 *    - Show offline banner
 *    - Retry failed status updates
 * 
 * 8. Permissions:
 *    - Role-based access (admin vs. kitchen staff)
 *    - Audit log for status changes
 *    - Restrict cancel/modify actions
 */

// ============================================================================
// SCREEN 2: Menu Management (Admin Only)
// ============================================================================

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({Key? key}) : super(key: key);

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMenuItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Dish'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Real-time menu list from Firestore
        // Collection: menu
        // Shows all items (available and unavailable)
        stream: _firestore
            .collection('menu')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final menuItems = snapshot.data!.docs;

          if (menuItems.isEmpty) {
            return const Center(
              child: Text('No menu items. Add your first dish!'),
            );
          }

          return ListView.builder(
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final doc = menuItems[index];
              final name = doc['name'] as String;
              final price = (doc['price'] as num).toDouble();
              final isAvailable = doc['isAvailable'] as bool;

              return ListTile(
                title: Text(name),
                subtitle: Text('₹$price'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle availability switch
                    Switch(
                      value: isAvailable,
                      onChanged: (value) async {
                        await _firestore
                            .collection('menu')
                            .doc(doc.id)
                            .update({'isAvailable': value});
                      },
                    ),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteMenuItem(doc.id, name),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Show dialog to add new menu item
  /// Admin only - should verify admin role before calling
  void _showAddMenuItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dish name input
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Dish Name',
                  hintText: 'e.g., Masala Dosa',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Dish name cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Price input
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (₹)',
                  hintText: 'e.g., 40',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price cannot be empty';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Price must be a positive number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _addMenuItem(
                  nameController.text.trim(),
                  double.parse(priceController.text.trim()),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Menu item added successfully!')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Add new menu item to Firestore
  /// Firestore Collection: menu
  /// Document fields:
  ///   - name: String (dish name)
  ///   - price: Number (in rupees)
  ///   - isAvailable: Boolean (default true)
  ///   - createdAt: Timestamp (when item was added)
  Future<void> _addMenuItem(String name, double price) async {
    await _firestore.collection('menu').add({
      'name': name,
      'price': price,
      'isAvailable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete menu item from Firestore
  Future<void> _deleteMenuItem(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('menu').doc(docId).delete();
    }
  }
}
