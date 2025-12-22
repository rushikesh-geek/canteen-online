/**
 * Student App Screens
 * 
 * Minimal Flutter UI for order placement and tracking.
 * Connects to Firestore backend logic.
 * 
 * TODO: Add proper styling, error states, loading indicators
 */

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================================
// SCREEN 1: Menu Listing & Order Placement
// ============================================================================

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // Cart to track selected items (itemId -> quantity)
  Map<String, int> cart = {};
  
  // Cache menu items for cart calculations
  Map<String, MenuItem> menuItemsCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canteen Menu'),
        actions: [
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // AuthGate will automatically redirect to LoginScreen
            },
          ),
          // Show cart badge
          if (cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: Text('${_getTotalItems()} items'),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Real-time menu from Firestore
        // Collection: menu
        // Only shows items where isAvailable = true
        stream: FirebaseFirestore.instance
            .collection('menu')
            .where('isAvailable', isEqualTo: true)
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
              child: Text('No menu items available'),
            );
          }

          return ListView.builder(
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final doc = menuItems[index];
              final item = MenuItem(
                id: doc.id,
                name: doc['name'] as String,
                price: (doc['price'] as num).toDouble(),
              );
              
              // Cache menu item for later use
              menuItemsCache[item.id] = item;
              
          final quantity = cart[item.id] ?? 0;
          
          return ListTile(
            title: Text(item.name),
            subtitle: Text('₹${item.price}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decrease quantity
                IconButton(
                  icon: const Icon(Icons.remove_circle),
                  onPressed: quantity > 0 ? () => _updateCart(item.id, -1) : null,
                ),
                // Show quantity
                Text('$quantity', style: const TextStyle(fontSize: 16)),
                // Increase quantity
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: () => _updateCart(item.id, 1),
                ),
              ],
            ),
          );
        },
      );
        },
      ),
      bottomNavigationBar: cart.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _proceedToSlotSelection,
                  child: Text('Proceed to Order (₹${_getTotalAmount()})'),
                ),
              ),
            )
          : null,
    );
  }

  void _updateCart(String itemId, int delta) {
    setState(() {
      cart[itemId] = (cart[itemId] ?? 0) + delta;
      if (cart[itemId]! <= 0) {
        cart.remove(itemId);
      }
    });
  }

  int _getTotalItems() {
    return cart.values.fold(0, (sum, qty) => sum + qty);
  }

  double _getTotalAmount() {
    double total = 0;
    cart.forEach((itemId, quantity) {
      final item = menuItemsCache[itemId];
      if (item != null) {
        total += item.price * quantity;
      }
    });
    return total;
  }

  void _proceedToSlotSelection() {
    // Convert cart items to list for slot selection screen
    final cartItems = cart.entries.map((e) {
      return MenuItem(
        id: e.key,
        name: menuItemsCache[e.key]!.name,
        price: menuItemsCache[e.key]!.price,
      );
    }).toList();
    
    // Navigate to slot selection screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SlotSelectionScreen(
          cart: cart,
          menuItems: cartItems,
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 2: Slot Selection & Order Placement
// ============================================================================

class SlotSelectionScreen extends StatefulWidget {
  final Map<String, int> cart;
  final List<MenuItem> menuItems;

  const SlotSelectionScreen({
    Key? key,
    required this.cart,
    required this.menuItems,
  }) : super(key: key);

  @override
  State<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends State<SlotSelectionScreen> {
  String? selectedSlotId;
  bool isPlacingOrder = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Pickup Time')),
      body: Column(
        children: [
          // Order summary
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Order:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._buildOrderSummary(),
                  ],
                ),
              ),
            ),
          ),
          
          // Slot listing
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Real-time listener for available slots
              // 
              // FIRESTORE COMPOSITE INDEX REQUIRED:
              // This query filters by TWO fields (date, status) and orders by a THIRD (startTime).
              // Firestore requires a composite index for this combination.
              //
              // To create the index:
              // Query uses the existing composite index:
              //    Collection: orderSlots
              //    Fields: date (Ascending), isActive (Ascending), startTime (Ascending)
              //
              // Query logic: Show only TODAY's slots that are ACTIVE, ordered by pickup time
              stream: FirebaseFirestore.instance
                  .collection('orderSlots')
                  .where('date', isEqualTo: _getTodayDate())
                  .where('isActive', isEqualTo: true)
                  .orderBy('startTime')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final slots = snapshot.data!.docs;

                if (slots.isEmpty) {
                  return const Center(
                    child: Text('No slots available. Please try again later.'),
                  );
                }

                return ListView.builder(
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slotData = slots[index].data() as Map<String, dynamic>;
                    final slotId = slots[index].id;
                    
                    // BACKWARD COMPATIBILITY: Handle both Timestamp and legacy String formats
                    DateTime? startTime;
                    try {
                      final startTimeField = slotData['startTime'];
                      if (startTimeField is Timestamp) {
                        startTime = startTimeField.toDate();
                      } else if (startTimeField is String) {
                        // Legacy data: parse "11:00" format (TODO: migrate old data)
                        final parts = startTimeField.split(':');
                        final now = DateTime.now();
                        startTime = DateTime(now.year, now.month, now.day, 
                          int.parse(parts[0]), int.parse(parts[1]));
                      }
                    } catch (e) {
                      // Skip invalid slots
                      return const SizedBox.shrink();
                    }
                    
                    if (startTime == null) return const SizedBox.shrink();
                    
                    final currentCount = slotData['bookedCount'] ?? slotData['currentCount'] ?? 0;
                    final maxCapacity = slotData['capacity'] ?? slotData['maxCapacity'] ?? 30;
                    final isFull = currentCount >= maxCapacity;

                    return ListTile(
                      title: Text(_formatTime(startTime)),
                      subtitle: Text('$currentCount/$maxCapacity orders'),
                      trailing: isFull
                          ? const Chip(label: Text('Full'))
                          : Radio<String>(
                              value: slotId,
                              groupValue: selectedSlotId,
                              onChanged: (value) {
                                setState(() {
                                  selectedSlotId = value;
                                });
                              },
                            ),
                      enabled: !isFull,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: selectedSlotId != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: isPlacingOrder ? null : _placeOrder,
                  child: isPlacingOrder
                      ? const CircularProgressIndicator()
                      : const Text('Place Order'),
                ),
              ),
            )
          : null,
    );
  }

  List<Widget> _buildOrderSummary() {
    List<Widget> widgets = [];
    widget.cart.forEach((itemId, quantity) {
      final item = widget.menuItems.firstWhere((m) => m.id == itemId);
      widgets.add(Text('$quantity × ${item.name} = ₹${item.price * quantity}'));
    });
    return widgets;
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  Future<void> _placeOrder() async {
    setState(() {
      isPlacingOrder = true;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Fetch user data for name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown User';

      // Build items array
      List<Map<String, dynamic>> items = [];
      double totalAmount = 0;
      
      widget.cart.forEach((itemId, quantity) {
        final menuItem = widget.menuItems.firstWhere((m) => m.id == itemId);
        items.add({
          'itemName': menuItem.name,
          'quantity': quantity,
          'price': menuItem.price,
        });
        totalAmount += menuItem.price * quantity;
      });

      // CRITICAL: Use Firestore transaction to create order atomically
      // This matches the logic from backend/order_creation.ts
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Re-read slot inside transaction for latest state
        final freshSlotDoc = await transaction.get(
          FirebaseFirestore.instance.collection('orderSlots').doc(selectedSlotId)
        );
        final freshSlot = freshSlotDoc.data()!;

        // Double-check slot capacity (race condition protection)
        if (freshSlot['bookedCount'] >= freshSlot['capacity']) {
          throw Exception('Slot filled up. Please select another time.');
        }

        // Create order document
        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        final now = Timestamp.now();
        
        transaction.set(orderRef, {
          'orderId': orderRef.id,
          'userId': user.uid,
          'userName': userName,
          'items': items,
          'totalAmount': totalAmount,
          'slotId': selectedSlotId,
          'estimatedPickupTime': freshSlot['startTime'],
          'status': 'pending',
          'placedAt': now,
          'confirmedAt': null,
          'readyAt': null,
          'completedAt': null,
          'pickupVerified': false,
          'pickupVerifiedAt': null,
          'cancellationReason': null,
        });

        // Update slot count
        final newCount = (freshSlot['bookedCount'] as int) + 1;
        final Map<String, dynamic> updates = {
          'bookedCount': newCount,
        };

        // Auto-close slot if full
        if (newCount >= freshSlot['capacity']) {
          updates['isActive'] = false;
          updates['autoClosedAt'] = now;
        }

        transaction.update(freshSlotDoc.reference, updates);
      });

      // Success - navigate to order status screen
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OrderStatusScreen()),
        (route) => false, // Remove all previous routes
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );

    } catch (e) {
      // Show error message
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isPlacingOrder = false;
        });
      }
    }
  }
}

