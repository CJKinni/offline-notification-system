import 'package:flutter/material.dart';
import 'colors.dart';

class GlassTheme {
  // Blur sigmas
  static const blurLow = 10.0;
  static const blurMid = 20.0;
  static const blurHigh = 30.0;

  // Border radii
  static const radiusXs = 8.0;
  static const radiusSm = 12.0;
  static const radiusMd = 16.0;
  static const radiusLg = 24.0;
  static const radiusXl = 32.0;
  static const radiusFull = 999.0;

  // Spacing
  static const spacingXs = 4.0;
  static const spacingSm = 8.0;
  static const spacingMd = 16.0;
  static const spacingLg = 24.0;
  static const spacingXl = 32.0;

  // Shadow for glass cards
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 24,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.6),
      blurRadius: 40,
      spreadRadius: -8,
      offset: const Offset(0, 16),
    ),
  ];

  // Glass decoration factory
  static BoxDecoration glassDecoration({
    double radius = radiusMd,
    Color fill = HermesColors.glassFill,
    Color rim = HermesColors.glassRim,
    double rimWidth = 0.5,
    List<BoxShadow>? shadows,
    Color? glowColor,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: fill,
      border: Border.all(color: rim, width: rimWidth),
      boxShadow: [
        ...(shadows ?? cardShadow),
        if (glowColor != null)
          BoxShadow(
            color: glowColor,
            blurRadius: 20,
            spreadRadius: -4,
          ),
      ],
    );
  }
}

// Spring curves for animations
class SpringCurve extends Curve {
  final double mass;
  final double stiffness;
  final double damping;

  const SpringCurve({
    this.mass = 1.0,
    this.stiffness = 180.0,
    this.damping = 20.0,
  });

  @override
  double transformInternal(double t) {
    final w0 = (stiffness / mass).abs();
    final zeta = damping / (2 * (stiffness * mass).abs());
    if (zeta < 1) {
      final wd = w0 * (1 - zeta * zeta);
      return 1 -
          (zeta * w0 * t * (zeta * w0 / wd).abs() + t) /
              (1 + (zeta * w0 / wd) * (zeta * w0 / wd)) *
              2 *
              t.clamp(0, 1);
    }
    return 1 - (1 + w0 * t) * (-w0 * t).abs().clamp(0, 1);
  }
}

const hermesSpring = SpringCurve(stiffness: 200, damping: 22);
