// 测试 CameraViewModel.setZoom 的 fromPill 参数行为
//
// 关键场景：
// - fromPill=true → lastSelectedPillZoom = zoom
// - fromPill=false（默认，如 pinch）→ lastSelectedPillZoom = null
// - 反复切换必须保持正确

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/widgets.dart' show Offset, Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/camera/camera_view_model.dart';
import 'package:easy_beauty_cam/services/camera_service.dart';

class _FakeCameraService extends CameraService {
  double? _zoom;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setZoom(double zoom) async {
    _zoom = zoom;
  }

  @override
  Future<void> switchCamera(int index) async {}

  @override
  Future<XFile?> takePicture() async => null;

  @override
  Future<void> focusAndExposeAt(Offset normalizedPoint) async {}

  @override
  Future<void> setOrientationFromDevice(Orientation orientation) async {}

  @override
  Future<void> pausePreview() async {}

  @override
  Future<void> resumePreview() async {}

  @override
  void dispose() {}

  double? get appliedZoom => _zoom;
}

void main() {
  group('CameraViewModel.setZoom(fromPill:)', () {
    test('fromPill=true 时 lastSelectedPillZoom 记录该值', () async {
      final fake = _FakeCameraService();
      final vm = CameraViewModel(fake);
      await vm.setZoom(2.0, fromPill: true);

      expect(vm.state.currentZoom, 2.0);
      expect(vm.state.lastSelectedPillZoom, 2.0);
    });

    test('fromPill=false（pinch）时 lastSelectedPillZoom 清空', () async {
      final fake = _FakeCameraService();
      final vm = CameraViewModel(fake);
      // 先点 pill 选中 2x
      await vm.setZoom(2.0, fromPill: true);
      expect(vm.state.lastSelectedPillZoom, 2.0);

      // 然后 pinch 缩放（fromPill 默认 false）
      await vm.setZoom(2.5);
      expect(vm.state.currentZoom, 2.5);
      expect(vm.state.lastSelectedPillZoom, isNull,
          reason: 'pinch 缩放后应清空 lastSelectedPillZoom');
    });

    test('点 pill 取消之前 pinch 引入的"未选中"状态', () async {
      final fake = _FakeCameraService();
      final vm = CameraViewModel(fake);
      // pinch 缩放
      await vm.setZoom(2.7);
      expect(vm.state.lastSelectedPillZoom, isNull);

      // 点 pill
      await vm.setZoom(2.0, fromPill: true);
      expect(vm.state.lastSelectedPillZoom, 2.0);
    });

    test('点 pill 切换焦段（2x → 3x），pill 选中态跟随切换', () async {
      final fake = _FakeCameraService();
      final vm = CameraViewModel(fake);
      await vm.setZoom(2.0, fromPill: true);
      expect(vm.state.lastSelectedPillZoom, 2.0);

      await vm.setZoom(3.0, fromPill: true);
      expect(vm.state.currentZoom, 3.0);
      expect(vm.state.lastSelectedPillZoom, 3.0);
    });

    test('initial state: lastSelectedPillZoom 为 null', () {
      final fake = _FakeCameraService();
      final vm = CameraViewModel(fake);

      expect(vm.state.currentZoom, 1.0);
      expect(vm.state.lastSelectedPillZoom, isNull,
          reason: '初始状态不应有 pill 选中');
    });

    test('Pinch 后再点 pill 同一档位，pill 重新高亮', () async {
      final fake = _FakeCameraService();
      final vm = CameraViewModel(fake);
      // 先点 2x pill
      await vm.setZoom(2.0, fromPill: true);
      expect(vm.state.lastSelectedPillZoom, 2.0);
      // pinch 微调
      await vm.setZoom(2.3);
      expect(vm.state.lastSelectedPillZoom, isNull);
      // 再点 2x pill
      await vm.setZoom(2.0, fromPill: true);
      expect(vm.state.lastSelectedPillZoom, 2.0,
          reason: '再次点 pill 后应恢复 lastSelectedPillZoom');
    });
  });
}
