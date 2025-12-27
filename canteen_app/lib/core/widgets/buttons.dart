import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable button components with consistent styling

/// Primary call-to-action button
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const PrimaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppTheme.space8),
                ],
                Text(text),
              ],
            ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Secondary outlined button
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  const SecondaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppTheme.space8),
          ],
          Text(text),
        ],
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Text button for subtle actions
class TertiaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const TertiaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: AppTheme.space4),
          ],
          Text(text),
        ],
      ),
    );
  }
}

/// Icon button with consistent styling
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double? size;
  final String? tooltip;

  const AppIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      color: color ?? AppTheme.textPrimary,
      tooltip: tooltip,
    );

    return button;
  }
}
