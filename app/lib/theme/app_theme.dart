import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';

ThemeData buildHermesTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: HermesColors.background,
    colorScheme: const ColorScheme.dark(
      primary: HermesColors.primary,
      onPrimary: Colors.white,
      secondary: HermesColors.success,
      surface: HermesColors.surface,
      onSurface: HermesColors.textPrimary,
      error: HermesColors.error,
    ),
    textTheme: const TextTheme(
      displayLarge: HermesTypography.displayLarge,
      displayMedium: HermesTypography.displayMedium,
      headlineLarge: HermesTypography.headlineLarge,
      headlineMedium: HermesTypography.headlineMedium,
      bodyLarge: HermesTypography.bodyLarge,
      bodyMedium: HermesTypography.bodyMedium,
      bodySmall: HermesTypography.bodySmall,
      labelLarge: HermesTypography.labelLarge,
      labelSmall: HermesTypography.labelSmall,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: HermesTypography.headlineLarge,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    }),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
