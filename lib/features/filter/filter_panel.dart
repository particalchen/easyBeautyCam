import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'filter_view_model.dart';
import 'widgets/filter_carousel.dart';
import 'widgets/beauty_slider.dart';
import '../../core/theme/app_theme.dart';

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterViewModelProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.overlayBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                const Text('编辑', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => _save(context, ref),
                  child: const Text('保存', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
          // 图片预览
          if (state.imagePath != null)
            Container(
              height: 300,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(File(state.imagePath!)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 16),
          // 滤镜选择
          const FilterCarousel(),
          const SizedBox(height: 16),
          // 美颜滑杆
          const BeautySlider(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filterViewModelProvider.notifier);
    await notifier.saveProcessedImage();
    if (context.mounted) Navigator.pop(context, true);
  }
}