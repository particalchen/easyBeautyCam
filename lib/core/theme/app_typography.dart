import 'package:flutter/material.dart';

/// 字号 token —— 与 DESIGN.md typography.* 一一对应
///
/// SF Pro 在 iOS 上系统自带，其他平台 fallback 到 SF Pro Text → 平台默认。
/// 用 `fontFamilyFallback` 让 Android / 鸿蒙 也有合理兜底。
class AppTypography {
  AppTypography._();

  // 平台无关的 SF Pro fontFamily，统一约定「-FallBack」
  static const String _familyDisplay = 'SF Pro Display';
  static const String _familyText = 'SF Pro Text';
  static const String _familyRounded = 'SF Pro Rounded';

  // ── headline ──────────────────────────────────────────
  static const TextStyle headlineLg = TextStyle(
    fontFamily: _familyDisplay,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
  );

  static const TextStyle headlineLgMobile = TextStyle(
    fontFamily: _familyDisplay,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: _familyDisplay,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
  );

  // ── body ───────────────────────────────────────────────
  static const TextStyle bodyLg = TextStyle(
    fontFamily: _familyText,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 24 / 17,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: _familyText,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 20 / 15,
  );

  // ── button ─────────────────────────────────────────────
  static const TextStyle buttonText = TextStyle(
    fontFamily: _familyText,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 24 / 17,
  );

  // ── numeric（zoom 1x/2x/3x、计数器）─────────────────────
  static const TextStyle numericLabel = TextStyle(
    fontFamily: _familyRounded,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 18 / 14,
    letterSpacing: 0.02 * 14,
  );

  // ── 完整 TextTheme（喂给 ThemeData）───────────────────
  static TextTheme get textTheme => const TextTheme(
        displayLarge: headlineLg,
        displayMedium: headlineLg,
        displaySmall: headlineMd,
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        headlineSmall: headlineMd,
        titleLarge: headlineMd,
        titleMedium: buttonText,
        titleSmall: bodyMd,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: bodyMd,
        labelLarge: buttonText,
        labelMedium: numericLabel,
        labelSmall: numericLabel,
      );
}
