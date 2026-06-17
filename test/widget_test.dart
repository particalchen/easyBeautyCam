// 纯 Dart smoke test —— 不依赖 camera / photo_manager 等 plugin，
// 主要用来挡 token / theme 配置的回归。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/core/theme/app_colors.dart';
import 'package:easy_beauty_cam/core/theme/app_spacing.dart';
import 'package:easy_beauty_cam/core/theme/app_theme.dart';

void main() {
  group('AppSpacing tokens', () {
    test('sm == 8 (回归保护：camera / filter / beauty 视图都依赖此 token)', () {
      expect(AppSpacing.sm, 8);
    });
  });

  group('AppColors tokens', () {
    test('background 不为空', () {
      expect(AppColors.background, isA<Color>());
    });
  });

  group('AppTheme.lightTheme', () {
    test('能正常构造', () {
      final theme = AppTheme.lightTheme;
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
    });

    test('primary 来自 AppColors.primary', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, AppColors.primary);
    });
  });
}
