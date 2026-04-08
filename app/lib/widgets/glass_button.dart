import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';
import '../theme/typography.dart';

class GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isLoading;
  final IconData? icon;
  final bool outlined;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.isLoading = false,
    this.icon,
    this.outlined = false,
  });

  const GlassButton.outlined({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.isLoading = false,
    this.icon,
  }) : outlined = true;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? HermesColors.primary;
    final disabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: (_) { if (!disabled) _controller.reverse(); },
      onTapUp: (_) { _controller.forward(); widget.onPressed?.call(); },
      onTapCancel: () { _controller.forward(); },
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: GlassTheme.spacingMd,
                vertical: GlassTheme.spacingSm + 4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GlassTheme.radiusSm),
                color: widget.outlined
                    ? Colors.transparent
                    : accent.withOpacity(disabled ? 0.3 : 0.85),
                border: Border.all(
                  color: accent.withOpacity(disabled ? 0.2 : 0.6),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading) ...[
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.outlined ? accent : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16,
                        color: widget.outlined ? accent : Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.label,
                    style: HermesTypography.labelLarge.copyWith(
                      color: widget.outlined
                          ? (disabled ? accent.withOpacity(0.4) : accent)
                          : (disabled ? Colors.white38 : Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
