import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Styled card for menu items with add button
class MenuItemCard extends StatelessWidget {
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isVeg;
  final bool isAvailable;
  final VoidCallback onAdd;
  final int quantity;

  const MenuItemCard({
    Key? key,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.isVeg = true,
    this.isAvailable = true,
    required this.onAdd,
    this.quantity = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isAvailable ? onAdd : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.surfaceGrey,
                    child: const Icon(
                      Icons.restaurant,
                      size: 48,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              )
            else
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: AppTheme.surfaceGrey,
                  child: const Icon(
                    Icons.restaurant,
                    size: 48,
                    color: AppTheme.textHint,
                  ),
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(AppTheme.space12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Veg/Non-veg indicator + Name
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isVeg ? AppTheme.successGreen : AppTheme.errorRed,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isVeg ? AppTheme.successGreen : AppTheme.errorRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Expanded(
                        child: Text(
                          name,
                          style: AppTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (description != null) ...[
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      description!,
                      style: AppTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: AppTheme.space8),

                  // Price + Add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: AppTheme.titleMedium.copyWith(
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      if (isAvailable)
                        quantity > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.space8,
                                  vertical: AppTheme.space4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryOrange,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Text(
                                  '$quantity',
                                  style: AppTheme.labelMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Material(
                                color: AppTheme.lightOrange,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                child: InkWell(
                                  onTap: onAdd,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  child: const Padding(
                                    padding: EdgeInsets.all(AppTheme.space8),
                                    child: Icon(
                                      Icons.add,
                                      size: 20,
                                      color: AppTheme.primaryOrange,
                                    ),
                                  ),
                                ),
                              )
                      else
                        Text(
                          'Unavailable',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.errorRed,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status badge with color coding
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({Key? key, required this.status}) : super(key: key);

  Color _getColor() {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.warningAmber;
      case 'preparing':
        return AppTheme.infoBlue;
      case 'ready':
        return AppTheme.successGreen;
      case 'completed':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textHint;
    }
  }

  IconData _getIcon() {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'preparing':
        return Icons.restaurant;
      case 'ready':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 14, color: color),
          const SizedBox(width: AppTheme.space4),
          Text(
            status,
            style: AppTheme.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cart item badge (floating button with count)
class CartBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const CartBadge({
    Key? key,
    required this.count,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          onPressed: onTap,
          child: const Icon(Icons.shopping_cart),
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(AppTheme.space4),
              decoration: const BoxDecoration(
                color: AppTheme.errorRed,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: AppTheme.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Quantity stepper (-, count, +)
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const QuantityStepper({
    Key? key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderGrey),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: quantity > 1 ? onDecrement : null,
            padding: const EdgeInsets.all(AppTheme.space4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
            child: Text(
              quantity.toString(),
              style: AppTheme.titleSmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: onIncrement,
            padding: const EdgeInsets.all(AppTheme.space4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
