import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../filter_view_model.dart';

/// 美颜三档滑杆：磨皮 / 美白 / 瘦脸
///
/// 设计：DESIGN.md Components › Filter & Beauty Sliders
/// - 横向 track
/// - active 段为珊瑚色
/// - 拇指（thumb）为大号圆形
class BeautySlider extends ConsumerWidget {
  const BeautySlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMain,
        vertical: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSlider(
            context,
            l10n.beautySmooth,
            state.smooth,
            (v) => notifier.setSmooth(v),
          ),
          const SizedBox(height: AppSpacing.gutterGrid),
          _buildSlider(
            context,
            l10n.beautyWhiten,
            state.whiten,
            (v) => notifier.setWhiten(v),
          ),
          const SizedBox(height: AppSpacing.gutterGrid),
          _buildSlider(
            context,
            l10n.beautySlim,
            state.slim,
            (v) => notifier.setSlim(v),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(BuildContext context, String label, double value, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurface,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            // 滑动条压低高度：track 2pt、thumb 12pt
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${value.round()}',
            style: AppTypography.numericLabel.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
