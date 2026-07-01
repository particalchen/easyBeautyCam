import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart' show Offset, Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/services/camera_service.dart';

void main() {
  group('CameraService', () {
    test('pausePreview 在 controller 未初始化时静默返回', () async {
      final service = CameraService();
      // 没调 initialize，_controller == null
      await service.pausePreview(); // 不应抛
      await service.resumePreview(); // 不应抛
    });

    test('setOrientationFromDevice 在 controller 未初始化时静默返回', () async {
      final service = CameraService();
      // 没调 initialize，_controller == null
      await service.setOrientationFromDevice(Orientation.portrait);   // 不应抛
      await service.setOrientationFromDevice(Orientation.landscape); // 不应抛
    });
  });

  group('mapOrientationToDeviceOrientation', () {
    test('portrait → portraitUp', () {
      expect(
        mapOrientationToDeviceOrientation(Orientation.portrait),
        DeviceOrientation.portraitUp,
      );
    });

    test('landscape → landscapeLeft', () {
      expect(
        mapOrientationToDeviceOrientation(Orientation.landscape),
        DeviceOrientation.landscapeLeft,
      );
    });
  });

  group('mapTapToSensorFocusPoint', () {
    // 用户报的 bug：iPhone portrait + 16:9 sensor（previewSize 1920×1080），
    // 点击 frame 后焦点偏。本组测试覆盖换算正确性。
    //
    // 注意：本函数只做 FittedBox cover 反推裁切，**不做** sensor 旋转反变换——
    // iOS `camera_avfoundation` plugin 内部已用 `cgPoint(for:withOrientation:)`
    // 做了。返回的是 SizedBox/texture 归一化坐标，可直接喂 `setFocusPoint`。
    const frameAspect = 3 / 4; // CameraScreen 永远用 AspectRatio(3/4) 在逻辑层
    const sensorAspect16x9 = 16 / 9; // iOS 预览常见比例
    const sensorAspect4x3 = 4 / 3; // iPhone 后置拍照常见比例

    Offset call({
      required Offset tap,
      required double sensorAspect,
      required bool isLandscape,
    }) =>
        mapTapToSensorFocusPoint(
          tapInDisplayFrame: tap,
          sensorAspect: sensorAspect,
          displayFrameAspect: frameAspect,
          isLandscape: isLandscape,
        );

    test('portrait + 16:9 sensor：点击中心 (0.5, 0.5) → texture 中心 (0.5, 0.5)', () {
      final p = call(
        tap: const Offset(0.5, 0.5),
        sensorAspect: sensorAspect16x9,
        isLandscape: false,
      );
      expect(p.dx, closeTo(0.5, 1e-9));
      expect(p.dy, closeTo(0.5, 1e-9));
    });

    test('portrait + 16:9 sensor：点击左上 (0, 0) → texture (0, 0.125)', () {
      // 16:9 sensor → displayAspect = 9/16 = 0.5625；frame 0.75，cover 裁上下，
      // visibleHeightRatio = 0.75，cropTop = 0.125
      // frame 顶部 → texture 顶部（可见区起点）= (0, 0.125)
      final p = call(
        tap: Offset.zero,
        sensorAspect: sensorAspect16x9,
        isLandscape: false,
      );
      expect(p.dx, closeTo(0.0, 1e-9));
      expect(p.dy, closeTo(0.125, 1e-9));
    });

    test('portrait + 16:9 sensor：点击右下 (1, 1) → texture (1, 0.875)', () {
      // frame 底部 → texture 底部（可见区终点）= (1, 0.875)
      final p = call(
        tap: const Offset(1, 1),
        sensorAspect: sensorAspect16x9,
        isLandscape: false,
      );
      expect(p.dx, closeTo(1.0, 1e-9));
      expect(p.dy, closeTo(0.875, 1e-9));
    });

    test('portrait + 16:9 sensor：点击上边缘中点 (0.5, 0) → texture (0.5, 0.125)',
        () {
      // 〇十七 回归：之前双重旋转时这个 tap 会变成 sensor (0.875, 0.5)，
      // 焦点比触摸点偏右下。修后只剩 cover 反推，y 落在 0.125（可见区顶部），
      // X 跟触摸一致。
      final p = call(
        tap: const Offset(0.5, 0),
        sensorAspect: sensorAspect16x9,
        isLandscape: false,
      );
      expect(p.dx, closeTo(0.5, 1e-9));
      expect(p.dy, closeTo(0.125, 1e-9));
    });

    test('portrait + 4:3 sensor（无裁切）：tap 直接透传', () {
      // 4:3 sensor → displayAspect = 3/4 = frame aspect → cover 无裁切
      expect(
        call(tap: const Offset(0.5, 0.5), sensorAspect: sensorAspect4x3, isLandscape: false),
        const Offset(0.5, 0.5),
      );
      expect(
        call(tap: Offset.zero, sensorAspect: sensorAspect4x3, isLandscape: false),
        Offset.zero,
        reason: '无裁切 + 不旋转 = tap 透传',
      );
      expect(
        call(tap: const Offset(1, 1), sensorAspect: sensorAspect4x3, isLandscape: false),
        const Offset(1, 1),
        reason: '无裁切 + 不旋转 = tap 透传',
      );
    });

    test('landscape + 16:9 sensor：cover 裁左右，X 偏移，Y 透传', () {
      // landscape: sizedBoxAspect = sensorAspect = 16/9 ≈ 1.78
      // frame 0.75，1.78 > 0.75 → cover 裁左右，匹配高度
      // visibleWidthRatio = 0.75 / 1.78 ≈ 0.4219
      // cropLeft = (1 - 0.4219) / 2 ≈ 0.2891
      const visibleWidthRatio = 0.75 / (16 / 9);
      const cropLeft = (1 - 0.75 / (16 / 9)) / 2;

      // 点 (0, 0.5)：frame 左边 → texture 可见区左缘 = (cropLeft, 0.5)
      final leftEdge = call(
        tap: const Offset(0, 0.5),
        sensorAspect: sensorAspect16x9,
        isLandscape: true,
      );
      expect(leftEdge.dx, closeTo(cropLeft, 1e-9));
      expect(leftEdge.dy, closeTo(0.5, 1e-9));

      // 点 (1, 0.5)：frame 右边 → texture 可见区右缘 = (cropLeft + vwr, 0.5)
      final rightEdge = call(
        tap: const Offset(1, 0.5),
        sensorAspect: sensorAspect16x9,
        isLandscape: true,
      );
      expect(rightEdge.dx, closeTo(cropLeft + visibleWidthRatio, 1e-9));
      expect(rightEdge.dy, closeTo(0.5, 1e-9));

      // 点 (0.5, 0.5)：中心 → 中心 (对称变换)
      final center = call(
        tap: const Offset(0.5, 0.5),
        sensorAspect: sensorAspect16x9,
        isLandscape: true,
      );
      expect(center.dx, closeTo(cropLeft + 0.5 * visibleWidthRatio, 1e-9));
      expect(center.dy, closeTo(0.5, 1e-9),
          reason: 'Y 不受裁切影响，透传');
    });

    test('边界值：landscape + sensorAspect == frameAspect 时无裁切', () {
      // landscape + sensorAspect=0.75 时 sizedBoxAspect = 0.75 = frameAspect → 无裁切
      final result = mapTapToSensorFocusPoint(
        tapInDisplayFrame: const Offset(0.5, 0.5),
        sensorAspect: 0.75,
        displayFrameAspect: 0.75,
        isLandscape: true,
      );
      expect(result, const Offset(0.5, 0.5),
          reason: '无裁切 + 不旋转 = tap 透传');
    });

    test('回归：iOS plugin cgPoint（portrait）后 inverse 回 texture 应等于本函数 output', () {
      // 〇十七 双重旋转 bug 的回归测试：
      //   函数 output → iOS cgPoint → sensor → 90° CW inverse → texture
      //   应等于函数 output（焦点显示位置 = 函数告诉 iOS 的位置）
      //
      // 模拟 iOS plugin 的 cgPoint(for:withOrientation: .portrait)：
      //   input (x, y) → output (y, 1 - x)   （texture → sensor）
      // sensor → texture（90° CW 视觉）：(x, y) → (1-y, x)
      Offset iosCgPoint(Offset p) => Offset(p.dy, 1 - p.dx);
      Offset sensorToTexture(Offset s) => Offset(1 - s.dy, s.dx);

      for (final tap in [
        Offset.zero,
        const Offset(0.5, 0.5),
        const Offset(1, 1),
        const Offset(0.5, 0),
        const Offset(0, 0.5),
      ]) {
        final output = call(tap: tap, sensorAspect: sensorAspect16x9, isLandscape: false);
        final back = sensorToTexture(iosCgPoint(output));
        expect(back.dx, closeTo(output.dx, 1e-9), reason: 'tap=$tap');
        expect(back.dy, closeTo(output.dy, 1e-9), reason: 'tap=$tap');
      }
    });
  });
}