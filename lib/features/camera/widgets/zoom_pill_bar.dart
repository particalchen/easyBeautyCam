import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 浮在 preview frame 顶部的焦段 pill 横排
///
/// 设计：DESIGN.md Components › Zoom Pills (overlay variant)
/// - 半透明深色背景 + 圆角胶囊
/// - 选中态用 primary 色
/// - 选中判定用 [lastSelectedPillZoom]（区分"点 pill 选中"和"pinch 后碰巧等于"）
class ZoomPillBar extends StatelessWidget {
  final int cameraIndex;
  final double minZoom;
  final double maxZoom;
  /// 最近一次点 pill 选中的焦段值；null 表示当前 zoom 不是通过 pill 选中的
  /// （pinch / 初始 / 切换相机后）—— 此时所有 pill 都取消高亮。
  final double? lastSelectedPillZoom;
  final ValueChanged<double> onSelect;

  const ZoomPillBar({
    super.key,
    required this.cameraIndex,
    required this.minZoom,
    required this.maxZoom,
    required this.lastSelectedPillZoom,
    required this.onSelect,
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
    return '${z.toString()}x';
  }

  @override
  Widget build(BuildContext context) {
    final allZooms = _isFront ? _frontZooms : _backZooms;
    final zooms = allZooms
        .where((z) => z >= minZoom - 0.01 && z <= maxZoom + 0.01)
        .toList();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.inverseSurface.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < zooms.length; i++) ...[
              _buildPill(zooms[i], _isPillSelected(zooms[i])),
              if (i < zooms.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  /// pill 选中判定：
  /// - [lastSelectedPillZoom] 不为 null 时，比较 pill 与它的差值
  /// - 为 null 时（pinch 缩放后 / 初始 / 切相机），永远不选中
  bool _isPillSelected(double pillZoom) {
    if (lastSelectedPillZoom == null) return false;
    return (lastSelectedPillZoom! - pillZoom).abs() < 0.01;
  }

  Widget _buildPill(double zoom, bool isSelected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(zoom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutterGrid,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
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
