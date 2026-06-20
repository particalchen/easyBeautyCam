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
/// 1. 焦段 pill 行（后置 [.5x, 1x, 2x, 3x] / 前置 [1x]）—— 过滤到硬件支持范围
/// 2. 控制栏（占位 | 快门 | 相机切换）
class CameraControls extends StatelessWidget {
  final int cameraIndex;
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<int> onCameraSwitch;
  final ValueChanged<double> onZoomSelect;
  final VoidCallback onCapture;

  const CameraControls({
    super.key,
    required this.cameraIndex,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onCameraSwitch,
    required this.onZoomSelect,
    required this.onCapture,
  });

  /// 焦段档位池（候选）
  /// 后置：[0.5, 1.0, 2.0, 3.0]
  /// 前置：[1.0]
  /// 实际 UI 只显示硬件 [minZoom, maxZoom] 范围内的值
  static const _backZooms = <double>[0.5, 1.0, 2.0, 3.0];
  static const _frontZooms = <double>[1.0];

  bool get _isFront => cameraIndex == 1;

  /// 统一显示为 "Nx" 格式：0.5 → "0.5x"、1 → "1x"、2 → "2x"、3 → "3x"
  String _zoomLabel(double z) {
    if (z == z.truncateToDouble()) {
      return '${z.toInt()}x';
    }
    // 0.5 这种非整数也带 "x"
    return '${z.toString()}x';
  }

  @override
  Widget build(BuildContext context) {
    final allZooms = _isFront ? _frontZooms : _backZooms;
    // 过滤掉硬件不支持的焦段
    final zooms = allZooms
        .where((z) => z >= minZoom - 0.01 && z <= maxZoom + 0.01)
        .toList();

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
                _buildZoomPill(zooms[i], _isPillSelected(zooms[i])),
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

  /// pill 选中判定：硬件 clamp 后相等就算选中
  /// 这样如果 currentZoom 是用户拉 pinch 得到的非整数，pill 仍能正确高亮
  bool _isPillSelected(double pillZoom) {
    final clamped = pillZoom.clamp(minZoom, maxZoom);
    return (currentZoom - clamped).abs() < 0.01;
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
              : AppColors.inverseSurface.withValues(alpha: 0.4),
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
