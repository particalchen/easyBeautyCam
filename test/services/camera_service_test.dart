import 'package:flutter/widgets.dart' show Orientation;
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

    test('setOrientationFromDevice 在 controller 未初始化时静默 return', () async {
      final service = CameraService();
      // 没调 initialize，_controller == null
      await service.setOrientationFromDevice(Orientation.portrait);   // 不应抛
      await service.setOrientationFromDevice(Orientation.landscape); // 不应抛
    });
  });
}