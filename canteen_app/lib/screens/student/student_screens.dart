/// Student App Screens
/// 
/// Modern UI for order placement and tracking.
/// Connects to Firestore backend logic.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:canteen_app/services/razorpay_service.dart';
import 'package:canteen_app/utils/upi_qr.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:canteen_app/theme/app_theme.dart';
import 'package:canteen_app/widgets/premium_widgets.dart';
import 'package:canteen_app/widgets/premium_header.dart';

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

/// Menu Item Card - Modern card design for food items
class MenuItemCard extends StatelessWidget {
  final String name;
  final double price;
  final bool isAvailable;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const MenuItemCard({
    super.key,
    required this.name,
    required this.price,
    this.isAvailable = true,
    this.quantity = 0,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isAvailable && quantity == 0 ? onAdd : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dish name - Fixed height with ellipsis
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              
              // Price
              Text(
                '₹${price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              
              // Availability badge or add button - Fixed height
              if (!isAvailable)
                Container(
                  height: 32,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Unavailable',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                )
              else if (quantity == 0)
                SizedBox(
                  height: 36,
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onAdd,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'ADD',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onRemove,
                          borderRadius: BorderRadius.circular(14),
                          child: const Icon(
                            Icons.remove_circle_outline,
                            size: 28,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          quantity.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onAdd,
                          borderRadius: BorderRadius.circular(14),
                          child: Icon(
                            Icons.add_circle,
                            size: 28,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN 1: Menu Listing & Order Placement
// ============================================================================

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Map<String, int> cart = {};
  Map<String, MenuItem> menuItemsCache = {};

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email?.split('@')[0] ?? 'Student';
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: AppTheme.surfaceGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        title: const Text('Canteen Menu', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Premium Greeting Header
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryIndigo,
                  AppTheme.deepIndigo,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppTheme.radiusLarge),
                bottomRight: Radius.circular(AppTheme.radiusLarge),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space20,
              AppTheme.space16,
              AppTheme.space20,
              AppTheme.space24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $userName 👋',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                const Text(
                  'What would you like to eat today?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.space16),
          
          // Premium Menu Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Simple query - sort client-side
              stream: FirebaseFirestore.instance
                  .collection('menu')
                  .where('isAvailable', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Oops! Something went wrong',
                    message: 'Unable to load menu items',
                  );
                }

                if (!snapshot.hasData) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space16,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getCrossAxisCount(context),
                      childAspectRatio: 1.3, // Increased vertical space to prevent overflow
                      crossAxisSpacing: AppTheme.space12,
                      mainAxisSpacing: AppTheme.space12,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return const LoadingShimmer(height: 220);
                    },
                  );
                }

                final menuItems = snapshot.data!.docs;

                if (menuItems.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.restaurant_menu,
                    title: 'No items available',
                    message: 'Check back later for delicious options!',
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space16,
                    AppTheme.space8,
                    AppTheme.space16,
                    AppTheme.space80, // Space for FAB
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(context),
                    childAspectRatio: 1.3, // Increased vertical space to prevent overflow
                    crossAxisSpacing: AppTheme.space12,
                    mainAxisSpacing: AppTheme.space12,
                  ),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final doc = menuItems[index];
                    final item = MenuItem(
                      id: doc.id,
                      name: doc['name'] as String,
                      price: (doc['price'] as num).toDouble(),
                    );
                    
                    menuItemsCache[item.id] = item;
                    final quantity = cart[item.id] ?? 0;
                    
                    return PremiumMenuCard(
                      name: item.name,
                      price: item.price,
                      isAvailable: true,
                      quantity: quantity,
                      onAdd: () => _updateCart(item.id, 1),
                      onRemove: () => _updateCart(item.id, -1),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _proceedToSlotSelection,
              backgroundColor: AppTheme.accentOrange,
              elevation: 4,
              icon: Badge(
                label: Text(
                  _getTotalItems().toString(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppTheme.errorRed,
                child: const Icon(Icons.shopping_cart, color: Colors.white),
              ),
              label: Text(
                'Checkout • ₹${_getTotalAmount().toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2;
  }

  void _updateCart(String itemId, int delta) {
    debugPrint('🛒 Cart Update: itemId=$itemId, delta=$delta, currentQty=${cart[itemId] ?? 0}');
    setState(() {
      final currentQty = cart[itemId] ?? 0;
      final newQty = currentQty + delta;
      
      if (newQty <= 0) {
        cart.remove(itemId);
        debugPrint('🛒 Item removed from cart: $itemId');
      } else {
        cart[itemId] = newQty;
        debugPrint('🛒 Cart updated: $itemId → quantity=$newQty');
      }
      
      debugPrint('🛒 Total items in cart: ${_getTotalItems()}');
    });
  }

  int _getTotalItems() {
    return cart.values.fold(0, (total, qty) => total + qty);
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
    final cartItems = cart.entries.map((e) {
      return MenuItem(
        id: e.key,
        name: menuItemsCache[e.key]!.name,
        price: menuItemsCache[e.key]!.price,
      );
    }).toList();
    
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
    super.key,
    required this.cart,
    required this.menuItems,
  });

  @override
  State<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends State<SlotSelectionScreen> {
  String? selectedSlotId;
  bool isPlacingOrder = false;

  @override
  Widget build(BuildContext context) {
    final totalAmount = _calculateTotal();

    return Scaffold(
      backgroundColor: AppTheme.surfaceGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        title: const Text('Select Pickup Time', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Premium Order Summary Card
          Container(
            margin: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryIndigo, AppTheme.deepIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                ..._buildOrderSummary(),
                const Divider(color: Colors.white30, height: AppTheme.space24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '₹${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Section Header
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.space20,
              AppTheme.space8,
              AppTheme.space20,
              AppTheme.space12,
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: AppTheme.space8),
                Text(
                  'Choose Pickup Slot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          
          // Premium Slot Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Simple query - filter and sort client-side
              stream: FirebaseFirestore.instance
                  .collection('orderSlots')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyStateWidget(
                    icon: Icons.error_outline,
                    title: 'Oops! Something went wrong',
                    message: 'Unable to load pickup slots',
                  );
                }

                if (!snapshot.hasData) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: AppTheme.space12,
                      mainAxisSpacing: AppTheme.space12,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) => const LoadingShimmer(height: 80),
                  );
                }
                
                // Filter and sort client-side
                final todayDate = _getTodayDate();
                var slots = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['date'] == todayDate && data['isActive'] == true;
                }).toList();
                
                slots.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['startTime'];
                  final bTime = bData['startTime'];
                  
                  // Handle both Timestamp and String types
                  final aComparable = aTime is Timestamp ? aTime.toDate() : DateTime.tryParse(aTime.toString()) ?? DateTime(2000);
                  final bComparable = bTime is Timestamp ? bTime.toDate() : DateTime.tryParse(bTime.toString()) ?? DateTime(2000);
                  
                  return aComparable.compareTo(bComparable);
                });
                final allSlots = snapshot.data!.docs;
                final now = DateTime.now();
                final validSlots = allSlots.where((slotDoc) {
                  final slotData = slotDoc.data() as Map<String, dynamic>;
                  return _isValidSlot(slotData, now);
                }).toList();

                if (validSlots.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.schedule_outlined,
                    title: 'No slots available',
                    message: 'All pickup slots for today are full. Please try again tomorrow.',
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space16,
                    AppTheme.space8,
                    AppTheme.space16,
                    AppTheme.space80,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(context),
                    childAspectRatio: 2.2,
                    crossAxisSpacing: AppTheme.space12,
                    mainAxisSpacing: AppTheme.space12,
                  ),
                  itemCount: validSlots.length,
                  itemBuilder: (context, index) {
                    final slotData = validSlots[index].data() as Map<String, dynamic>;
                    final slotId = validSlots[index].id;
                    
                    DateTime? startTime;
                    try {
                      final startTimeField = slotData['startTime'];
                      if (startTimeField is Timestamp) {
                        startTime = startTimeField.toDate();
                      } else if (startTimeField is String) {
                        final parts = startTimeField.split(':');
                        final now = DateTime.now();
                        startTime = DateTime(now.year, now.month, now.day, 
                          int.parse(parts[0]), int.parse(parts[1]));
                      }
                    } catch (e) {
                      return const SizedBox.shrink();
                    }
                    
                    if (startTime == null) return const SizedBox.shrink();
                    
                    final currentCount = slotData['bookedCount'] ?? slotData['currentCount'] ?? 0;
                    final maxCapacity = slotData['capacity'] ?? slotData['maxCapacity'] ?? 30;

                    return SlotChip(
                      timeRange: _formatTime(startTime),
                      bookedCount: currentCount,
                      capacity: maxCapacity,
                      isSelected: selectedSlotId == slotId,
                      isEnabled: true,
                      onTap: () {
                        setState(() {
                          selectedSlotId = slotId;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: selectedSlotId != null
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.space16),
                  child: ElevatedButton(
                    onPressed: isPlacingOrder ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      elevation: 2,
                    ),
                    child: isPlacingOrder
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Place Order',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 600) return 3;
    return 2;
  }

  double _calculateTotal() {
    double total = 0;
    widget.cart.forEach((itemId, quantity) {
      final item = widget.menuItems.firstWhere((m) => m.id == itemId);
      total += item.price * quantity;
    });
    return total;
  }

  List<Widget> _buildOrderSummary() {
    List<Widget> widgets = [];
    widget.cart.forEach((itemId, quantity) {
      final item = widget.menuItems.firstWhere((m) => m.id == itemId);
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$quantity × ${item.name}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              Text(
                '₹${(item.price * quantity).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    });
    return widgets;
  }

  /// Validate if slot is in the future
  /// 
  /// Returns true if:
  /// - Slot date > today OR
  /// - Slot date == today AND slot time > current time
  /// 
  /// Handles both Timestamp and String ("HH:mm") formats
  bool _isValidSlot(Map<String, dynamic> slotData, DateTime now) {
    try {
      // Parse slot date - handle both Timestamp and String formats
      final slotDateField = slotData['date'];
      String? slotDateStr;
      
      if (slotDateField is Timestamp) {
        final dt = slotDateField.toDate();
        slotDateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } else if (slotDateField is String) {
        slotDateStr = slotDateField;
      }
      
      if (slotDateStr == null) return false;
      
      final dateParts = slotDateStr.split('-');
      if (dateParts.length != 3) return false;
      
      final slotDate = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
      
      final today = DateTime(now.year, now.month, now.day);
      
      // If slot is on a future date, it's valid
      if (slotDate.isAfter(today)) {
        return true;
      }
      
      // If slot is in the past, it's invalid
      if (slotDate.isBefore(today)) {
        return false;
      }
      
      // Slot is today - check time
      DateTime? slotTime;
      final startTimeField = slotData['startTime'];
      
      if (startTimeField is Timestamp) {
        slotTime = startTimeField.toDate();
      } else if (startTimeField is String) {
        // Parse "HH:mm" format
        final parts = startTimeField.split(':');
        if (parts.length != 2) return false;
        
        slotTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      } else {
        return false;
      }
      
      // Slot must be in the future (at least current time)
      return slotTime.isAfter(now);
      
    } catch (e) {
      // Invalid slot data - exclude it
      return false;
    }
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
          'status': 'confirmed', // AUTO-CONFIRM: Changed from 'pending' to allow immediate payment
          'placedAt': now,
          'confirmedAt': now, // Set immediately for payment flow
          'readyAt': null,
          'completedAt': null,
          'pickupVerified': false,
          'pickupVerifiedAt': null,
          'cancellationReason': null,
          // Payment fields (independent from order status)
          'paymentStatus': 'unpaid', // unpaid | verification_pending | paid | failed
          'paymentMethod': null, // QR | RAZORPAY
          'razorpayPaymentId': null,
          'paidAt': null,
          'markedPaidAt': null, // For QR payments
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
        const SnackBar(
          content: Text('✅ Order confirmed! Please complete payment to proceed.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
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
// SCREEN 3: Order Status Tracking with Payment (Real-time)
// ============================================================================

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  final RazorpayService _razorpayService = RazorpayService();
  final Map<String, DateTime> _processingPayments = {}; // Track orderId -> timestamp
  Timer? _paymentTimeoutTimer;

  @override
  void initState() {
    super.initState();
    
    // Only initialize Razorpay on Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        _razorpayService.initialize(
          onSuccess: _handlePaymentSuccess,
          onFailure: _handlePaymentFailure,
        );
      } catch (e) {
        debugPrint('Razorpay initialization failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _paymentTimeoutTimer?.cancel();
    _razorpayService.dispose();
    super.dispose();
  }

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
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Simple query - filter and sort client-side
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Get all orders and sort by placedAt timestamp (latest first)
          var orders = snapshot.data!.docs.toList();
          
          // Sort orders: LATEST to OLDEST (descending by placedAt)
          orders.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['placedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bTime = (bData['placedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            // bTime.compareTo(aTime) ensures latest orders appear at TOP
            return bTime.compareTo(aTime);
          });

          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet. Place your first order!'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderDoc = orders[index];
              return _buildOrderCard(orderDoc, user);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(DocumentSnapshot orderDoc, User user) {
    final orderData = orderDoc.data() as Map<String, dynamic>;
    final orderId = orderDoc.id;
    final status = orderData['status'] as String;
    final paymentStatus = orderData['paymentStatus'] as String? ?? 'UNPAID';
    final items = orderData['items'] as List<dynamic>;
    final totalAmount = (orderData['totalAmount'] as num).toDouble();
    
    // Handle both String and Timestamp formats
    final estimatedPickupTime = orderData['estimatedPickupTime'] is Timestamp
        ? (orderData['estimatedPickupTime'] as Timestamp).toDate()
        : DateTime.now();
    
    final pickupTimeStr = orderData['estimatedPickupTime'] is String
        ? orderData['estimatedPickupTime'] as String
        : _formatTime(estimatedPickupTime);
    
    final isProcessing = _processingPayments.containsKey(orderId);
    final canPay = status == 'confirmed' && !['paid', 'verification_pending'].contains(paymentStatus) && !isProcessing;

    return Card(
      margin: const EdgeInsets.all(12.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header with BOTH statuses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${orderId.substring(orderId.length - 6).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PremiumStatusChip(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            
            // Premium status timeline (only show if paid)
            if (paymentStatus == 'paid' && ['confirmed', 'preparing', 'ready', 'completed'].contains(status)) ...[
              OrderStatusTimeline(
                currentStatus: status,
                paymentStatus: paymentStatus,
              ),
              const SizedBox(height: 12),
            ],
            
            // Items summary
            Text(
              _buildItemsSummary(items),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            
            // Pickup time
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Pickup: $pickupTimeStr',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Total amount
            Row(
              children: [
                Icon(Icons.currency_rupee, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Total: ₹${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // Remove payment badge from here - it's now in header
              ],
            ),
            
            // Payment button (only for confirmed orders)
            if (status == 'confirmed') ...[
              const SizedBox(height: 12),
              if (kIsWeb)
                // Web users - Show UPI QR payment
                _buildWebQrPayment(orderId, totalAmount, paymentStatus)
              else if (paymentStatus == 'paid')
                // Already paid - show confirmation
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Payment completed - Kitchen preparing your order',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else if (paymentStatus == 'verification_pending')
                // Verification pending
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.hourglass_empty, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Payment verification pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Show Pay Now button on Android
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: canPay
                        ? () => _initiatePayment(orderId, totalAmount, user)
                        : null,
                    icon: isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payment),
                    label: Text(
                      isProcessing ? 'Processing...' : 'Pay Now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                  ),
                ),
            ],
            
            // Waiting message for non-confirmed orders
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Waiting for admin confirmation',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _initiatePayment(String orderId, double amount, User user) async {
    print('═══════════════════════════════════════════════════════');
    print('💳 INITIATING PAYMENT');
    print('═══════════════════════════════════════════════════════');
    print('Order ID: $orderId');
    print('Amount: ₹$amount');
    print('User ID: ${user.uid}');
    print('═══════════════════════════════════════════════════════');
    
    // Prevent duplicate payment attempts
    if (_processingPayments.containsKey(orderId)) {
      print('⚠️ Payment already in progress for order $orderId');
      debugPrint('Payment already in progress for order $orderId');
      return;
    }

    setState(() {
      _processingPayments[orderId] = DateTime.now();
    });
    
    print('✅ Order added to processing payments map');
    print('Current processing payments: $_processingPayments');

    // Set timeout to prevent infinite loading (3 minutes)
    _paymentTimeoutTimer = Timer(const Duration(minutes: 3), () {
      if (_processingPayments.containsKey(orderId)) {
        print('⏰ Payment timeout triggered for order: $orderId');
        _handlePaymentTimeout(orderId);
      }
    });

    try {
      // Platform check (double safety)
      if (kIsWeb) {
        throw UnsupportedError('Payment not available on Web. Please use Android app.');
      }

      // Fetch user details for prefill
      print('📋 Fetching user details...');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data();
      final userEmail = userData?['email'] ?? user.email ?? 'no-email@example.com';
      final userPhone = userData?['phoneNumber'] ?? userData?['phone'] ?? '0000000000';

      print('✅ User details fetched');
      print('Email: $userEmail');
      print('Phone: $userPhone');
      print('🚀 Calling Razorpay startPayment...');

      // Start Razorpay payment
      _razorpayService.startPayment(
        amountInRupees: amount,
        orderId: orderId,
        userEmail: userEmail,
        userPhone: userPhone,
      );
      
      print('✅ Razorpay startPayment called successfully');

    } catch (e, stackTrace) {
      print('❌ PAYMENT INITIATION ERROR');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      debugPrint('❌ Payment initiation error: $e');
      
      setState(() {
        _processingPayments.remove(orderId);
      });
      _paymentTimeoutTimer?.cancel();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initiatePayment(orderId, amount, user),
            ),
          ),
        );
      }
    }
  }

  void _handlePaymentSuccess(String paymentId) async {
    print('═══════════════════════════════════════════════════════');
    print('🎉 PAYMENT SUCCESS HANDLER CALLED');
    print('═══════════════════════════════════════════════════════');
    print('Payment ID: $paymentId');
    print('Processing payments map: $_processingPayments');
    print('═══════════════════════════════════════════════════════');
    
    // Cancel timeout timer
    _paymentTimeoutTimer?.cancel();

    // Find the order being processed (should be only one)
    final orderId = _processingPayments.keys.isNotEmpty 
        ? _processingPayments.keys.first 
        : null;

    if (orderId == null) {
      debugPrint('⚠️ Payment success but no order ID tracked');
      print('❌ ERROR: orderId is null! Cannot update Firestore.');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful (ID: $paymentId) but order not found. Please contact support.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }
      return;
    }

    print('📝 Updating Firestore for order: $orderId');

    try {
      // CRITICAL: Update payment status in Firestore IMMEDIATELY
      // Do NOT wait for webhooks or external confirmation
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'paymentStatus': 'paid',
        'paymentMethod': 'RAZORPAY',
        'razorpayPaymentId': paymentId,
        'paidAt': FieldValue.serverTimestamp(),
      });

      print('✅ Firestore updated successfully!');
      print('   Order ID: $orderId');
      print('   Payment Status: paid');
      print('   Payment ID: $paymentId');

      if (mounted) {
        setState(() {
          _processingPayments.remove(orderId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Payment successful! Order confirmed.'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ CRITICAL ERROR: Failed to update payment status in Firestore!');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      
      // Retry mechanism
      bool retrySuccess = false;
      for (int i = 1; i <= 3; i++) {
        print('🔄 Retry attempt $i/3...');
        await Future.delayed(Duration(seconds: i));
        
        try {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .update({
            'paymentStatus': 'paid',
            'paymentMethod': 'RAZORPAY',
            'razorpayPaymentId': paymentId,
            'paidAt': FieldValue.serverTimestamp(),
          });
          
          print('✅ Retry $i successful!');
          retrySuccess = true;
          break;
        } catch (retryError) {
          print('❌ Retry $i failed: $retryError');
        }
      }
      
      if (mounted) {
        setState(() {
          _processingPayments.remove(orderId);
        });
        
        if (!retrySuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ Payment recorded but update failed'),
                  const SizedBox(height: 4),
                  Text('Payment ID: $paymentId', style: const TextStyle(fontSize: 12)),
                  Text('Order ID: $orderId', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('Please contact support to confirm your order.', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 15),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Payment successful (after retry)!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _handlePaymentFailure(String error) {
    // Cancel timeout timer
    _paymentTimeoutTimer?.cancel();

    // Find the order being processed
    final orderId = _processingPayments.keys.isNotEmpty 
        ? _processingPayments.keys.first 
        : null;

    debugPrint('❌ Payment failed: $error');

    if (orderId != null) {
      setState(() {
        _processingPayments.remove(orderId);
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              if (orderId != null) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  // Get amount from Firestore and retry
                  FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .get()
                      .then((doc) {
                    if (doc.exists) {
                      final data = doc.data() as Map<String, dynamic>;
                      final amount = (data['totalAmount'] as num).toDouble();
                      _initiatePayment(orderId, amount, user);
                    }
                  });
                }
              }
            },
          ),
        ),
      );
    }
  }

  void _handlePaymentTimeout(String orderId) {
    debugPrint('⏰ Payment timeout for order: $orderId');

    setState(() {
      _processingPayments.remove(orderId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.timer_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payment timed out. If you completed payment, it will reflect shortly. Otherwise, please retry.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderId)
                    .get()
                    .then((doc) {
                  if (doc.exists) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = (data['totalAmount'] as num).toDouble();
                    _initiatePayment(orderId, amount, user);
                  }
                });
              }
            },
          ),
        ),
      );
    }
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

  Widget _buildWebQrPayment(String orderId, double amount, String paymentStatus) {
    if (paymentStatus == 'paid') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'Payment completed - Kitchen preparing your order',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (paymentStatus == 'verification_pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: const Column(
          children: [
            Icon(Icons.pending_outlined, color: Colors.orange, size: 32),
            SizedBox(height: 8),
            Text(
              'Payment verification pending',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Admin will verify your payment shortly',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Generate UPI QR code
    final merchantConfig = UpiQrGenerator.getMerchantConfig();
    final upiUri = UpiQrGenerator.generateUpiUri(
      upiId: merchantConfig['upiId']!,
      name: merchantConfig['name']!,
      amount: amount,
      transactionNote: 'Order #${orderId.substring(orderId.length - 6).toUpperCase()}',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        children: [
          // Title
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Scan to Pay via UPI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: upiUri,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 16),

          // Amount display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.currency_rupee, color: Colors.green, size: 20),
                Text(
                  amount.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // UPI app logos
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pay using: ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Google Pay • PhonePe • Paytm • BHIM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Warning message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment will be verified by admin before order completion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // I've Paid button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _markPaidByUser(orderId),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                "I've Paid",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markPaidByUser(String orderId) async {
    try {
      // ✅ ONLY update payment status, NOT order status
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'paymentStatus': 'verification_pending',
        'paymentMethod': 'QR',
        'markedPaidAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment marked. Admin will verify shortly.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
