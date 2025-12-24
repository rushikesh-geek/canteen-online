import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Premium Status Chip Component
/// Used for order status, payment status, slot status
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool outlined;
  final VoidCallback? onTap;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.outlined = false,
    this.onTap,
  });

  // Predefined status chips
  factory StatusChip.pending() => const StatusChip(
        label: 'Pending',
        color: AppTheme.warningAmber,
        icon: Icons.hourglass_empty,
      );

  factory StatusChip.confirmed() => const StatusChip(
        label: 'Confirmed',
        color: AppTheme.infoBlue,
        icon: Icons.check_circle_outline,
      );

  factory StatusChip.preparing() => const StatusChip(
        label: 'Preparing',
        color: Color(0xFF9C27B0), // Purple
        icon: Icons.restaurant,
      );

  factory StatusChip.ready() => const StatusChip(
        label: 'Ready',
        color: AppTheme.successGreen,
        icon: Icons.done_all,
      );

  factory StatusChip.completed() => const StatusChip(
        label: 'Completed',
        color: Colors.grey,
        icon: Icons.check_circle,
      );

  factory StatusChip.cancelled() => const StatusChip(
        label: 'Cancelled',
        color: AppTheme.errorRed,
        icon: Icons.cancel,
      );

  factory StatusChip.paid() => const StatusChip(
        label: 'Paid',
        color: AppTheme.successGreen,
        icon: Icons.check_circle,
      );

  factory StatusChip.unpaid() => const StatusChip(
        label: 'Unpaid',
        color: AppTheme.errorRed,
        icon: Icons.payment,
      );

  factory StatusChip.verifying() => const StatusChip(
        label: 'Verifying',
        color: AppTheme.warningAmber,
        icon: Icons.pending,
      );

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.15),
        border: outlined ? Border.all(color: color, width: 1.5) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppTheme.space4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: widget,
      );
    }

    return widget;
  }
}

/// Premium Menu Item Card
class PremiumMenuCard extends StatelessWidget {
  final String name;
  final double price;
  final int quantity;
  final bool isAvailable;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const PremiumMenuCard({
    super.key,
    required this.name,
    required this.price,
    this.quantity = 0,
    this.isAvailable = true,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: quantity > 0 ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: quantity > 0
            ? BorderSide(color: AppTheme.accentOrange, width: 2)
            : BorderSide.none,
      ),
      child: AnimatedOpacity(
        opacity: isAvailable ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Price Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      if (!isAvailable)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: const Text(
                              'UNAVAILABLE',
                              style: TextStyle(
                                color: AppTheme.errorRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space8),

                // Add/Remove Controls (Fixed height at bottom)
                if (isAvailable)
                  quantity == 0
                      ? SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () {
                              debugPrint('✅ ADD tapped: $name');
                              onAdd();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSmall,
                                ),
                              ),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              elevation: 2,
                            ),
                            child: const Text(
                              'ADD',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.lightOrange,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                            border: Border.all(
                              color: AppTheme.accentOrange,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    debugPrint('➖ REMOVE tapped: $name');
                                    onRemove();
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.remove,
                                      size: 18,
                                      color: AppTheme.accentOrange,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                quantity.toString(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentOrange,
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    debugPrint('➕ ADD (increment) tapped: $name');
                                    onAdd();
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSmall,
                                  ),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.add,
                                      size: 18,
                                      color: AppTheme.accentOrange,
                                    ),
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
      ),
    );
  }
}

/// Premium Order Card
class PremiumOrderCard extends StatelessWidget {
  final String orderId;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String orderStatus;
  final String paymentStatus;
  final DateTime pickupTime;
  final Widget? actions;
  final VoidCallback? onTap;

  const PremiumOrderCard({
    super.key,
    required this.orderId,
    required this.items,
    required this.totalAmount,
    required this.orderStatus,
    required this.paymentStatus,
    required this.pickupTime,
    this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space8,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${orderId.substring(orderId.length - 6).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  _getStatusChip(orderStatus),
                ],
              ),
              const SizedBox(height: AppTheme.space12),

              // Items
              Text(
                _buildItemsSummary(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.space12),

              // Pickup Time & Amount
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.space4),
                  Text(
                    _formatTime(pickupTime),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryIndigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),

              // Payment Status
              _getPaymentChip(paymentStatus),

              // Actions
              if (actions != null) ...[
                const SizedBox(height: AppTheme.space12),
                actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildItemsSummary() {
    return items
        .map((item) => '${item['quantity']}× ${item['itemName']}')
        .take(2)
        .join(', ') + (items.length > 2 ? '...' : '');
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _getStatusChip(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return StatusChip.pending();
      case 'confirmed':
        return StatusChip.confirmed();
      case 'preparing':
        return StatusChip.preparing();
      case 'ready':
        return StatusChip.ready();
      case 'completed':
        return StatusChip.completed();
      case 'cancelled':
        return StatusChip.cancelled();
      default:
        return StatusChip(label: status, color: Colors.grey);
    }
  }

  Widget _getPaymentChip(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return StatusChip.paid();
      case 'unpaid':
        return StatusChip.unpaid();
      case 'verification_pending':
        return StatusChip.verifying();
      default:
        return StatusChip(label: status, color: Colors.grey);
    }
  }
}

/// Slot Chip Widget
class SlotChip extends StatelessWidget {
  final String timeRange;
  final int bookedCount;
  final int capacity;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;

  const SlotChip({
    super.key,
    required this.timeRange,
    required this.bookedCount,
    required this.capacity,
    this.isSelected = false,
    this.isEnabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = bookedCount >= capacity;
    final spotsLeft = capacity - bookedCount;

    return InkWell(
      onTap: isEnabled && !isFull ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryIndigo
              : (isEnabled && !isFull
                  ? AppTheme.surfaceCard
                  : AppTheme.surfaceGrey),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryIndigo
                : (isFull ? AppTheme.errorRed : AppTheme.borderGrey),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeRange,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isEnabled ? AppTheme.textPrimary : AppTheme.textHint),
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              isFull
                  ? 'FULL'
                  : '$spotsLeft spot${spotsLeft == 1 ? '' : 's'} left',
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Colors.white70
                    : (isFull ? AppTheme.errorRed : AppTheme.textSecondary),
                fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty State Widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppTheme.borderGrey,
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppTheme.space24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading Shimmer Widget
class LoadingShimmer extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = AppTheme.radiusMedium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.surfaceGrey,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }
}
