import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../filter_view_model.dart';
import '../../../services/image_processing_service.dart';
import '../../../core/theme/app_theme.dart';

class FilterCarousel extends ConsumerWidget {
  const FilterCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: FilterType.values.length,
        itemBuilder: (context, index) {
          final filter = FilterType.values[index];
          final isSelected = filter == state.selectedFilter;
          final filterName = _getFilterName(filter);

          return GestureDetector(
            onTap: () => notifier.selectFilter(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filterName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  String _getFilterName(FilterType filter) {
    switch (filter) {
      case FilterType.original: return '原图';
      case FilterType.coral: return '珊瑚';
      case FilterType.gangfeng: return '港风';
      case FilterType.rixi: return '日系';
      case FilterType.jiaopian: return '胶片';
    }
  }

  Color _getFilterPreviewColor(FilterType filter) {
    switch (filter) {
      case FilterType.original: return Colors.grey;
      case FilterType.coral: return const Color(0xFFFFB4A2);
      case FilterType.gangfeng: return const Color(0xFF8B7355);
      case FilterType.rixi: return const Color(0xFFFFF8DC);
      case FilterType.jiaopian: return const Color(0xFFD4A574);
    }
  }
}