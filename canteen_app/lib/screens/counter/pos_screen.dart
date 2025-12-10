/// Point of Sale (POS) Screen - Counter Order Creation
/// 
/// ERP-style POS for counter staff:
/// - Browse available menu items
/// - Add to cart with quantities
/// - Multiple payment methods:
///   1. Wallet QR Scan - Deduct from student wallet
///   2. UPI QR - Show QR for customer to pay
///   3. Cash - Manual cash collection
/// - Generate order with proper tracking
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:canteen_app/theme/app_theme.dart';
import 'package:canteen_app/services/wallet_service.dart';
import 'package:canteen_app/utils/upi_qr.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  // Cart state
  final Map<String, int> _cart = {};
  final Map<String, Map<String, dynamic>> _cartItems = {};
  
  // Menu categories
  String _selectedCategory = 'All';
  
  // Loading state
  bool _isProcessing = false;
  
  // Customer info (for wallet payment)
  Map<String, dynamic>? _customer;
  double? _customerBalance;
  
  // Services
  final WalletService _walletService = WalletService();

  // Calculate total
  double get _totalAmount {
    double total = 0;
    _cart.forEach((itemId, qty) {
      final item = _cartItems[itemId];
      if (item != null) {
        total += (item['price'] as double) * qty;
      }
    });
    return total;
  }

  // Get item count
  int get _itemCount {
    int count = 0;
    _cart.forEach((_, qty) => count += qty);
    return count;
  }

  // Check if device is mobile (narrow screen)
  bool _isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    
    if (isMobile) {
      // Mobile: Single column with floating cart button
      return Stack(
        children: [
          _buildMenuSection(),
          // Floating cart button
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildFloatingCartButton(context),
          ),
        ],
      );
    }
    
    // Desktop/Tablet: Side-by-side layout
    return Row(
      children: [
        // Left: Menu Items (70%)
        Expanded(
          flex: 7,
          child: _buildMenuSection(),
        ),
        // Right: Cart & Checkout (30%)
        SizedBox(
          width: 320,
          child: _buildCartSection(),
        ),
      ],
    );
  }

  // Calculate grid columns based on screen width
  int _getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 2;
    if (width < 600) return 3;
    if (width < 900) return 3;
    return 4;
  }

  // Floating cart button for mobile view
  Widget _buildFloatingCartButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showCartBottomSheet(context),
      backgroundColor: AppTheme.primaryIndigo,
      icon: Badge(
        label: Text('$_itemCount'),
        isLabelVisible: _itemCount > 0,
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
      label: Text(
        _totalAmount > 0 ? '₹${_totalAmount.toStringAsFixed(0)}' : 'Cart',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Cart bottom sheet for mobile
  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Cart content
              Expanded(child: _buildCartSection()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      color: AppTheme.surfaceGrey,
      child: Column(
        children: [
          // Category tabs
          _buildCategoryTabs(),
          // Menu grid
          Expanded(
            child: _buildMenuGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('menu').snapshots(),
      builder: (context, snapshot) {
        Set<String> categories = {'All'};
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['category'] != null) {
              categories.add(data['category'] as String);
            }
          }
        }
        
        return Container(
          height: 56,
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  backgroundColor: Colors.grey[100],
                  selectedColor: AppTheme.lightOrange,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.deepOrange : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMenuGrid() {
    Query query = FirebaseFirestore.instance
        .collection('menu')
        .where('isAvailable', isEqualTo: true);
    
    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;
        if (items.isEmpty) {
          return const Center(
            child: Text('No items available in this category'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getGridColumns(context),
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final doc = items[index];
            final data = doc.data() as Map<String, dynamic>;
            final itemId = doc.id;
            final name = data['name'] as String;
            final price = (data['price'] as num).toDouble();
            final qty = _cart[itemId] ?? 0;

            return _buildMenuItem(itemId, name, price, qty, data);
          },
        );
      },
    );
  }

  Widget _buildMenuItem(String itemId, String name, double price, int qty, Map<String, dynamic> data) {
    return Card(
      elevation: qty > 0 ? 4 : 1,
      color: qty > 0 ? AppTheme.lightOrange : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: qty > 0 
            ? BorderSide(color: AppTheme.accentOrange, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _cart[itemId] = (qty + 1);
            _cartItems[itemId] = {
              'id': itemId,
              'name': name,
              'price': price,
              ...data,
            };
          });
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Item icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.lightIndigo,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant,
                  color: AppTheme.primaryIndigo,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              // Name
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Price
              Text(
                '₹${price.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppTheme.deepOrange,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              // Quantity controls if in cart
              if (qty > 0) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQtyButton(
                        icon: Icons.remove,
                        onTap: () {
                          setState(() {
                            if (qty <= 1) {
                              _cart.remove(itemId);
                              _cartItems.remove(itemId);
                            } else {
                              _cart[itemId] = qty - 1;
                            }
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildQtyButton(
                        icon: Icons.add,
                        onTap: () {
                          setState(() {
                            _cart[itemId] = qty + 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGrey,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildCartSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cart header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryIndigo,
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Cart ($_itemCount items)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (_cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                    onPressed: () {
                      setState(() {
                        _cart.clear();
                        _cartItems.clear();
                        _customer = null;
                        _customerBalance = null;
                      });
                    },
                    tooltip: 'Clear cart',
                    iconSize: 20,
                  ),
              ],
            ),
          ),
          
          // Customer info (if scanned)
          if (_customer != null) _buildCustomerCard(),
          
          // Cart items
          Expanded(
            child: _cart.isEmpty
                ? _buildEmptyCart()
                : _buildCartItems(),
          ),
          
          // Totals & payment buttons
          if (_cart.isNotEmpty) _buildCheckoutSection(),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.successGreen, Colors.green[700]!],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white24,
            child: Text(
              (_customer!['userName'] as String)[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customer!['userName'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Balance: ₹${_customerBalance?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    color: _customerBalance != null && _customerBalance! >= _totalAmount
                        ? Colors.white70
                        : Colors.red[200],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () {
              setState(() {
                _customer = null;
                _customerBalance = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Cart is empty',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap items to add',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _cart.entries.map((entry) {
        final item = _cartItems[entry.key]!;
        final qty = entry.value;
        final price = item['price'] as double;
        final subtotal = price * qty;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceGrey,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${price.toStringAsFixed(0)} × $qty',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${subtotal.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCheckoutSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(
                '₹${_totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.deepOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Payment buttons
          Row(
            children: [
              // Wallet QR Payment
              Expanded(
                child: _buildPaymentButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Wallet QR',
                  color: AppTheme.primaryIndigo,
                  onTap: _showWalletQRScanner,
                ),
              ),
              const SizedBox(width: 8),
              // UPI Payment
              Expanded(
                child: _buildPaymentButton(
                  icon: Icons.account_balance,
                  label: 'UPI',
                  color: AppTheme.successGreen,
                  onTap: _showUPIPaymentDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Cash Payment
          SizedBox(
            width: double.infinity,
            child: _buildPaymentButton(
              icon: Icons.payments,
              label: 'Cash Payment',
              color: AppTheme.accentOrange,
              onTap: _processCashPayment,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      ),
    );
  }

  // ============================================================================
  // PAYMENT METHODS
  // ============================================================================

  /// Show QR Scanner for Wallet Payment
  void _showWalletQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _WalletQRScannerSheet(
          onScanned: (customerData, balance) {
            Navigator.pop(context);
            setState(() {
              _customer = customerData;
              _customerBalance = balance;
            });
            // Process wallet payment
            _processWalletPayment();
          },
          walletService: _walletService,
        ),
      ),
    );
  }

  /// Process payment from student wallet
  Future<void> _processWalletPayment() async {
    if (_customer == null || _cart.isEmpty) return;
    
    if (_customerBalance != null && _customerBalance! < _totalAmount) {
      _showError('Insufficient wallet balance!');
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      final adminId = FirebaseAuth.instance.currentUser!.uid;
      final studentId = _customer!['userId'] as String;
      final studentName = _customer!['userName'] as String;
      
      // Build order items
      List<Map<String, dynamic>> items = [];
      _cart.forEach((itemId, qty) {
        final item = _cartItems[itemId]!;
        items.add({
          'itemId': itemId,
          'itemName': item['name'],
          'quantity': qty,
          'price': item['price'],
          'subtotal': (item['price'] as double) * qty,
        });
      });
      
      // Create order
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final now = Timestamp.now();
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(orderRef, {
          'orderId': orderRef.id,
          'userId': studentId,
          'userName': studentName,
          'items': items,
          'totalAmount': _totalAmount,
          'status': 'completed',
          'placedAt': now,
          'confirmedAt': now,
          'completedAt': now,
          'orderType': 'counter',
          'paymentStatus': 'paid',
          'paymentMethod': 'WALLET',
          'paidAt': now,
          'counterId': adminId,
        });
      });
      
      // Deduct from wallet
      await _walletService.deductPayment(
        studentId: studentId,
        amount: _totalAmount,
        orderId: orderRef.id,
        adminId: adminId,
      );
      
      if (!mounted) return;
      
      _showSuccessDialog(
        title: 'Wallet Payment Successful',
        message: 'Amount ₹${_totalAmount.toStringAsFixed(2)} deducted from ${studentName}\'s wallet',
        orderId: orderRef.id,
      );
      
      _clearCart();
      
    } catch (e) {
      _showError('Payment failed: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Show UPI QR for customer to pay
  void _showUPIPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UPIPaymentDialog(
        amount: _totalAmount,
        onPaymentConfirmed: (transactionId) {
          Navigator.pop(context);
          _processUPIPayment(transactionId);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  /// Process UPI Payment (after customer pays)
  Future<void> _processUPIPayment(String transactionId) async {
    setState(() => _isProcessing = true);
    
    try {
      final adminId = FirebaseAuth.instance.currentUser!.uid;
      
      // Build order items
      List<Map<String, dynamic>> items = [];
      _cart.forEach((itemId, qty) {
        final item = _cartItems[itemId]!;
        items.add({
          'itemId': itemId,
          'itemName': item['name'],
          'quantity': qty,
          'price': item['price'],
          'subtotal': (item['price'] as double) * qty,
        });
      });
      
      // Create order
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final now = Timestamp.now();
      
      await orderRef.set({
        'orderId': orderRef.id,
        'userId': 'walk-in',
        'userName': 'Walk-in Customer',
        'items': items,
        'totalAmount': _totalAmount,
        'status': 'completed',
        'placedAt': now,
        'confirmedAt': now,
        'completedAt': now,
        'orderType': 'counter',
        'paymentStatus': 'paid',
        'paymentMethod': 'UPI',
        'upiTransactionId': transactionId,
        'paidAt': now,
        'counterId': adminId,
      });
      
      if (!mounted) return;
      
      _showSuccessDialog(
        title: 'UPI Payment Received',
        message: 'Transaction ID: $transactionId',
        orderId: orderRef.id,
      );
      
      _clearCart();
      
    } catch (e) {
      _showError('Failed to create order: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Process Cash Payment
  Future<void> _processCashPayment() async {
    // Show cash received confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cash Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${_totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Confirm cash received from customer?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
            ),
            child: const Text('Cash Received'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final adminId = FirebaseAuth.instance.currentUser!.uid;
      
      // Build order items
      List<Map<String, dynamic>> items = [];
      _cart.forEach((itemId, qty) {
        final item = _cartItems[itemId]!;
        items.add({
          'itemId': itemId,
          'itemName': item['name'],
          'quantity': qty,
          'price': item['price'],
          'subtotal': (item['price'] as double) * qty,
        });
      });
      
      // Create order
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final now = Timestamp.now();
      
      await orderRef.set({
        'orderId': orderRef.id,
        'userId': 'walk-in',
        'userName': 'Walk-in Customer',
        'items': items,
        'totalAmount': _totalAmount,
        'status': 'completed',
        'placedAt': now,
        'confirmedAt': now,
        'completedAt': now,
        'orderType': 'counter',
        'paymentStatus': 'paid',
        'paymentMethod': 'CASH',
        'paidAt': now,
        'counterId': adminId,
      });
      
      if (!mounted) return;
      
      _showSuccessDialog(
        title: 'Cash Payment Recorded',
        message: 'Order created successfully',
        orderId: orderRef.id,
      );
      
      _clearCart();
      
    } catch (e) {
      _showError('Failed to create order: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _cartItems.clear();
      _customer = null;
      _customerBalance = null;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
      ),
    );
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required String orderId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 8),
            Text(
              'Order #${orderId.substring(orderId.length - 6).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WALLET QR SCANNER SHEET
// ============================================================================

class _WalletQRScannerSheet extends StatefulWidget {
  final Function(Map<String, dynamic> customer, double balance) onScanned;
  final WalletService walletService;

  const _WalletQRScannerSheet({
    required this.onScanned,
    required this.walletService,
  });

  @override
  State<_WalletQRScannerSheet> createState() => _WalletQRScannerSheetState();
}

class _WalletQRScannerSheetState extends State<_WalletQRScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final parsed = WalletService.parsePaymentQR(barcode.rawValue!);
      
      if (parsed == null || parsed['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parsed?['error'] ?? 'Invalid QR code'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        setState(() => _isProcessing = false);
        return;
      }
      
      final userId = parsed['userId'] as String;
      final userDetails = await widget.walletService.getUserDetails(userId);
      
      if (userDetails == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student not found'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        setState(() => _isProcessing = false);
        return;
      }
      
      final balance = await widget.walletService.getBalance(userId);
      
      widget.onScanned({
        ...parsed,
        'email': userDetails['email'],
      }, balance);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Title
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.qr_code_scanner, color: AppTheme.primaryIndigo),
              const SizedBox(width: 12),
              const Text(
                'Scan Student Wallet QR',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        // Scanner
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryIndigo, width: 3),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Instructions
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Point camera at student\'s wallet QR code',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// UPI PAYMENT DIALOG
// ============================================================================

class _UPIPaymentDialog extends StatefulWidget {
  final double amount;
  final Function(String transactionId) onPaymentConfirmed;
  final VoidCallback onCancel;

  const _UPIPaymentDialog({
    required this.amount,
    required this.onPaymentConfirmed,
    required this.onCancel,
  });

  @override
  State<_UPIPaymentDialog> createState() => _UPIPaymentDialogState();
}

class _UPIPaymentDialogState extends State<_UPIPaymentDialog> {
  final TextEditingController _transactionIdController = TextEditingController();
  bool _showTransactionInput = false;

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = UpiQrGenerator.getMerchantConfig();
    final upiUri = UpiQrGenerator.generateUpiUri(
      upiId: config['upiId']!,
      name: config['name']!,
      amount: widget.amount,
      transactionNote: 'Canteen Order Payment',
    );

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance, color: AppTheme.successGreen),
          const SizedBox(width: 12),
          const Text('UPI Payment'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Amount
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Column(
                children: [
                  const Text('Amount to Pay'),
                  Text(
                    '₹${widget.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // QR Code
            if (!_showTransactionInput) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: QrImageView(
                  data: upiUri,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Customer scans to pay via any UPI app',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _showTransactionInput = true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                ),
                child: const Text('Payment Received'),
              ),
            ] else ...[
              // Transaction ID input
              const Text(
                'Enter UPI Transaction ID:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _transactionIdController,
                decoration: InputDecoration(
                  hintText: 'e.g., 123456789012',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _showTransactionInput = false);
                    },
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final txId = _transactionIdController.text.trim();
                      if (txId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter transaction ID'),
                          ),
                        );
                        return;
                      }
                      widget.onPaymentConfirmed(txId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                    ),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
