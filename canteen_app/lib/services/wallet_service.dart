import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Wallet Service
/// 
/// Manages student wallet operations:
/// - Check balance
/// - Add money (admin only)
/// - Deduct payment (via QR scan)
/// - Transaction history
class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's wallet balance
  Stream<double> getWalletBalance(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 0.0;
      final data = doc.data()!;
      return (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
    });
  }

  /// Get wallet balance once (not stream)
  Future<double> getBalance(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 0.0;
    final data = doc.data()!;
    return (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
  }

  /// Add money to student wallet (Admin action)
  /// 
  /// Returns transaction ID on success
  Future<String> addMoney({
    required String studentId,
    required double amount,
    required String adminId,
    String? note,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be positive');
    }

    // Use transaction for atomicity
    final transactionRef = _firestore.collection('wallet_transactions').doc();
    
    await _firestore.runTransaction((transaction) async {
      // Get current balance
      final userDoc = await transaction.get(
        _firestore.collection('users').doc(studentId)
      );
      
      if (!userDoc.exists) {
        throw Exception('Student not found');
      }
      
      final currentBalance = (userDoc.data()!['walletBalance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance + amount;
      
      // Update user balance
      transaction.update(userDoc.reference, {
        'walletBalance': newBalance,
        'walletUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Create transaction record
      transaction.set(transactionRef, {
        'transactionId': transactionRef.id,
        'userId': studentId,
        'type': 'credit', // credit = add money
        'amount': amount,
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'description': note ?? 'Wallet top-up',
        'adminId': adminId,
        'createdAt': FieldValue.serverTimestamp(),
        'method': 'admin_topup',
      });
    });
    
    return transactionRef.id;
  }

  /// Deduct money from student wallet (Payment for order)
  /// 
  /// Called when admin scans student QR code
  Future<String> deductPayment({
    required String studentId,
    required double amount,
    required String orderId,
    required String adminId,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be positive');
    }

    final transactionRef = _firestore.collection('wallet_transactions').doc();
    
    await _firestore.runTransaction((transaction) async {
      // Get current balance
      final userDoc = await transaction.get(
        _firestore.collection('users').doc(studentId)
      );
      
      if (!userDoc.exists) {
        throw Exception('Student not found');
      }
      
      final userData = userDoc.data()!;
      final currentBalance = (userData['walletBalance'] as num?)?.toDouble() ?? 0.0;
      
      // Check sufficient balance
      if (currentBalance < amount) {
        throw Exception('Insufficient wallet balance. Available: ₹${currentBalance.toStringAsFixed(2)}');
      }
      
      final newBalance = currentBalance - amount;
      
      // Update user balance
      transaction.update(userDoc.reference, {
        'walletBalance': newBalance,
        'walletUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update order payment status
      final orderRef = _firestore.collection('orders').doc(orderId);
      transaction.update(orderRef, {
        'paymentStatus': 'paid',
        'paymentMethod': 'WALLET',
        'walletTransactionId': transactionRef.id,
        'paidAt': FieldValue.serverTimestamp(),
      });
      
      // Create transaction record
      transaction.set(transactionRef, {
        'transactionId': transactionRef.id,
        'userId': studentId,
        'type': 'debit', // debit = payment
        'amount': amount,
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'description': 'Payment for Order #${orderId.substring(orderId.length - 6).toUpperCase()}',
        'orderId': orderId,
        'adminId': adminId,
        'createdAt': FieldValue.serverTimestamp(),
        'method': 'qr_scan',
      });
    });
    
    return transactionRef.id;
  }

  /// Get transaction history for user (no composite index needed)
  Stream<QuerySnapshot> getTransactionHistory(String userId, {int limit = 50}) {
    // Simple query - sort client-side to avoid composite index
    return _firestore
        .collection('wallet_transactions')
        .where('userId', isEqualTo: userId)
        .limit(limit)
        .snapshots();
  }
  
  /// Sort transactions by createdAt descending (call after getting snapshot)
  List<QueryDocumentSnapshot> sortTransactions(List<QueryDocumentSnapshot> docs) {
    final sorted = docs.toList();
    sorted.sort((a, b) {
      final aTime = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final bTime = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  /// Initialize wallet for new user (if not exists)
  Future<void> initializeWallet(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    
    if (userDoc.exists) {
      final data = userDoc.data()!;
      if (data['walletBalance'] == null) {
        await userRef.update({
          'walletBalance': 0.0,
          'walletCreatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Generate payment QR data for student
  /// 
  /// QR contains: userId|name|timestamp|checksum
  /// This is an OFFLINE QR - doesn't need internet to display
  static String generatePaymentQR({
    required String userId,
    required String userName,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Simple checksum for basic validation
    final checksum = (userId.hashCode ^ userName.hashCode ^ timestamp).abs() % 10000;
    
    // Format: CANTEEN|userId|userName|timestamp|checksum
    return 'CANTEEN|$userId|$userName|$timestamp|$checksum';
  }

  /// Parse and validate payment QR data
  /// 
  /// Returns null if invalid
  static Map<String, dynamic>? parsePaymentQR(String qrData) {
    try {
      final parts = qrData.split('|');
      
      if (parts.length != 5 || parts[0] != 'CANTEEN') {
        return null;
      }
      
      final userId = parts[1];
      final userName = parts[2];
      final timestamp = int.parse(parts[3]);
      final checksum = int.parse(parts[4]);
      
      // Validate checksum
      final expectedChecksum = (userId.hashCode ^ userName.hashCode ^ timestamp).abs() % 10000;
      if (checksum != expectedChecksum) {
        return null;
      }
      
      // Check if QR is not too old (valid for 24 hours)
      final qrTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      if (now.difference(qrTime).inHours > 24) {
        return {'error': 'QR code expired. Please generate a new one.'};
      }
      
      return {
        'userId': userId,
        'userName': userName,
        'timestamp': qrTime,
        'isValid': true,
      };
    } catch (e) {
      return null;
    }
  }

  /// Get user details by ID
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return doc.data();
  }
}
