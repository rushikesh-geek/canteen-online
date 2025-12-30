/// Admin QR Scanner & Payment Processing
/// 
/// Features:
/// - Scan student wallet QR code
/// - Create order for student at counter
/// - Deduct payment from wallet
/// - Add money to student wallet
/// - View transaction logs
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:canteen_app/services/wallet_service.dart';
import 'package:canteen_app/theme/app_theme.dart';

// ============================================================================
// MAIN COUNTER SCREEN
// ============================================================================

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter Operations'),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan & Pay'),
            Tab(icon: Icon(Icons.add_card), text: 'Add Money'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ScanAndPayTab(),
          AddMoneyTab(),
          TransactionLogsTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: SCAN & PAY
// ============================================================================

class ScanAndPayTab extends StatefulWidget {
  const ScanAndPayTab({super.key});

  @override
  State<ScanAndPayTab> createState() => _ScanAndPayTabState();
}

class _ScanAndPayTabState extends State<ScanAndPayTab> {
  final WalletService _walletService = WalletService();
  final MobileScannerController _scannerController = MobileScannerController();
  
  bool _isProcessing = false;
  Map<String, dynamic>? _scannedUser;
  double? _studentBalance;
  
  // Order items for counter order
  List<Map<String, dynamic>> _orderItems = [];
  Map<String, int> _cart = {};
  List<Map<String, dynamic>> _menuItems = [];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuItems() async {
    // Simple query - sort client-side to avoid composite index
    final snapshot = await FirebaseFirestore.instance
        .collection('menu')
        .where('isAvailable', isEqualTo: true)
        .get();
    
    final items = snapshot.docs.map((doc) => {
      'id': doc.id,
      'name': doc['name'] as String,
      'price': (doc['price'] as num).toDouble(),
    }).toList();
    
    // Sort by name client-side
    items.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    
    setState(() {
      _menuItems = items;
    });
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing || _scannedUser != null) return;
    
    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;
    
    _processQRCode(barcode.rawValue!);
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Parse QR data
      final parsed = WalletService.parsePaymentQR(qrData);
      
      if (parsed == null) {
        _showError('Invalid QR code. Please scan a valid wallet QR.');
        return;
      }
      
      if (parsed['error'] != null) {
        _showError(parsed['error']);
        return;
      }
      
      // Check if QR has already been used (security check)
      final sessionId = parsed['sessionId'] as String?;
      if (sessionId != null) {
        final usedError = await _walletService.validateQRNotUsed(sessionId);
        if (usedError != null) {
          _showError(usedError);
          return;
        }
      }
      
      // Fetch user details and balance
      final userId = parsed['userId'] as String;
      final userDetails = await _walletService.getUserDetails(userId);
      
      if (userDetails == null) {
        _showError('Student not found in system.');
        return;
      }
      
      final balance = await _walletService.getBalance(userId);
      
      setState(() {
        _scannedUser = {
          ...parsed,
          'email': userDetails['email'],
          'photoUrl': userDetails['photoUrl'],
        };
        _studentBalance = balance;
        _cart.clear();
        _orderItems.clear();
      });
      
      // Pause scanner
      _scannerController.stop();
      
    } catch (e) {
      _showError('Error processing QR: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
      ),
    );
    setState(() {
      _isProcessing = false;
    });
  }

  void _resetScan() {
    setState(() {
      _scannedUser = null;
      _studentBalance = null;
      _cart.clear();
      _orderItems.clear();
    });
    _scannerController.start();
  }

  double get _totalAmount {
    double total = 0;
    _cart.forEach((itemId, qty) {
      final item = _menuItems.firstWhere((m) => m['id'] == itemId);
      total += (item['price'] as double) * qty;
    });
    return total;
  }

  Future<void> _processPayment() async {
    if (_scannedUser == null || _cart.isEmpty) return;
    
    final studentId = _scannedUser!['userId'] as String;
    final adminId = FirebaseAuth.instance.currentUser!.uid;
    final total = _totalAmount;
    
    // Check balance
    if (_studentBalance! < total) {
      _showError('Insufficient balance! Student has ₹${_studentBalance!.toStringAsFixed(2)}');
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Get student name
      final userName = _scannedUser!['userName'] as String;
      
      // Build order items
      List<Map<String, dynamic>> items = [];
      _cart.forEach((itemId, qty) {
        final item = _menuItems.firstWhere((m) => m['id'] == itemId);
        items.add({
          'itemName': item['name'],
          'quantity': qty,
          'price': item['price'],
        });
      });
      
      // Create order document
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final now = Timestamp.now();
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Create the order
        transaction.set(orderRef, {
          'orderId': orderRef.id,
          'userId': studentId,
          'userName': userName,
          'items': items,
          'totalAmount': total,
          'status': 'completed', // Counter orders are completed immediately
          'placedAt': now,
          'confirmedAt': now,
          'completedAt': now,
          'orderType': 'counter', // Mark as counter order
          'paymentStatus': 'paid',
          'paymentMethod': 'WALLET',
          'paidAt': now,
        });
      });
      
      // Deduct from wallet
      await _walletService.deductPayment(
        studentId: studentId,
        amount: total,
        orderId: orderRef.id,
        adminId: adminId,
      );
      
      // Mark QR session as used (prevents reuse)
      final sessionId = _scannedUser!['sessionId'] as String?;
      if (sessionId != null) {
        await _walletService.markQRSessionAsUsed(
          sessionId: sessionId,
          userId: studentId,
          adminId: adminId,
          amount: total,
          orderId: orderRef.id,
        );
      }
      
      if (!mounted) return;
      
      // Show success
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successGreen, size: 28),
              const SizedBox(width: 12),
              const Text('Payment Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: $userName'),
              const SizedBox(height: 8),
              Text('Amount Paid: ₹${total.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text(
                'New Balance: ₹${(_studentBalance! - total).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetScan();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
              ),
              child: const Text('Next Customer'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      _showError('Payment failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_scannedUser != null) {
      return _buildOrderScreen();
    }
    
    return _buildScannerScreen();
  }

  Widget _buildScannerScreen() {
    return Column(
      children: [
        // Scanner
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: AppTheme.primaryIndigo,
                width: 3,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onBarcodeDetected,
                ),
                // Scan overlay
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                // Processing indicator
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
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 48,
                  color: AppTheme.primaryIndigo,
                ),
                const SizedBox(height: AppTheme.space12),
                const Text(
                  'Scan Student Wallet QR',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.space8),
                Text(
                  'Point camera at student\'s wallet QR code',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderScreen() {
    return Column(
      children: [
        // Student info card
        Container(
          margin: const EdgeInsets.all(AppTheme.space16),
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryIndigo, AppTheme.deepIndigo],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: Text(
                  (_scannedUser!['userName'] as String)[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scannedUser!['userName'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance: ₹${_studentBalance!.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _studentBalance! < _totalAmount
                            ? Colors.red[200]
                            : Colors.green[200],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _resetScan,
              ),
            ],
          ),
        ),
        
        // Menu items
        Expanded(
          child: _menuItems.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: AppTheme.space8,
                    mainAxisSpacing: AppTheme.space8,
                  ),
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final item = _menuItems[index];
                    final qty = _cart[item['id']] ?? 0;
                    
                    return _buildMenuItem(item, qty);
                  },
                ),
        ),
        
        // Order summary & pay button
        if (_cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Items summary
                  ..._cart.entries.map((e) {
                    final item = _menuItems.firstWhere((m) => m['id'] == e.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${e.value}× ${item['name']}'),
                          Text('₹${((item['price'] as double) * e.value).toStringAsFixed(0)}'),
                        ],
                      ),
                    );
                  }),
                  
                  const Divider(),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${_totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _studentBalance! >= _totalAmount
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppTheme.space12),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _studentBalance! >= _totalAmount && !_isProcessing
                          ? _processPayment
                          : null,
                      icon: _isProcessing
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
                        _studentBalance! >= _totalAmount
                            ? 'Deduct ₹${_totalAmount.toStringAsFixed(0)} from Wallet'
                            : 'Insufficient Balance',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item, int qty) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _cart[item['id']] = (qty + 1);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item['name'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '₹${(item['price'] as double).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryIndigo,
                ),
              ),
              if (qty > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (qty <= 1) {
                              _cart.remove(item['id']);
                            } else {
                              _cart[item['id']] = qty - 1;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove, size: 16),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$qty',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _cart[item['id']] = qty + 1;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryIndigo,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 16, color: Colors.white),
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
// TAB 2: ADD MONEY TO STUDENT WALLET
// ============================================================================

class AddMoneyTab extends StatefulWidget {
  const AddMoneyTab({super.key});

  @override
  State<AddMoneyTab> createState() => _AddMoneyTabState();
}

class _AddMoneyTabState extends State<AddMoneyTab> {
  final WalletService _walletService = WalletService();
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  bool _isProcessing = false;
  bool _isScanning = true;
  Map<String, dynamic>? _scannedUser;
  double? _currentBalance;

  @override
  void dispose() {
    _scannerController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing || !_isScanning) return;
    
    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;
    
    _processQRCode(barcode.rawValue!);
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Use relaxed parsing for Add Money (24hr expiry, no single-use check)
      final parsed = WalletService.parsePaymentQRForIdentification(qrData);
      
      if (parsed == null || parsed['error'] != null) {
        _showError(parsed?['error'] ?? 'Invalid QR code');
        return;
      }
      
      final userId = parsed['userId'] as String;
      final userDetails = await _walletService.getUserDetails(userId);
      
      if (userDetails == null) {
        _showError('Student not found');
        return;
      }
      
      final balance = await _walletService.getBalance(userId);
      
      setState(() {
        _scannedUser = {...parsed, 'email': userDetails['email']};
        _currentBalance = balance;
        _isScanning = false;
      });
      
      _scannerController.stop();
      
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed),
    );
    setState(() {
      _isProcessing = false;
    });
  }

  void _reset() {
    setState(() {
      _scannedUser = null;
      _currentBalance = null;
      _isScanning = true;
      _amountController.clear();
      _noteController.clear();
    });
    _scannerController.start();
  }

  Future<void> _addMoney() async {
    if (_scannedUser == null) return;
    
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final adminId = FirebaseAuth.instance.currentUser!.uid;
      final studentId = _scannedUser!['userId'] as String;
      
      await _walletService.addMoney(
        studentId: studentId,
        amount: amount,
        adminId: adminId,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );
      
      if (!mounted) return;
      
      final newBalance = _currentBalance! + amount;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successGreen, size: 28),
              const SizedBox(width: 12),
              const Text('Money Added'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: ${_scannedUser!['userName']}'),
              const SizedBox(height: 8),
              Text('Amount Added: ₹${amount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text(
                'New Balance: ₹${newBalance.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _reset();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning) {
      return Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: AppTheme.successGreen, width: 3),
              ),
              clipBehavior: Clip.hardEdge,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onBarcodeDetected,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_card, size: 48, color: AppTheme.successGreen),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan to Add Money',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.space16),
      child: Column(
        children: [
          // Student card
          Container(
            padding: const EdgeInsets.all(AppTheme.space16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.successGreen, Colors.green[700]!],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Text(
                    (_scannedUser!['userName'] as String)[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scannedUser!['userName'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Current Balance: ₹${_currentBalance!.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _reset,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Amount field
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGreen,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide(color: AppTheme.successGreen, width: 2),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick amounts
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [50, 100, 200, 500, 1000].map((amount) {
              return ActionChip(
                label: Text('₹$amount'),
                onPressed: () {
                  _amountController.text = amount.toString();
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Note field
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g., Cash deposit',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Add button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _addMoney,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add Money to Wallet', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 3: TRANSACTION LOGS
// ============================================================================

class TransactionLogsTab extends StatelessWidget {
  const TransactionLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Simple query - sort client-side
      stream: FirebaseFirestore.instance
          .collection('wallet_transactions')
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Sort client-side
        final transactions = snapshot.data!.docs.toList();
        transactions.sort((a, b) {
          final aTime = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final bTime = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

        if (transactions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No transactions yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.space16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index].data() as Map<String, dynamic>;
            return _buildTransactionTile(tx);
          },
        );
      },
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> tx) {
    final isCredit = tx['type'] == 'credit';
    final amount = (tx['amount'] as num).toDouble();
    final userId = tx['userId'] as String;
    final description = tx['description'] as String? ?? 'Transaction';
    final createdAt = tx['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCredit ? AppTheme.lightGreen : AppTheme.lightRed,
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        ),
        title: Text(
          description,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'User: ${userId.substring(0, 8)}... • ${_formatTime(createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
