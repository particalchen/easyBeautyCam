import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// 快门按钮 —— 70pt 圆形，珊瑚渐变 + 珊瑚色软阴影
///
/// 设计：DESIGN.md Components › Shutter Button
class CaptureButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CaptureButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: AppSpacing.shutterSize,
        height: AppSpacing.shutterSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGradientStart,
              AppColors.primaryGradientEnd,
            ],
          ),
          // 软阴影：低透明度 + 珊瑚色调
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.30),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: AppSpacing.shutterSize - 16,
            height: AppSpacing.shutterSize - 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ),
      ),
    );
  }
}
