import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import 'camera_switch_button.dart';
import 'capture_button.dart';
import 'pose_thumb_strip.dart';

/// 底部相机控制栏
///
/// 布局（自上而下）：
/// 1. PoseStrip（[showPoseStrip] 为 true 时显示；前置相机不显示）
/// 2. 控制栏（占位 | 快门 | 相机切换）
///
/// 焦段 pill 已上移为浮在 preview 顶部的 ZoomPillBar，不在 CameraControls 里。
class CameraControls extends StatelessWidget {
  final int cameraIndex;
  final bool showPoseStrip;
  final ValueChanged<int> onCameraSwitch;
  final VoidCallback onCapture;

  const CameraControls({
    super.key,
    required this.cameraIndex,
    required this.showPoseStrip,
    required this.onCameraSwitch,
    required this.onCapture,
  });

  bool get _isFront => cameraIndex == 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPoseStrip) const PoseThumbStrip(),
          SizedBox(height: showPoseStrip ? AppSpacing.gutterGrid : 0),
          // 控制栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: AppSpacing.thumbHotzone),
              CaptureButton(onPressed: onCapture),
              CameraSwitchButton(
                onPressed: () => onCameraSwitch(_isFront ? 0 : 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
