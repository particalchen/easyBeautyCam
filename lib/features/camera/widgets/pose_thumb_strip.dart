import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pose_library/pose_manager.dart';
import '../../../core/theme/app_theme.dart';

class PoseThumbStrip extends ConsumerWidget {
  const PoseThumbStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poseState = ref.watch(poseManagerProvider);

    if (poseState.poses.isEmpty) {
      return const SizedBox(height: 80);
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: poseState.poses.length,
        itemBuilder: (context, index) {
          final isSelected = index == poseState.selectedIndex;
          final pose = poseState.poses[index];

          return GestureDetector(
            onTap: () => ref.read(poseManagerProvider.notifier).selectPose(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              height: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  pose.assetPath,
                  fit: BoxFit.cover,
                  color: Colors.white.withOpacity(isSelected ? 0.9 : 0.5),
                  colorBlendMode: BlendMode.srcATop,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}