// ============================================================================
// SCREEN 3: Order Status Tracking (Real-time)
// ============================================================================

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: const Center(child: Text('Please log in to view orders')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot>(
        // ⚠️ FIRESTORE COMPOSITE INDEX REQUIRED
        // This query uses multiple filters + orderBy, which requires a composite index:
        // 
        // Collection: orders
        // Fields (in order):
        //   1. userId (Ascending)
        //   2. placedAt (Descending)
        //
        // Why: Firestore requires composite indexes when combining:
        //   - Multiple where() clauses on different fields
        //   - An inequality filter (isGreaterThan) + orderBy() on that field
        //
        // Create index at: Firebase Console → Firestore → Indexes
        // Or click the link in the error message to auto-generate
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .where('placedAt', isGreaterThan: _getTodayStart())
            .orderBy('placedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet. Place your first order!'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderData = orders[index].data() as Map<String, dynamic>;
              final orderId = orders[index].id;
              final status = orderData['status'] as String;
              final items = orderData['items'] as List<dynamic>;
              
              // Handle both String and Timestamp formats (backward compatibility)
              final estimatedPickupTime = orderData['estimatedPickupTime'] is Timestamp
                  ? (orderData['estimatedPickupTime'] as Timestamp).toDate()
                  : DateTime.now(); // Fallback
              
              final pickupTimeStr = orderData['estimatedPickupTime'] is String
                  ? orderData['estimatedPickupTime'] as String
                  : _formatTime(estimatedPickupTime);
              
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text('Order #${orderId.substring(orderId.length - 6).toUpperCase()}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_buildItemsSummary(items)),
                      const SizedBox(height: 4),
                      Text('Pickup: $pickupTimeStr'),
                    ],
                  ),
                  trailing: _buildStatusChip(status),
                  onTap: () {
                    // TODO: Navigate to order details screen
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Timestamp _getTodayStart() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    return Timestamp.fromDate(todayStart);
  }

  String _buildItemsSummary(List<dynamic> items) {
    return items
        .map((item) => '${item['quantity']}× ${item['itemName']}')
        .take(2) // Show only first 2 items
        .join(', ');
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'confirmed':
        color = Colors.blue;
        label = 'Confirmed';
        break;
      case 'preparing':
        color = Colors.purple;
        label = 'Preparing';
        break;
      case 'ready':
        color = Colors.green;
        label = 'Ready!';
        break;
      case 'completed':
        color = Colors.grey;
        label = 'Completed';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.2),
    );
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class MenuItem {
  final String id;
  final String name;
  final double price;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
  });
}

