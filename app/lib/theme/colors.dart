import 'package:flutter/material.dart';

class HermesColors {
  // Background layers
  static const background = Color(0xFF050810);
  static const surface = Color(0xFF0A0E1A);
  static const surfaceElevated = Color(0xFF0F1422);

  // Glass treatments
  static const glassFill = Color(0x0FFFFFFF);        // 6% white
  static const glassFillMid = Color(0x1AFFFFFF);     // 10% white
  static const glassFillHigh = Color(0x26FFFFFF);    // 15% white
  static const glassRim = Color(0x26FFFFFF);         // 15% white border
  static const glassRimBright = Color(0x40FFFFFF);   // 25% white border

  // Primary accent
  static const primary = Color(0xFF6366F1);          // Indigo
  static const primaryGlow = Color(0x336366F1);
  static const primaryDim = Color(0xFF4F52CC);

  // Provider badge colors
  static const claude = Color(0xFF8B5CF6);           // Purple
  static const openai = Color(0xFF14B8A6);           // Teal
  static const gemini = Color(0xFF3B82F6);           // Blue
  static const ollama = Color(0xFFF97316);           // Orange
  static const minimax = Color(0xFFEC4899);          // Pink

  // Status
  static const success = Color(0xFF10B981);
  static const successGlow = Color(0x3310B981);
  static const warning = Color(0xFFF59E0B);
  static const warningGlow = Color(0x33F59E0B);
  static const error = Color(0xFFF43F5E);
  static const errorGlow = Color(0x33F43F5E);

  // Text
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF475569);
  static const textDisabled = Color(0xFF334155);

  static Color providerColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'claude': return claude;
      case 'openai': return openai;
      case 'gemini': return gemini;
      case 'ollama': return ollama;
      case 'minimax': return minimax;
      default: return primary;
    }
  }
}
