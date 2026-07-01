// 测试 PoseLongPressNotifier 的状态变迁
//
// 关键场景：
// - 初始 state == null
// - show(poseA) → state == poseA
// - show(poseB) → state == poseB（连续长按另一张）
// - clear() → state == null
// - show → clear → show 反复切换必须保持正确

import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/camera/state/pose_long_press_provider.dart';
import 'package:easy_beauty_cam/features/pose_library/pose_model.dart';

const _poseA = PoseModel(
  id: 'a',
  name: 'A',
  category: 'c',
  assetPath: 'resources/poses/a.png',
  isLocal: true,
);
const _poseB = PoseModel(
  id: 'b',
  name: 'B',
  category: 'c',
  assetPath: 'resources/poses/b.png',
  isLocal: true,
);

void main() {
  group('PoseLongPressNotifier', () {
    test('初始 state 为 null', () {
      final notifier = PoseLongPressNotifier();
      expect(notifier.state, isNull);
    });

    test('show(pose) 写入状态；clear() 清空', () {
      final notifier = PoseLongPressNotifier();
      notifier.show(_poseA);
      expect(notifier.state, _poseA);

      notifier.clear();
      expect(notifier.state, isNull);
    });

    test('连续长按另一张 → state 切换到新 pose（不累加）', () {
      final notifier = PoseLongPressNotifier();
      notifier.show(_poseA);
      expect(notifier.state, _poseA);

      // 模拟：A 还没松开时用户已经触发了 B 的长按（边缘场景——实际不会发生，但状态机应正确）
      notifier.show(_poseB);
      expect(notifier.state, _poseB);
    });

    test('show / clear 反复切换保持正确', () {
      final notifier = PoseLongPressNotifier();
      for (var i = 0; i < 5; i++) {
        notifier.show(_poseA);
        expect(notifier.state, _poseA);
        notifier.clear();
        expect(notifier.state, isNull);
      }
    });
  });
}