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
    // 点击 frame 中心，焦点偏到 sensor 边缘。本组测试覆盖换算正确性。
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

    test('portrait + 16:9 sensor：点击中心 (0.5, 0.5) → sensor 中心 (0.5, 0.5)', () {
      final sensor = call(
        tap: const Offset(0.5, 0.5),
        sensorAspect: sensorAspect16x9,
        isLandscape: false,
      );
      expect(sensor.dx, closeTo(0.5, 1e-9));
      expect(sensor.dy, closeTo(0.5, 1e-9));
    });

    test('portrait + 16:9 sensor：点击左上 (0, 0) → sensor 右上 (0.875, 0)', () {
      // 16:9 sensor → displayAspect = 9/16 = 0.5625；frame 0.75，cover 裁上下，
      // visibleHeightRatio = 0.75，cropTop = 0.125
      // SizedBox 坐标 (0, 0.125)；portrait 90° 反向旋转 → (1 - 0.125, 0) = (0.875, 0)
      final sensor = call(
        tap: Offset.zero,
        sensorAspect: sensorAspect16x9,
        isLandscape: false,
      );
      expect(sensor.dx, closeTo(0.875, 1e-9));
      expect(sensor.dy, closeTo(0.0, 1e-9));
    });

    test('portrait + 16:9 sensor：点击右下 (1, 1) → sensor 左下 (0.125, 1)', () {
      // SizedBox (1, 0.125 + 0.75 = 0.875)；90° 反向 → (1 - 0.875, 1) = (0.125, 1)
      final sensor = call(
        tap: const Offset(1, 1),
        sensorAspect: sensorAspect16x9,
        isLandscape: false,
      );
      expect(sensor.dx, closeTo(0.125, 1e-9));
      expect(sensor.dy, closeTo(1.0, 1e-9));
    });

    test('portrait + 16:9 sensor：点击上边缘中点 (0.5, 0) → sensor 顶部 (0.875, 0.5)',
        () {
      final sensor = call(
        tap: const Offset(0.5, 0),
        sensorAspect: sensorAspect16x9,
        isLandscape: false,
      );
      expect(sensor.dx, closeTo(0.875, 1e-9));
      expect(sensor.dy, closeTo(0.5, 1e-9));
    });

    test('portrait + 4:3 sensor（无裁切）：center / 角落映射正确', () {
      // 4:3 sensor → displayAspect = 3/4 = frame aspect → cover 无裁切
      // 旋转公式: (x, y) → (1 - y, x)
      expect(
        call(tap: const Offset(0.5, 0.5), sensorAspect: sensorAspect4x3, isLandscape: false),
        const Offset(0.5, 0.5),
        reason: '无裁切时中心点旋转后还是中心',
      );
      expect(
        call(tap: Offset.zero, sensorAspect: sensorAspect4x3, isLandscape: false),
        const Offset(1, 0),
        reason: '左上 → sensor 右上',
      );
      expect(
        call(tap: const Offset(1, 1), sensorAspect: sensorAspect4x3, isLandscape: false),
        const Offset(0, 1),
        reason: '右下 → sensor 左下',
      );
    });

    test('landscape + 16:9 sensor：cover 裁左右，映射正确', () {
      // landscape: sizedBoxAspect = sensorAspect = 16/9 ≈ 1.78
      // frame 0.75，1.78 > 0.75 → cover 裁左右，匹配高度
      // visibleWidthRatio = 0.75 / 1.78 = 0.4213...
      // cropLeft = (1 - 0.4213) / 2 ≈ 0.2893
      // landscape 显示 → sensor 旋转 180° → (1-x, 1-y)
      const visibleWidthRatio = 0.75 / (16 / 9);
      const cropLeft = (1 - 0.75 / (16 / 9)) / 2;
      // 点 (1, 0.5)：SizedBox (cropLeft + 1 * vwr, 0.5)；180° 反向 → (1 - (cropLeft+vwr), 1 - 0.5)
      final rightEdgeSensor = call(
        tap: const Offset(1, 0.5),
        sensorAspect: sensorAspect16x9,
        isLandscape: true,
      );
      expect(rightEdgeSensor.dx, closeTo(1 - (cropLeft + visibleWidthRatio), 1e-9));
      expect(rightEdgeSensor.dy, closeTo(0.5, 1e-9));

      // 点 (0.5, 0.5)：SizedBox (cropLeft + 0.5 * vwr, 0.5)
      final centerSensor = call(
        tap: const Offset(0.5, 0.5),
        sensorAspect: sensorAspect16x9,
        isLandscape: true,
      );
      expect(centerSensor.dx, closeTo(1 - (cropLeft + 0.5 * visibleWidthRatio), 1e-9));
      expect(centerSensor.dy, closeTo(0.5, 1e-9),
          reason: 'y 不受裁切影响，仅做 180° 翻转；中心 y=0.5 翻完还是 0.5');
    });

    test('边界值：sensorAspect == frameAspect 时两种方向都不裁切', () {
      // 假设某种奇葩 sensor 比例正好和 frame 一致
      // portrait 下 sizedBoxAspect = 1/0.75 = 1.333，与 frame 0.75 不等；但 frame > sizedBox 时不裁高度
      // 直接用一个会触发 "frame >= sizedBox" 分支的：sensorAspect 让 sizedBoxAspect = frame
      // portrait: sizedBoxAspect = 1/sensorAspect = 0.75 → sensorAspect = 4/3（已在上面覆盖）
      // 这里改成手动指定 frameAspect 与 sizedBoxAspect 相等：
      // call 框架里 displayFrameAspect 是 0.75，所以让 sizedBoxAspect = 0.75 也走 else 分支
      // 简化：portrait + sensorAspect=4/3 已经在上面覆盖"无裁切"路径
      // landscape + sensorAspect=0.75 时 sizedBoxAspect = 0.75 = frameAspect → 无裁切，180° 翻转
      final result = mapTapToSensorFocusPoint(
        tapInDisplayFrame: const Offset(0.5, 0.5),
        sensorAspect: 0.75,
        displayFrameAspect: 0.75,
        isLandscape: true,
      );
      expect(result, const Offset(0.5, 0.5),
          reason: '180° 翻转 + 中心点 = 自身');
    });
  });
}