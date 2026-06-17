import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// 通用圆环 icon 按钮 —— 相机切换按钮、相册按钮复用
///
/// 视觉规范（颜色走 [AppColors]，尺寸走 [AppSpacing]）：
/// - 半透黑底（[AppColors.scrimStrong]）
/// - 1.5pt [AppColors.onPrimary] 边框
/// - 线性 / outline 图标（前景 [AppColors.onPrimary]）
/// - 默认直径 [AppSpacing.cameraButtonSize]；AppBar 内联使用时传更小的 size（如 36）
class AppCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = AppSpacing.cameraButtonSize,
    // widget-local default；不提到 AppSpacing，避免把每个 icon 容器都耦合到本组件的比例
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.scrimStrong,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.onPrimary, width: 1.5),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: AppColors.onPrimary, size: iconSize),
        ),
      ),
    );
  }
}