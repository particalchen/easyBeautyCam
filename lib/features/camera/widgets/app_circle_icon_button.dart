import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// 通用圆环 icon 按钮 —— 相机切换按钮、相册按钮复用
///
/// 视觉规范（颜色走 [AppColors]，尺寸走 [AppSpacing]）：
/// - 半透黑底（[AppColors.scrimStrong]）
/// - 1.5pt [AppColors.onPrimary] 边框（[bordered] = false 时去掉）
/// - 线性 / outline 图标（前景 [AppColors.onPrimary]，可调 [iconOpacity]）
/// - 默认直径 [AppSpacing.cameraButtonSize]；AppBar 内联使用时传更小的 size（如 36）
class AppCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  /// 是否画圆形外圈描边
  /// - true（默认）：相机切换按钮，醒目
  /// - false：AppBar 内联按钮，去掉描边更干净
  final bool bordered;

  /// 图标前景色透明度（0.0 ~ 1.0）
  /// - 1.0（默认）：完全不透明
  /// - 0.75：背景相机控制按钮（次要操作，不抢戏）
  final double iconOpacity;

  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = AppSpacing.cameraButtonSize,
    // widget-local default；不提到 AppSpacing，避免把每个 icon 容器都耦合到本组件的比例
    this.iconSize = 28,
    this.bordered = true,
    this.iconOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.onPrimary.withValues(alpha: iconOpacity);
    final border = bordered
        ? const BorderSide(color: AppColors.onPrimary, width: 1.5)
        : BorderSide.none;
    return Material(
      color: AppColors.scrimStrong,
      shape: CircleBorder(side: border),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}