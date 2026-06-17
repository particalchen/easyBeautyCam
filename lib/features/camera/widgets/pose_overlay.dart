import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pose_library/pose_manager.dart';
import '../../../core/theme/app_colors.dart';

/// 姿势轮廓叠加层
///
/// 设计：DESIGN.md Components › Marker Pose Outlines
/// - 半透明白色（rgba 255,255,255,0.55）
/// - 1px 软外发光
/// - 不跟随相机缩放（外层 Positioned.fill 已经脱离 GestureDetector 缩放层）
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 外发光
            Opacity(
              opacity: 0.20,
              child: Image.asset(
                currentPose.assetPath,
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.srcATop,
                errorBuilder: _errorBuilder,
              ),
            ),
            // 主轮廓（半透明白）
            Opacity(
              opacity: 0.55,
              child: Image.asset(
                currentPose.assetPath,
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.srcATop,
                errorBuilder: _errorBuilder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBuilder(BuildContext context, Object error, StackTrace? stack) {
    // 资源缺失时用轮廓色占位，避免白屏
    return Container(
      color: AppColors.poseLine.withOpacity(0.05),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined,
          color: AppColors.poseLine, size: 48),
    );
  }
}
