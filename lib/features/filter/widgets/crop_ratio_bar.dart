import 'dart:ui' show Offset;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/image_processing_service.dart';
import '../filter_view_model.dart';

/// 裁切比例选择条 —— 6 个比例按钮（自由 / 16:9 / 4:3 / 1:1 / 3:4 / 9:16）+ 重置按钮
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
                _ResetChip(
                  enabled: canReset,
                  onTap: () => notifier.resetTransform(),
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final ratio in _ratios) ...[
                  _RatioChip(
                    label: ratio.label,
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

class _ResetChip extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ResetChip({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.surfaceContainerHigh
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(
            color: enabled ? AppColors.outline : AppColors.outlineVariant,
            width: 1,
          ),
        ),
        child: Text(
          '重置',
          style: AppTypography.numericLabel.copyWith(
            color: enabled
                ? AppColors.onSurface
                : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _RatioChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RatioChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        child: Text(
          label,
          style: AppTypography.numericLabel.copyWith(
            color: isSelected ? Colors.white : AppColors.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
