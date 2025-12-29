/**
 * Admin App Screens
 * 
 * Minimal Flutter UI for canteen staff to manage orders.
 * Real-time order queue with status updates.
 * 
 * TODO: Add proper styling, filters, search functionality
 */

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'slot_management.dart';
import 'counter_screen.dart';
import 'user_management_screen.dart';

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
  
  // Filter by status (default: show active orders only)
  String selectedFilter = 'active'; // 'active', 'all', 'pending', 'preparing', 'ready'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
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
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'active', child: Text('Active Orders')),
              const PopupMenuItem(value: 'all', child: Text('All Orders')),
              const PopupMenuItem(value: 'pending', child: Text('Pending Only')),
              const PopupMenuItem(value: 'preparing', child: Text('Preparing Only')),
              const PopupMenuItem(value: 'ready', child: Text('Ready Only')),
            ],
          ),          // Logout button
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

          final orders = snapshot.data!.docs;

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
    final todayStart = _getTodayStart();
    
    // Base query: all orders from today
    Query query = _firestore
        .collection('orders')
        .where('placedAt', isGreaterThan: todayStart)
        .orderBy('placedAt', descending: false); // Oldest first (FIFO)

    // Apply status filter
    if (selectedFilter != 'active' && selectedFilter != 'all') {
      // ⚠️ FIRESTORE COMPOSITE INDEX REQUIRED
      // Collection: orders
      // Fields: placedAt (Ascending), status (Ascending)
      // Reason: Inequality filter (isGreaterThan) + additional where() clause
      query = _firestore
          .collection('orders')
          .where('placedAt', isGreaterThan: todayStart)
          .where('status', isEqualTo: selectedFilter)
          .orderBy('placedAt', descending: false);
    }

    return query.snapshots();
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
    
    // Handle both String and Timestamp formats (backward compatibility)
    final estimatedPickupTime = data['estimatedPickupTime'] is Timestamp
        ? (data['estimatedPickupTime'] as Timestamp).toDate()
        : DateTime.now(); // Fallback if String format
    
    final pickupTimeStr = data['estimatedPickupTime'] is String
        ? data['estimatedPickupTime'] as String
        : _formatTime(estimatedPickupTime);
    
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
        title: Text(
          userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_buildItemsSummary(items)),
            Text('Pickup: $pickupTimeStr', 
                 style: const TextStyle(fontSize: 12)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full order details
                const Text('Order Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...items.map((item) => Text(
                  '${item['quantity']}× ${item['itemName']} - ₹${item['price'] * item['quantity']}',
                )),
                const Divider(),
                Text('Order ID: #${orderId.substring(orderId.length - 6).toUpperCase()}'),
                Text('Placed: ${_formatDateTime(placedAt)}'),
                const SizedBox(height: 16),
                
                // Action buttons
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
