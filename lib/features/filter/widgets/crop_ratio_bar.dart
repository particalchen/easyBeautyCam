import 'dart:ui' show Offset;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/image_processing_service.dart';
import '../filter_view_model.dart';

/// 裁切比例选择条 —— 6 个比例按钮（原图 / 16:9 / 4:3 / 1:1 / 3:4 / 9:16）
///
/// 布局：
///   ┌─ 标题行：裁切比例 [左] | 重置按钮 [右] ─┐
///   ├─ chips 行：6 个比例 chip ─┤
class CropRatioBar extends ConsumerWidget {
  const CropRatioBar({super.key});

  static const _ratios = [
    CropRatio.original,
    CropRatio.ratio_16_9,
    CropRatio.ratio_4_3,
    CropRatio.ratio_1_1,
    CropRatio.ratio_3_4,
    CropRatio.ratio_9_16,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);
    final canReset = state.scale != 1.0 || state.translation != Offset.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 标题行：裁切比例 [左] | 重置按钮 [右] ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '裁切比例',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              _ResetIconButton(
                enabled: canReset,
                onTap: () => notifier.resetTransform(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // ── chips 行：只有 6 个 chip，无重置 ──
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ratio in _ratios) ...[
                  _RatioChip(
                    label: ratio.label,
                    ratio: ratio.ratio, // null = 原图（画方形图示）
                    isSelected: state.cropRatio == ratio,
                    onTap: () => notifier.setCropRatio(ratio),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 比例 chip：上方矩形图示 + 下方文字
class _RatioChip extends StatelessWidget {
  final String label;
  final double? ratio; // null = 原图（用方形图示）
  final bool isSelected;
  final VoidCallback onTap;

  const _RatioChip({
    required this.label,
    required this.ratio,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上方：矩形图示（intrinsic size 26×18，按宽高比显示）
            CustomPaint(
              size: const Size(26, 18),
              painter: _RatioIconPainter(
                ratio: ratio ?? 1.0, // 原图显示方形
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            // 下方：文字
            Text(
              label,
              style: AppTypography.numericLabel.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 比例图示 painter：按宽高比画矩形（去掉原图的 4 角外框，更精简）
class _RatioIconPainter extends CustomPainter {
  final double ratio; // width / height
  final Color color;

  _RatioIconPainter({
    required this.ratio,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double frameW;
    double frameH;
    if (size.width / size.height > ratio) {
      frameH = size.height;
      frameW = frameH * ratio;
    } else {
      frameW = size.width;
      frameH = frameW / ratio;
    }
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameW,
      height: frameH,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(frameRect, paint);
  }

  @override
  bool shouldRepaint(_RatioIconPainter old) =>
      old.ratio != ratio || old.color != color;
}

/// 重置按钮：圆形 IconButton，放在「裁切比例」标题行最右侧
class _ResetIconButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ResetIconButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(
        Icons.refresh,
        color: enabled
            ? AppColors.primary
            : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
        size: 22,
      ),
      tooltip: '重置',
      style: IconButton.styleFrom(
        backgroundColor: enabled
            ? AppColors.surfaceContainerHigh
            : AppColors.surfaceContainer,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(6),
      ),
    );
  }
}