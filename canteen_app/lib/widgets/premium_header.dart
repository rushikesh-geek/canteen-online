import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:canteen_app/theme/app_theme.dart';

/// Premium greeting header with time-based message
class GreetingHeader extends StatelessWidget {
  final User user;
  final String? customGreeting;

  const GreetingHeader({
    super.key,
    required this.user,
    this.customGreeting,
  });

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getUserFirstName() {
    final displayName = user.displayName;
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }
    final email = user.email ?? '';
    return email.split('@').first.split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final greeting = customGreeting ?? _getTimeBasedGreeting();
    final firstName = _getUserFirstName();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryIndigo,
            AppTheme.deepIndigo,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusLarge),
          bottomRight: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              greeting,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              firstName,
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'What would you like to eat today?',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Order status timeline widget
/// Shows the order progress: Confirmed → Preparing → Ready → Completed
class OrderStatusTimeline extends StatelessWidget {
  final String currentStatus;
  final String paymentStatus;

  const OrderStatusTimeline({
    super.key,
    required this.currentStatus,
    required this.paymentStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Order flow: confirmed → preparing → ready → completed
    // Payment status is separate and shown elsewhere
    final statuses = ['confirmed', 'preparing', 'ready', 'completed'];
    
    // Find current index, default to 0 if status not found
    int currentIndex = statuses.indexOf(currentStatus);
    if (currentIndex == -1) {
      // Handle 'pending' or unknown status - show as before confirmed
      currentIndex = currentStatus == 'pending' ? -1 : 0;
    }
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: List.generate(statuses.length, (index) {
          final status = statuses[index];
          final isCompleted = index <= currentIndex;
          final isCurrent = index == currentIndex;
          
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCompleted 
                              ? AppTheme.successGreen 
                              : AppTheme.surfaceGrey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCurrent 
                                ? AppTheme.successGreen 
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : Icons.circle_outlined,
                          size: 14,
                          color: isCompleted ? Colors.white : AppTheme.textHint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusLabel(status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCompleted ? AppTheme.textPrimary : AppTheme.textHint,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (index < statuses.length - 1)
                  Flexible(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: isCompleted 
                          ? AppTheme.successGreen 
                          : AppTheme.borderGrey,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Confirmed';
      case 'preparing': return 'Preparing';
      case 'ready': return 'Ready';
      case 'completed': return 'Done';
      default: return status;
    }
  }
}

/// Premium status chip widget
class PremiumStatusChip extends StatelessWidget {
  final String status;
  final bool compact;

  const PremiumStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: config.color,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: compact ? 14 : 16,
            color: config.color,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  ({Color color, Color backgroundColor, IconData icon, String label}) _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return (
          color: AppTheme.warningAmber,
          backgroundColor: AppTheme.lightAmber,
          icon: Icons.hourglass_empty,
          label: 'Pending',
        );
      case 'confirmed':
        return (
          color: AppTheme.infoBlue,
          backgroundColor: AppTheme.lightBlue,
          icon: Icons.check_circle_outline,
          label: 'Confirmed',
        );
      case 'paid':
        return (
          color: AppTheme.successGreen,
          backgroundColor: AppTheme.lightGreen,
          icon: Icons.check_circle,
          label: 'Paid',
        );
      case 'preparing':
        return (
          color: AppTheme.warningAmber,
          backgroundColor: AppTheme.lightAmber,
          icon: Icons.restaurant,
          label: 'Preparing',
        );
      case 'ready':
        return (
          color: AppTheme.successGreen,
          backgroundColor: AppTheme.lightGreen,
          icon: Icons.done_all,
          label: 'Ready',
        );
      case 'completed':
        return (
          color: AppTheme.textSecondary,
          backgroundColor: AppTheme.surfaceGrey,
          icon: Icons.check_circle_outline,
          label: 'Completed',
        );
      case 'cancelled':
        return (
          color: AppTheme.errorRed,
          backgroundColor: AppTheme.errorRed.withOpacity(0.1),
          icon: Icons.cancel,
          label: 'Cancelled',
        );
      default:
        return (
          color: AppTheme.textSecondary,
          backgroundColor: AppTheme.surfaceGrey,
          icon: Icons.info_outline,
          label: status,
        );
    }
  }
}
