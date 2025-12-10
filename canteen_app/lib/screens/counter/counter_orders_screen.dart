/// Counter Orders Screen
/// 
/// View all orders created from the counter terminal today
/// - Filter by payment method
/// - View order details
/// - Reprint receipt (future)
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:canteen_app/theme/app_theme.dart';

class CounterOrdersScreen extends StatefulWidget {
  const CounterOrdersScreen({super.key});

  @override
  State<CounterOrdersScreen> createState() => _CounterOrdersScreenState();
}

class _CounterOrdersScreenState extends State<CounterOrdersScreen> {
  String _paymentFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Column(
      children: [
        // Filter bar - responsive
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Payment Filter',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () => setState(() {}),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'WALLET', 'UPI', 'CASH'].map((filter) {
                          final isSelected = _paymentFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() => _paymentFilter = filter);
                              },
                              backgroundColor: Colors.grey[100],
                              selectedColor: AppTheme.lightOrange,
                              labelStyle: TextStyle(
                                color: isSelected ? AppTheme.deepOrange : AppTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Text(
                      'Payment: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    ...['All', 'WALLET', 'UPI', 'CASH'].map((filter) {
                      final isSelected = _paymentFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _paymentFilter = filter);
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: AppTheme.lightOrange,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.deepOrange : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(() {}),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
        ),
        
        // Orders list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              // Apply client-side filtering
              final orders = _filterOrders(snapshot.data!.docs);
              
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No counter orders today',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
              
              // Calculate totals
              double totalSales = 0;
              Map<String, double> paymentTotals = {'WALLET': 0, 'UPI': 0, 'CASH': 0};
              for (var doc in orders) {
                final data = doc.data() as Map<String, dynamic>;
                final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
                final method = data['paymentMethod'] as String? ?? 'CASH';
                totalSales += amount;
                paymentTotals[method] = (paymentTotals[method] ?? 0) + amount;
              }
              
              return Column(
                children: [
                  // Summary bar - responsive
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    color: AppTheme.lightIndigo,
                    child: isMobile
                        ? Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                icon: Icons.receipt,
                                label: 'Orders',
                                value: orders.length.toString(),
                                color: AppTheme.primaryIndigo,
                              ),
                              _buildSummaryItem(
                                icon: Icons.payments,
                                label: 'Total',
                                value: '₹${totalSales.toStringAsFixed(0)}',
                                color: AppTheme.successGreen,
                              ),
                              _buildSummaryItem(
                                icon: Icons.account_balance_wallet,
                                label: 'Wallet',
                                value: '₹${paymentTotals['WALLET']!.toStringAsFixed(0)}',
                                color: AppTheme.primaryIndigo,
                              ),
                              _buildSummaryItem(
                                icon: Icons.account_balance,
                                label: 'UPI',
                                value: '₹${paymentTotals['UPI']!.toStringAsFixed(0)}',
                                color: Colors.green,
                              ),
                              _buildSummaryItem(
                                icon: Icons.money,
                                label: 'Cash',
                                value: '₹${paymentTotals['CASH']!.toStringAsFixed(0)}',
                                color: AppTheme.accentOrange,
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem(
                                icon: Icons.receipt,
                                label: 'Orders',
                                value: orders.length.toString(),
                                color: AppTheme.primaryIndigo,
                              ),
                              _buildSummaryItem(
                                icon: Icons.payments,
                                label: 'Total Sales',
                                value: '₹${totalSales.toStringAsFixed(0)}',
                                color: AppTheme.successGreen,
                              ),
                              _buildSummaryItem(
                                icon: Icons.account_balance_wallet,
                                label: 'Wallet',
                                value: '₹${paymentTotals['WALLET']!.toStringAsFixed(0)}',
                                color: AppTheme.primaryIndigo,
                              ),
                              _buildSummaryItem(
                                icon: Icons.account_balance,
                                label: 'UPI',
                                value: '₹${paymentTotals['UPI']!.toStringAsFixed(0)}',
                                color: Colors.green,
                              ),
                              _buildSummaryItem(
                                icon: Icons.money,
                                label: 'Cash',
                                value: '₹${paymentTotals['CASH']!.toStringAsFixed(0)}',
                                color: AppTheme.accentOrange,
                              ),
                            ],
                          ),
                  ),
                  
                  // Orders list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final doc = orders[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildOrderCard(doc.id, data);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    // Simplified query - filter and sort client-side to avoid composite index
    return FirebaseFirestore.instance
        .collection('orders')
        .where('orderType', isEqualTo: 'counter')
        .snapshots();
  }
  
  // Filter orders client-side
  List<QueryDocumentSnapshot> _filterOrders(List<QueryDocumentSnapshot> orders) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    
    var filtered = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final placedAt = data['placedAt'] as Timestamp?;
      if (placedAt == null) return false;
      return placedAt.toDate().isAfter(todayStart);
    }).toList();
    
    // Apply payment filter
    if (_paymentFilter != 'All') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['paymentMethod'] == _paymentFilter;
      }).toList();
    }
    
    // Sort by placedAt descending
    filtered.sort((a, b) {
      final aTime = ((a.data() as Map<String, dynamic>)['placedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final bTime = ((b.data() as Map<String, dynamic>)['placedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    
    return filtered;
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? [];
    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    final paymentMethod = data['paymentMethod'] as String? ?? 'CASH';
    final placedAt = (data['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final customerName = data['userName'] as String? ?? 'Walk-in';
    
    // Get payment method icon and color
    IconData paymentIcon;
    Color paymentColor;
    switch (paymentMethod) {
      case 'WALLET':
        paymentIcon = Icons.account_balance_wallet;
        paymentColor = AppTheme.primaryIndigo;
        break;
      case 'UPI':
        paymentIcon = Icons.account_balance;
        paymentColor = Colors.green;
        break;
      default:
        paymentIcon = Icons.money;
        paymentColor = AppTheme.accentOrange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: paymentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(paymentIcon, color: paymentColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '#${orderId.substring(orderId.length - 6).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '₹${total.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.successGreen,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              customerName,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              _formatTime(placedAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Items:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final itemData = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${itemData['quantity']}× ${itemData['itemName']}'),
                        Text('₹${((itemData['price'] as num) * (itemData['quantity'] as num)).toStringAsFixed(0)}'),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: paymentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(paymentIcon, size: 14, color: paymentColor),
                          const SizedBox(width: 4),
                          Text(
                            paymentMethod,
                            style: TextStyle(
                              color: paymentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data['upiTransactionId'] != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'TXN: ${data['upiTransactionId']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }
}
