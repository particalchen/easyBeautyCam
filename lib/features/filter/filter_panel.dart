import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import 'filter_view_model.dart';
import 'widgets/filter_carousel.dart';
import 'widgets/beauty_slider.dart';

/// 滤镜 + 美颜 浮层
///
/// 触发时机：拍完照后从 camera_screen 弹出（showModalBottomSheet）
/// 设计：DESIGN.md Elevation & Depth › Floating Panels
/// - 半透明暖白底（overlay-bg） + 高斯模糊（在调用方外面包一层 BackdropFilter 可选）
/// - 顶部 24px 圆角
class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(filterViewModelProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.overlayBg,
        borderRadius: AppRadii.sheetTop,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 顶部把手 ──
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
            ),
            // ── 顶部栏：取消 / 编辑 / 保存 ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMain,
                vertical: AppSpacing.gutterGrid,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.actionCancel,
                      style: AppTypography.buttonText.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    l10n.actionEdit,
                    style: AppTypography.headlineMd,
                  ),
                  TextButton(
                    onPressed: () => _save(context, ref),
                    child: Text(
                      l10n.actionSave,
                      style: AppTypography.buttonText.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── 图片预览 ──
            if (state.imagePath != null)
              Container(
                height: 300,
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMain,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.xlAll,
                  image: DecorationImage(
                    image: FileImage(File(state.imagePath!)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.gutterGrid),
            // ── 滤镜选择 ──
            const FilterCarousel(),
            const SizedBox(height: AppSpacing.gutterGrid),
            // ── 美颜滑杆 ──
            const BeautySlider(),
            const SizedBox(height: AppSpacing.gutterGrid),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filterViewModelProvider.notifier);
    await notifier.saveProcessedImage();
    if (context.mounted) Navigator.pop(context, true);
  }
}
