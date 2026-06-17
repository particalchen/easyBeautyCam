import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/image_processing_service.dart';
import '../filter_view_model.dart';

/// 滤镜横向 carousel
///
/// 设计：DESIGN.md Components › Filter & Beauty Sliders › Filter Chips
/// - 圆形或圆角方形预览
/// - 选中：2pt 珊瑚描边
class FilterCarousel extends ConsumerWidget {
  const FilterCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
        itemCount: FilterType.values.length,
        itemBuilder: (context, index) {
          final filter = FilterType.values[index];
          final isSelected = filter == state.selectedFilter;
          final filterName = _localizedFilterName(l10n, filter);

          return GestureDetector(
            onTap: () => notifier.selectFilter(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: AppRadii.lgAll,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getFilterPreviewColor(filter),
                      borderRadius: AppRadii.lgAll,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filterName,
                    style: AppTypography.numericLabel.copyWith(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _localizedFilterName(AppLocalizations l10n, FilterType filter) {
    switch (filter) {
      case FilterType.original:
        return l10n.filterOriginal;
      case FilterType.coral:
        return l10n.filterCoral;
      case FilterType.gangfeng:
        return l10n.filterGangfeng;
      case FilterType.rixi:
        return l10n.filterRixi;
      case FilterType.jiaopian:
        return l10n.filterJiaopian;
    }
  }

  Color _getFilterPreviewColor(FilterType filter) {
    switch (filter) {
      case FilterType.original:
        return AppColors.filterPreviewOriginal;
      case FilterType.coral:
        return AppColors.filterPreviewCoral;
      case FilterType.gangfeng:
        return AppColors.filterPreviewGangfeng;
      case FilterType.rixi:
        return AppColors.filterPreviewRixi;
      case FilterType.jiaopian:
        return AppColors.filterPreviewJiaopian;
    }
  }
}
