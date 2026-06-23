import 'package:flutter/material.dart';

/// 颜色 token —— 与 DESIGN.md 一一对应
///
/// 改色流程：
/// 1. 改 DESIGN.md
/// 2. 同步改这里
/// 3. 重新跑 `flutter pub get`
class AppColors {
  AppColors._();

  // ── Material 3 ColorScheme 角色（DESIGN.md colors.*）───────────
  static const Color surface = Color(0xFFFDF8F6);
  static const Color surfaceDim = Color(0xFFDDD9D7);
  static const Color surfaceBright = Color(0xFFFDF8F6);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF7F3F1);
  static const Color surfaceContainer = Color(0xFFF2EDEB);
  static const Color surfaceContainerHigh = Color(0xFFECE7E5);
  static const Color surfaceContainerHighest = Color(0xFFE6E1E0);
  static const Color onSurface = Color(0xFF1C1B1A);
  static const Color onSurfaceVariant = Color(0xFF56423F);
  static const Color inverseSurface = Color(0xFF32302F);
  static const Color inverseOnSurface = Color(0xFFF5F0EE);
  static const Color outline = Color(0xFF89726E);
  static const Color outlineVariant = Color(0xFFDCC0BC);
  static const Color surfaceTint = Color(0xFF9F4035);

  static const Color primary = Color(0xFF9F4035);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFF8A7A);
  static const Color onPrimaryContainer = Color(0xFF762219);
  static const Color inversePrimary = Color(0xFFFFB4A9);

  static const Color secondary = Color(0xFF884F41);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFFB4A2);
  static const Color onSecondaryContainer = Color(0xFF7A4336);

  static const Color tertiary = Color(0xFF5F5E5E);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFADABAB);
  static const Color onTertiaryContainer = Color(0xFF403F3F);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color primaryFixed = Color(0xFFFFDAD5);
  static const Color primaryFixedDim = Color(0xFFFFB4A9);
  static const Color onPrimaryFixed = Color(0xFF410000);
  static const Color onPrimaryFixedVariant = Color(0xFF7F2920);

  static const Color secondaryFixed = Color(0xFFFFDAD2);
  static const Color secondaryFixedDim = Color(0xFFFFB4A2);
  static const Color onSecondaryFixed = Color(0xFF360E05);
  static const Color onSecondaryFixedVariant = Color(0xFF6C382B);

  static const Color tertiaryFixed = Color(0xFFE5E2E1);
  static const Color tertiaryFixedDim = Color(0xFFC8C6C5);
  static const Color onTertiaryFixed = Color(0xFF1C1B1B);
  static const Color onTertiaryFixedVariant = Color(0xFF474746);

  static const Color background = Color(0xFFFDF8F6);
  static const Color onBackground = Color(0xFF1C1B1A);
  static const Color surfaceVariant = Color(0xFFE6E1E0);

  // ── 半透黑底（相机 UI 专用）────────────────────────
  /// 强 scrim：浮在纯黑相机预览上的圆环按钮底色
  static const Color scrimStrong = Color(0x66000000);
  /// 弱 scrim：AppBar 半透黑底（前景图标全白）
  static const Color scrimLight = Color(0x40000000);

  // ── 业务语义色（DESIGN.md colors 段的别名 / 业务额外补充）───
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF999999);

  /// 姿势轮廓线条（半透明白）
  static const Color poseLine = Color.fromRGBO(255, 255, 255, 0.55);

  /// 姿势轮廓光晕
  static const Color poseGlow = Color.fromRGBO(255, 255, 255, 0.20);

  /// 浮层面板背景（带玻璃感）
  static const Color overlayBg = Color.fromRGBO(255, 250, 248, 0.95);

  /// 浅色描边（卡片）
  static const Color borderLight = Color(0xFFEEEEEE);

  // ── 主色渐变（快门按钮）───────────────────────────────────
  static const Color primaryGradientStart = Color(0xFFFFB4A2);
  static const Color primaryGradientEnd = Color(0xFFFF8A7A);

  // ── 滤镜预览色（carousel 缩略图用）────────────────────────
  static const Color filterPreviewOriginal = surfaceContainerHigh;
  static const Color filterPreviewCoral = secondaryContainer;
  static const Color filterPreviewGangfeng = Color(0xFF8B7355);
  static const Color filterPreviewRixi = Color(0xFFFFF8DC);
  static const Color filterPreviewJiaopian = Color(0xFFD4A574);

  /// 提示色：橙色（人脸未检测到、警告）
  static const Color warning = Color(0xFFFF9800);
  /// 成功色：绿色（检测成功）
  static const Color success = Color(0xFF4CAF50);

  // ── 兼容旧名（不推荐新代码使用）─────────────────────────────
  @Deprecated('Use AppColors.poseLine instead')
  static const Color poseLineLegacy = poseLine;
  @Deprecated('Use AppColors.overlayBg instead')
  static const Color overlayBackground = overlayBg;
  @Deprecated('Use AppColors.borderLight instead')
  static const Color cardBorder = borderLight;
}
