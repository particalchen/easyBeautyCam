import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import 'app_circle_icon_button.dart';

/// 相机前/后置切换按钮 —— 复用 AppCircleIconButton
///
/// 视觉规范与相册按钮统一（半透黑底 + 白边 + 线性图标），
/// 直径走 [AppSpacing.cameraButtonSize]（56pt），固定 `Icons.cameraswitch` 图标。
/// 图标前景透明度 75%——次要操作，不抢快门按钮的戏。
class CameraSwitchButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CameraSwitchButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AppCircleIconButton(
      icon: Icons.cameraswitch,
      onPressed: onPressed,
      size: AppSpacing.cameraButtonSize,
      iconOpacity: 0.75,
    );
  }
}