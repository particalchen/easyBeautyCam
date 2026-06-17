import 'package:flutter/material.dart';

/// 通用圆环 icon 按钮 —— 相机切换按钮、相册按钮复用
///
/// 视觉规范：
/// - 半透黑底（0x66000000）
/// - 1.5pt 白色边框
/// - 线性 / outline 图标
class AppCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x66000000),
      shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 1.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
