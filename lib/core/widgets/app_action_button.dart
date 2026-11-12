import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant {
  primary,
  secondary,
  danger,
  success,
  outline,
}

/// زر موحد للتطبيق يمنع الضغط المتكرر ويدعم كلا الاسمين isFullWidth و fullWidth
class AppActionButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final FutureOr<void> Function()? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final bool? fullWidth;
  final AppButtonVariant variant;
  final Duration debounceDuration;

  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.fullWidth,
    this.variant = AppButtonVariant.primary,
    this.debounceDuration = const Duration(milliseconds: 600),
  });

  @override
  State<AppActionButton> createState() => _AppActionButtonState();
}

class _AppActionButtonState extends State<AppActionButton> {
  bool _isInternalBusy = false;
  DateTime? _lastClickTime;

  bool get _effectiveBusy => widget.isLoading || _isInternalBusy;
  bool get _effectiveFullWidth => widget.fullWidth ?? widget.isFullWidth;

  Future<void> _handleTap() async {
    if (_effectiveBusy || widget.onPressed == null) return;

    final now = DateTime.now();
    if (_lastClickTime != null &&
        now.difference(_lastClickTime!) < widget.debounceDuration) {
      return;
    }
    _lastClickTime = now;

    if (mounted) {
      setState(() => _isInternalBusy = true);
    }

    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        setState(() => _isInternalBusy = false);
      }
    }
  }

  Color _getBackgroundColor() {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return AppColors.primaryNavy;
      case AppButtonVariant.secondary:
        return AppColors.secondaryBlue;
      case AppButtonVariant.danger:
        return AppColors.dangerRed;
      case AppButtonVariant.success:
        return AppColors.successGreen;
      case AppButtonVariant.outline:
        return Colors.transparent;
    }
  }

  Color _getForegroundColor() {
    if (widget.variant == AppButtonVariant.outline) {
      return AppColors.primaryNavy;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor();
    final fgColor = _getForegroundColor();

    final buttonChild = Row(
      mainAxisSize: _effectiveFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_effectiveBusy) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: fgColor,
            ),
          ),
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );

    final Widget button = widget.variant == AppButtonVariant.outline
        ? OutlinedButton(
            onPressed: _effectiveBusy ? null : _handleTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              side: const BorderSide(color: AppColors.primaryNavy, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: buttonChild,
          )
        : ElevatedButton(
            onPressed: _effectiveBusy ? null : _handleTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: fgColor,
              disabledBackgroundColor: bgColor.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: buttonChild,
          );

    if (_effectiveFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}