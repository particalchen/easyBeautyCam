import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'capture_button.dart';

class CameraControls extends StatelessWidget {
  final int cameraIndex;
  final Function(int) onCameraSwitch;
  final VoidCallback onCapture;

  const CameraControls({
    super.key,
    required this.cameraIndex,
    required this.onCameraSwitch,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 相册按钮
          _buildControlButton(
            icon: Icons.photo_library_outlined,
            onTap: () => Navigator.pushNamed(context, '/album'),
          ),
          // 镜头切换按钮
          Row(
            children: [
              _buildLensButton('1x', 0),
              const SizedBox(width: 8),
              _buildLensButton('2x', 1),
              const SizedBox(width: 8),
              _buildLensButton('3x', 2),
            ],
          ),
          // 拍照按钮
          CaptureButton(onPressed: onCapture),
          // 占位（对称布局）
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildLensButton(String label, int index) {
    final isSelected = cameraIndex == index;
    return GestureDetector(
      onTap: () => onCameraSwitch(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}