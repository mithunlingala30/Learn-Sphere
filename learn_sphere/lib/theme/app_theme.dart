import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: LS.periwinkle,
    brightness: Brightness.light,
  ).copyWith(
    primary: LS.periwinkle,
    onPrimary: Colors.white,
    secondary: LS.ink,
    surface: LS.paper,
    onSurface: LS.ink,
    error: LS.rose,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LS.mist,
    canvasColor: LS.mist,
    splashFactory: InkRipple.splashFactory,
    dividerColor: LS.line,
    textTheme: TextTheme(
      displayLarge: display(56),
      headlineLarge: display(34),
      headlineMedium: display(28),
      headlineSmall: display(22),
      titleLarge: display(20, weight: FontWeight.w600),
      titleMedium: body(16, weight: FontWeight.w600),
      titleSmall: body(14, weight: FontWeight.w600),
      bodyLarge: body(16),
      bodyMedium: body(14),
      bodySmall: body(12, color: LS.slate),
      labelLarge: body(14, weight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LS.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: body(15, weight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LS.ink,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        side: const BorderSide(color: LS.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: body(15, weight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LS.periwinkle,
        textStyle: body(14, weight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LS.ink,
      contentTextStyle: body(14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
