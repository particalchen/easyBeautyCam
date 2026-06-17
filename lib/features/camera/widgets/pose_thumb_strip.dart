import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pose_library/pose_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 姿势缩略图横向滑动条
///
/// 设计：DESIGN.md Components › Pose Thumbnails
/// - 卡片圆角 1rem（AppRadii.xl = 16px）
/// - 未选中：1px 浅灰描边
/// - 选中：2px 珊瑚描边（无 scale 1.05x，已在原版本移除，避免误触）
class PoseThumbStrip extends ConsumerWidget {
  const PoseThumbStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poseState = ref.watch(poseManagerProvider);

    if (poseState.poses.isEmpty) {
      return const SizedBox(height: AppSpacing.poseThumbnail);
    }

    return SizedBox(
      height: AppSpacing.poseThumbnail,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
        itemCount: poseState.poses.length,
        itemBuilder: (context, index) {
          final isSelected = index == poseState.selectedIndex;
          final pose = poseState.poses[index];

          return GestureDetector(
            onTap: () => ref.read(poseManagerProvider.notifier).selectPose(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: AppSpacing.poseThumbnail - 20, // 60pt 宽
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: AppRadii.thumbnail,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderLight,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.xl - 1),
                child: Image.asset(
                  pose.assetPath,
                  fit: BoxFit.cover,
                  color: Colors.white.withOpacity(isSelected ? 0.95 : 0.5),
                  colorBlendMode: BlendMode.srcATop,
                  errorBuilder: (context, error, stack) => Container(
                    color: AppColors.surfaceContainer,
                    alignment: Alignment.center,
                    child: Text(
                      '#${index + 1}',
                      style: AppTypography.numericLabel.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
