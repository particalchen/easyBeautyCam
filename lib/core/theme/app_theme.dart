import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// 主题组装 —— 把所有 token 拼成 Material 3 ThemeData
///
/// 单一职责：
/// 1. 把 token 映射到 ThemeData / ColorScheme
/// 2. 暴露 lightTheme
///
/// token 本身在 `app_colors.dart` / `app_typography.dart` / `app_spacing.dart` / `app_radii.dart`
class AppTheme {
  AppTheme._();

  /// 从 DESIGN.md 的 primary 派生整套 M3 ColorScheme，再覆盖为精确色值
  static final ColorScheme _colorScheme =
      ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light)
          .copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onTertiaryContainer,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceContainerLowest: AppColors.surfaceContainerLowest,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    inverseSurface: AppColors.inverseSurface,
    onInverseSurface: AppColors.inverseOnSurface,
    inversePrimary: AppColors.inversePrimary,
    surfaceTint: AppColors.surfaceTint,
  );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _colorScheme,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: AppTypography.textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.textPrimary,
          titleTextStyle: AppTypography.headlineLgMobile.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        dividerColor: AppColors.borderLight,
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.primary.withOpacity(0.2),
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withOpacity(0.15),
          trackHeight: 3,
        ),
      );
}
