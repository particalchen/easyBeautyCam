import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pose_library/pose_manager.dart';
import '../../../core/theme/app_theme.dart';

class PoseOverlay extends ConsumerWidget {
  const PoseOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poseState = ref.watch(poseManagerProvider);
    if (poseState.poses.isEmpty || poseState.selectedIndex >= poseState.poses.length) {
      return const SizedBox.shrink();
    }

    final currentPose = poseState.poses[poseState.selectedIndex];

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.55,
          child: Image.asset(
            currentPose.assetPath,
            fit: BoxFit.contain,
            color: Colors.white,
            colorBlendMode: BlendMode.srcATop,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}