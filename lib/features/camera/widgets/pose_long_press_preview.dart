import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/pose_long_press_provider.dart';
import '../../../core/theme/app_colors.dart';

/// 长按 PoseThumbStrip 缩略图时叠加在取景框上的半透明 pose 原图。
///
/// 与 PoseOverlay 互斥：长按期间 PoseOverlay 隐藏，本 widget 接管画面。
/// - 半透明（opacity 0.5）让用户既能看到 pose 真实长相，又保留对取景画面的位置感
/// - 不带颜色/混合模式，直接显示 -res 原图（彩色参考），与 PoseOverlay 的"白色轮廓"区别开
/// - IgnorePointer 不拦截 tap-to-focus 等手势
/// - 长按结束后 state=null → 本 widget 渲染 SizedBox.shrink()，PoseOverlay 自动恢复
class PoseLongPressPreview extends ConsumerWidget {
  const PoseLongPressPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pose = ref.watch(poseLongPressProvider);
    if (pose == null) {
      return const SizedBox.shrink();
    }

    final imagePath = pose.referenceAssetPath ?? pose.assetPath;

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.5,
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Container(
              color: AppColors.poseLine.withOpacity(0.05),
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.poseLine,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}