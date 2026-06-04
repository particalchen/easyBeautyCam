import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFF8A7A);
  static const primaryGradientStart = Color(0xFFFFB4A2);
  static const primaryGradientEnd = Color(0xFFFF8A7A);
  static const background = Color(0xFFFFFAF8);
  static const textPrimary = Color(0xFF2D2D2D);
  static const textSecondary = Color(0xFF999999);
  static const poseLine = Color.fromRGBO(255, 255, 255, 0.55);
  static const overlayBackground = Color.fromRGBO(255, 250, 248, 0.95);
  static const cardBorder = Color(0xFFEEEEEE);
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        color: AppColors.textSecondary,
      ),
    ),
  );
}