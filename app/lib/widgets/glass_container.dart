import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/glass_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blurSigma;
  final Color fill;
  final Color rim;
  final double rimWidth;
  final Color? glowColor;
  final List<BoxShadow>? shadows;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.radius = GlassTheme.radiusMd,
    this.blurSigma = GlassTheme.blurMid,
    this.fill = HermesColors.glassFill,
    this.rim = HermesColors.glassRim,
    this.rimWidth = 0.5,
    this.glowColor,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: GlassTheme.glassDecoration(
              radius: radius,
              fill: fill,
              rim: rim,
              rimWidth: rimWidth,
              shadows: shadows,
              glowColor: glowColor,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? glowColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GlassTheme.spacingMd),
    this.margin,
    this.radius = GlassTheme.radiusMd,
    this.glowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(
      padding: padding,
      margin: margin,
      radius: radius,
      glowColor: glowColor,
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 80),
        child: card,
      ),
    );
  }
}
