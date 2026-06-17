import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'camera_switch_button.dart';
import 'capture_button.dart';

/// 底部相机控制栏
///
/// 布局（自上而下）：
/// 1. 焦段 pill 行（后置 [.5, 1x, 2, 3] / 前置 [1x]）
/// 2. 控制栏（占位 | 快门 | 相机切换）
class CameraControls extends StatelessWidget {
  final int cameraIndex;
  final double currentZoom;
  final ValueChanged<int> onCameraSwitch;
  final ValueChanged<double> onZoomSelect;
  final VoidCallback onCapture;

  const CameraControls({
    super.key,
    required this.cameraIndex,
    required this.currentZoom,
    required this.onCameraSwitch,
    required this.onZoomSelect,
    required this.onCapture,
  });

  /// 写死的焦段档位（B 方案）
  /// 后置：[0.5, 1.0, 2.0, 3.0]
  /// 前置：[1.0]
  /// A 方案（动态检测硬件）放入设计文档的"未来工作"。
  static const _backZooms = <double>[0.5, 1.0, 2.0, 3.0];
  static const _frontZooms = <double>[1.0];

  bool get _isFront => cameraIndex == 1;

  /// 0.5 → ".5", 1.0 → "1x", 2.0 → "2", 3.0 → "3"
  String _zoomLabel(double z) {
    if (z == 1.0) return '1x';
    if (z == 0.5) return '.5';
    if (z == z.truncateToDouble()) return z.toInt().toString();
    return z.toString();
  }

  @override
  Widget build(BuildContext context) {
    final zooms = _isFront ? _frontZooms : _backZooms;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 焦段行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < zooms.length; i++) ...[
                _buildZoomPill(zooms[i], zooms[i] == currentZoom),
                if (i < zooms.length - 1) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.gutterGrid),
          // 控制栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: AppSpacing.thumbHotzone),
              CaptureButton(onPressed: onCapture),
              CameraSwitchButton(
                onPressed: () => onCameraSwitch(_isFront ? 0 : 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoomPill(double zoom, bool isSelected) {
    return GestureDetector(
      onTap: () => onZoomSelect(zoom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutterGrid,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.inverseSurface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Text(
          _zoomLabel(zoom),
          style: AppTypography.numericLabel.copyWith(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
