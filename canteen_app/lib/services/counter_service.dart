/// Counter Service - ERP Backend Logic
/// 
/// Manages counter operations following ERP principles:
/// - Order creation and management
/// - Payment processing (Wallet, UPI, Cash)
/// - Sales tracking and reporting
/// - Inventory adjustments (future)
/// - Shift management (future)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Counter Service for Point of Sale operations
class CounterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // ORDER MANAGEMENT
  // ============================================================================

  /// Create a counter order
  /// 
  /// Unlike app orders, counter orders are typically completed immediately.
  /// Supports different payment methods: WALLET, UPI, CASH
  Future<String> createCounterOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String? customerId,
    String? customerName,
    String? upiTransactionId,
    String? walletTransactionId,
  }) async {
    final counterId = _auth.currentUser?.uid;
    if (counterId == null) {
      throw Exception('Counter staff not logged in');
    }

    final orderRef = _firestore.collection('orders').doc();
    final now = Timestamp.now();

    final orderData = {
      'orderId': orderRef.id,
      'userId': customerId ?? 'walk-in',
      'userName': customerName ?? 'Walk-in Customer',
      'items': items,
      'totalAmount': totalAmount,
      'status': 'completed',
      'placedAt': now,
      'confirmedAt': now,
      'completedAt': now,
      'orderType': 'counter',
      'paymentStatus': 'paid',
      'paymentMethod': paymentMethod,
      'paidAt': now,
      'counterId': counterId,
    };

    // Add transaction IDs if provided
    if (upiTransactionId != null) {
      orderData['upiTransactionId'] = upiTransactionId;
    }
    if (walletTransactionId != null) {
      orderData['walletTransactionId'] = walletTransactionId;
    }

    await orderRef.set(orderData);
    
    // Update daily sales summary
    await _updateDailySales(totalAmount, paymentMethod, items);
    
    return orderRef.id;
  }

  /// Update daily sales summary for reporting
  Future<void> _updateDailySales(
    double amount,
    String paymentMethod,
    List<Map<String, dynamic>> items,
  ) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final summaryRef = _firestore.collection('counter_daily_summary').doc(dateKey);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(summaryRef);
      
      if (doc.exists) {
        final data = doc.data()!;
        transaction.update(summaryRef, {
          'totalSales': (data['totalSales'] as num? ?? 0) + amount,
          'orderCount': (data['orderCount'] as num? ?? 0) + 1,
          'paymentMethods.$paymentMethod': 
              (data['paymentMethods']?[paymentMethod] as num? ?? 0) + amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(summaryRef, {
          'date': dateKey,
          'totalSales': amount,
          'orderCount': 1,
          'paymentMethods': {
            'WALLET': paymentMethod == 'WALLET' ? amount : 0,
            'UPI': paymentMethod == 'UPI' ? amount : 0,
            'CASH': paymentMethod == 'CASH' ? amount : 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Update item sales
      for (var item in items) {
        final itemName = item['itemName'] as String;
        final qty = item['quantity'] as int;
        final itemPrice = item['price'] as double;
        
        final itemKey = itemName.replaceAll('.', '_').replaceAll('/', '_');
        final itemSalesRef = _firestore.collection('counter_item_sales').doc('$dateKey-$itemKey');
        
        final itemDoc = await transaction.get(itemSalesRef);
        if (itemDoc.exists) {
          transaction.update(itemSalesRef, {
            'quantity': FieldValue.increment(qty),
            'totalSales': FieldValue.increment(itemPrice * qty),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(itemSalesRef, {
            'date': dateKey,
            'itemName': itemName,
            'quantity': qty,
            'totalSales': itemPrice * qty,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  // ============================================================================
  // REPORTING
  // ============================================================================

  /// Get counter orders for a specific date range
  Stream<QuerySnapshot> getCounterOrders({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
  }) {
    Query query = _firestore
        .collection('orders')
        .where('orderType', isEqualTo: 'counter');
    
    if (startDate != null) {
      query = query.where('placedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('placedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    if (paymentMethod != null && paymentMethod != 'All') {
      query = query.where('paymentMethod', isEqualTo: paymentMethod);
    }
    
    return query.orderBy('placedAt', descending: true).snapshots();
  }

  /// Get daily summary for reporting
  Future<Map<String, dynamic>?> getDailySummary(DateTime date) async {
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    final doc = await _firestore.collection('counter_daily_summary').doc(dateKey).get();
    return doc.data();
  }

  /// Get sales summary for date range
  Future<Map<String, dynamic>> getSalesReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final querySnapshot = await _firestore
        .collection('orders')
        .where('orderType', isEqualTo: 'counter')
        .where('placedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('placedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    double totalSales = 0;
    int orderCount = 0;
    Map<String, double> paymentTotals = {'WALLET': 0, 'UPI': 0, 'CASH': 0};
    Map<String, int> itemCounts = {};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final method = data['paymentMethod'] as String? ?? 'CASH';

      totalSales += amount;
      orderCount++;
      paymentTotals[method] = (paymentTotals[method] ?? 0) + amount;

      // Count items
      final items = data['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        final itemData = item as Map<String, dynamic>;
        final itemName = itemData['itemName'] as String;
        final qty = (itemData['quantity'] as num).toInt();
        itemCounts[itemName] = (itemCounts[itemName] ?? 0) + qty;
      }
    }

    return {
      'totalSales': totalSales,
      'orderCount': orderCount,
      'avgOrderValue': orderCount > 0 ? totalSales / orderCount : 0,
      'paymentTotals': paymentTotals,
      'topItems': itemCounts,
    };
  }

  // ============================================================================
  // MENU MANAGEMENT
  // ============================================================================

  /// Get available menu items for POS
  Stream<QuerySnapshot> getAvailableMenuItems({String? category}) {
    Query query = _firestore
        .collection('menu')
        .where('isAvailable', isEqualTo: true);
    
    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }
    
    return query.orderBy('name').snapshots();
  }

  /// Get menu categories
  Future<List<String>> getCategories() async {
    final snapshot = await _firestore.collection('menu').get();
    
    Set<String> categories = {'All'};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['category'] != null) {
        categories.add(data['category'] as String);
      }
    }
    
    return categories.toList()..sort();
  }

  // ============================================================================
  // COUNTER STAFF MANAGEMENT
  // ============================================================================

  /// Check if current user is counter staff
  Future<bool> isCounterStaff() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;
    
    final role = doc.data()?['role'] as String?;
    return role == 'counter' || role == 'admin';
  }

  /// Get current counter staff info
  Future<Map<String, dynamic>?> getCurrentCounterStaff() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    
    return {
      'uid': user.uid,
      'email': user.email,
      'name': doc.data()?['name'] ?? user.displayName ?? 'Counter Staff',
      'role': doc.data()?['role'] ?? 'counter',
    };
  }
}

/// Helper class for building cart items
class CartItem {
  final String itemId;
  final String itemName;
  final double price;
  int quantity;

  CartItem({
    required this.itemId,
    required this.itemName,
    required this.price,
    this.quantity = 1,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }
}