// ============================================================================
// TODO: IMPROVEMENTS FOR PRODUCTION
// ============================================================================

/*
 * 1. Menu Items:
 *    - Store menu in Firestore collection instead of hardcoding
 *    - Add categories (Breakfast, Lunch, Snacks)
 *    - Add images for items
 *    - Add availability status
 * 
 * 2. Error Handling:
 *    - Add proper error states for network failures
 *    - Add retry logic for failed orders
 *    - Show validation errors for empty cart
 * 
 * 3. Loading States:
 *    - Add skeleton loaders while fetching data
 *    - Add progress indicators for all async operations
 * 
 * 4. UI Improvements:
 *    - Add proper styling (colors, fonts, spacing)
 *    - Add animations for status changes
 *    - Add pull-to-refresh on order status screen
 *    - Add search and filters for menu
 * 
 * 5. Notifications:
 *    - Integrate FCM token registration
 *    - Request notification permissions on app start
 *    - Handle notification taps to navigate to order
 * 
 * 6. Offline Support:
 *    - Cache menu items for offline viewing
 *    - Queue orders when offline (tricky with slots)
 *    - Show offline banner
 * 
 * 7. Order Details:
 *    - Add detailed order view screen
 *    - Show order timeline (placed → confirmed → preparing → ready)
 *    - Add cancel order functionality
 */
