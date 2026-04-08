import 'package:flutter/material.dart';
import 'colors.dart';

class HermesTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w700,
    color: HermesColors.textPrimary, letterSpacing: -0.5, height: 1.2,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w600,
    color: HermesColors.textPrimary, letterSpacing: -0.3, height: 1.3,
  );
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w600,
    color: HermesColors.textPrimary, height: 1.3,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600,
    color: HermesColors.textPrimary, height: 1.4,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400,
    color: HermesColors.textPrimary, height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: HermesColors.textSecondary, height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: HermesColors.textTertiary, height: 1.4,
  );
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500,
    color: HermesColors.textPrimary, letterSpacing: 0.1,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: HermesColors.textSecondary, letterSpacing: 0.5,
  );
  static const TextStyle mono = TextStyle(
    fontSize: 13, fontFamily: 'monospace',
    color: HermesColors.textSecondary, height: 1.5,
  );
}
