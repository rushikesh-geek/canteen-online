/// Counter Reports Screen
/// 
/// Sales analytics and reports for counter operations
/// - Daily/Weekly/Monthly summaries
/// - Payment method breakdown
/// - Top selling items
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:canteen_app/theme/app_theme.dart';

class CounterReportsScreen extends StatefulWidget {
  const CounterReportsScreen({super.key});

  @override
  State<CounterReportsScreen> createState() => _CounterReportsScreenState();
}

class _CounterReportsScreenState extends State<CounterReportsScreen> {
  String _selectedPeriod = 'Today';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [
              const Text(
                'Period: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              ...['Today', 'This Week', 'This Month'].map((period) {
                final isSelected = _selectedPeriod == period;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(period),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedPeriod = period;
                        });
                      }
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: AppTheme.lightOrange,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.deepOrange : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Reports content
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchReportData(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final data = snapshot.data!;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  _buildSummaryCards(data),
                  
                  const SizedBox(height: 24),
                  
                  // Payment breakdown
                  _buildPaymentBreakdown(data),
                  
                  const SizedBox(height: 24),
                  
                  // Top items
                  _buildTopItems(data),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchReportData() async {
    DateTime startDate;
    final now = DateTime.now();
    
    switch (_selectedPeriod) {
      case 'This Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default: // Today
        startDate = DateTime(now.year, now.month, now.day);
    }
    
    final querySnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('orderType', isEqualTo: 'counter')
        .where('placedAt', isGreaterThan: Timestamp.fromDate(startDate))
        .get();
    
    // Calculate metrics
    double totalSales = 0;
    int orderCount = 0;
    Map<String, double> paymentTotals = {'WALLET': 0, 'UPI': 0, 'CASH': 0};
    Map<String, int> paymentCounts = {'WALLET': 0, 'UPI': 0, 'CASH': 0};
    Map<String, int> itemCounts = {};
    Map<String, double> itemSales = {};
    
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final method = data['paymentMethod'] as String? ?? 'CASH';
      
      totalSales += amount;
      orderCount++;
      paymentTotals[method] = (paymentTotals[method] ?? 0) + amount;
      paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
      
      // Count items
      final items = data['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        final itemData = item as Map<String, dynamic>;
        final itemName = itemData['itemName'] as String;
        final qty = (itemData['quantity'] as num).toInt();
        final price = (itemData['price'] as num).toDouble();
        
        itemCounts[itemName] = (itemCounts[itemName] ?? 0) + qty;
        itemSales[itemName] = (itemSales[itemName] ?? 0) + (price * qty);
      }
    }
    
    // Get top 5 items
    final sortedItems = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(5).toList();
    
    return {
      'totalSales': totalSales,
      'orderCount': orderCount,
      'avgOrderValue': orderCount > 0 ? totalSales / orderCount : 0,
      'paymentTotals': paymentTotals,
      'paymentCounts': paymentCounts,
      'topItems': topItems,
      'itemSales': itemSales,
    };
  }

  Widget _buildSummaryCards(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.payments,
            label: 'Total Sales',
            value: '₹${(data['totalSales'] as double).toStringAsFixed(0)}',
            color: AppTheme.successGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.receipt,
            label: 'Orders',
            value: '${data['orderCount']}',
            color: AppTheme.primaryIndigo,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            icon: Icons.trending_up,
            label: 'Avg. Order',
            value: '₹${(data['avgOrderValue'] as double).toStringAsFixed(0)}',
            color: AppTheme.accentOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(Map<String, dynamic> data) {
    final paymentTotals = data['paymentTotals'] as Map<String, double>;
    final paymentCounts = data['paymentCounts'] as Map<String, int>;
    final total = data['totalSales'] as double;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentRow(
            icon: Icons.account_balance_wallet,
            label: 'Wallet',
            amount: paymentTotals['WALLET'] ?? 0,
            count: paymentCounts['WALLET'] ?? 0,
            total: total,
            color: AppTheme.primaryIndigo,
          ),
          const SizedBox(height: 12),
          _buildPaymentRow(
            icon: Icons.account_balance,
            label: 'UPI',
            amount: paymentTotals['UPI'] ?? 0,
            count: paymentCounts['UPI'] ?? 0,
            total: total,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildPaymentRow(
            icon: Icons.money,
            label: 'Cash',
            amount: paymentTotals['CASH'] ?? 0,
            count: paymentCounts['CASH'] ?? 0,
            total: total,
            color: AppTheme.accentOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    required IconData icon,
    required String label,
    required double amount,
    required int count,
    required double total,
    required Color color,
  }) {
    final percentage = total > 0 ? (amount / total) * 100 : 0;
    
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$label ($count orders)',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage / 100,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopItems(Map<String, dynamic> data) {
    final topItems = data['topItems'] as List<MapEntry<String, int>>;
    final itemSales = data['itemSales'] as Map<String, double>;
    
    if (topItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Center(
          child: Text('No items sold in this period'),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Items',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ...topItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final sales = itemSales[item.key] ?? 0;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _getRankColor(index),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${item.value} sold',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${sales.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFFFD700); // Gold
      case 1:
        return const Color(0xFFC0C0C0); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }
}
