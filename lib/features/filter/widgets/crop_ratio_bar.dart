import 'dart:ui' show Offset;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/image_processing_service.dart';
import '../filter_view_model.dart';

/// 裁切比例选择条 —— 6 个比例按钮（原图 / 16:9 / 4:3 / 1:1 / 3:4 / 9:16）+ 重置按钮（最右侧图标）
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
          child: Text(
            '裁切比例',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
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
                // 重置按钮：放在最右侧
                _ResetIconButton(
                  enabled: canReset,
                  onTap: () => notifier.resetTransform(),
                ),
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
            // 上方：矩形图示（28pt 高，按宽高比显示）
            SizedBox(
              height: 28,
              width: 40,
              child: CustomPaint(
                painter: _RatioIconPainter(
                  ratio: ratio ?? 1.0, // 原图显示方形
                  color: isSelected ? Colors.white : AppColors.onSurface,
                  isOriginal: ratio == null,
                ),
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

/// 比例图示 painter：按宽高比画矩形
class _RatioIconPainter extends CustomPainter {
  final double ratio; // width / height
  final Color color;
  final bool isOriginal;

  _RatioIconPainter({
    required this.ratio,
    required this.color,
    required this.isOriginal,
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
      ..strokeWidth = 1.5;
    canvas.drawRect(frameRect, paint);

    // 原图 chip 额外画一个 "无裁切" 标识（角标或全屏标记）
    if (isOriginal) {
      // 在矩形外画 4 个角（表示"完整保留"）
      final cornerLen = 4.0;
      final cornerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      // 左上
      canvas.drawLine(
        Offset(0, cornerLen),
        const Offset(0, 0),
        cornerPaint,
      );
      canvas.drawLine(
        const Offset(0, 0),
        Offset(cornerLen, 0),
        cornerPaint,
      );
      // 右上
      canvas.drawLine(
        Offset(size.width - cornerLen, 0),
        Offset(size.width, 0),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, cornerLen),
        cornerPaint,
      );
      // 左下
      canvas.drawLine(
        Offset(0, size.height - cornerLen),
        Offset(0, size.height),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(0, size.height),
        Offset(cornerLen, size.height),
        cornerPaint,
      );
      // 右下
      canvas.drawLine(
        Offset(size.width - cornerLen, size.height),
        Offset(size.width, size.height),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(size.width, size.height - cornerLen),
        Offset(size.width, size.height),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RatioIconPainter old) =>
      old.ratio != ratio || old.color != color || old.isOriginal != isOriginal;
}

/// 重置按钮：圆形 IconButton，放在比例行最右侧
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
