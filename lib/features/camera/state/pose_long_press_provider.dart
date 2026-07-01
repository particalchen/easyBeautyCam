import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pose_library/pose_model.dart';

/// 长按 PoseThumbStrip 缩略图时，正在被长按的那张 pose 的瞬时状态。
///
/// - `null` —— 没有长按发生（或上一次长按已结束）
/// - 非 null —— 用户正在长按这张 pose；PoseOverlay 应该隐藏、PoseLongPressPreview 应该显示
///
/// 设计说明：纯瞬时 UI 状态，不持久化、不与 `poseManagerProvider` 的 `selectedIndex` 耦合
/// （长按不影响"当前选中的 pose"——松手后视觉恢复原状，但不改变选区）。
class PoseLongPressNotifier extends StateNotifier<PoseModel?> {
  PoseLongPressNotifier() : super(null);

  void show(PoseModel pose) {
    state = pose;
  }

  void clear() {
    state = null;
  }
}

final poseLongPressProvider =
    StateNotifierProvider<PoseLongPressNotifier, PoseModel?>(
  (ref) => PoseLongPressNotifier(),
);