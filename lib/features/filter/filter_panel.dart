import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import 'filter_view_model.dart';
import 'widgets/beauty_slider.dart';
import 'widgets/crop_ratio_bar.dart';
import 'widgets/filter_carousel.dart';
import 'widgets/interactive_crop_editor.dart';

/// 拍后编辑页（全屏路由）：图片预览 + 滤镜/美颜/裁切 tab
///
/// 触发：拍完照后从 camera_screen Navigator.push(MaterialPageRoute(fullscreenDialog: true)) 进入
/// 布局（自上而下）：
/// 1. 顶部栏（取消 / 编辑 / 保存）
/// 2. 图片预览（Expanded，占满中间空间）
/// 3. TabBar（滤镜 / 美颜 / 裁切）
/// 4. TabBarView（高度 150）
class FilterPanel extends ConsumerStatefulWidget {
  const FilterPanel({super.key});

  @override
  ConsumerState<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<FilterPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(filterViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.overlayBg,
      body: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // ── 顶部栏 ──
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
                  Text(l10n.actionEdit, style: AppTypography.headlineMd),
                  TextButton(
                    onPressed: state.isProcessing
                        ? null
                        : () => _save(context, ref),
                    child: state.isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
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
            // ── 图片预览（Expanded）──
            if (state.imagePath != null || state.previewBytes != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMain),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: InteractiveCropEditor(
                      previewBytes: state.previewBytes,
                      imagePath: state.imagePath,
                      cropRatio: state.cropRatio,
                      scale: state.scale,
                      translation: state.translation,
                      onTransformChanged: (s, t) => ref
                          .read(filterViewModelProvider.notifier)
                          .setTransform(scale: s, translation: t),
                    ),
                  ),
                ),
              ),
            // ── TabBar ──
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: '滤镜'),
                Tab(text: '美颜'),
                Tab(text: '裁切'),
              ],
            ),
            // ── TabView（高度 150）──
            SizedBox(
              height: 150,
              child: TabBarView(
                controller: _tabController,
                children: const [
                  FilterCarousel(),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: BeautySlider(),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: CropRatioBar(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filterViewModelProvider.notifier);
    final path = await notifier.saveProcessedImage();
    if (context.mounted) Navigator.pop(context, path);
  }
}