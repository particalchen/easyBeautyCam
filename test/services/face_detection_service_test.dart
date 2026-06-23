import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/services/face_detection_service.dart';

void main() {
  group('FaceDetectionService 缓存', () {
    test('同一 imagePath 连续 detect 只调底层 1 次', () async {
      int callCount = 0;
      final svc = FaceDetectionService(
        detectFn: (path, bytes) async {
          callCount++;
          return const <FaceContours>[];
        },
      );

      await svc.detect('/photo/a.jpg');
      await svc.detect('/photo/a.jpg');
      await svc.detect('/photo/a.jpg');

      expect(callCount, 1, reason: '第二次起应命中缓存');
    });

    test('不同 imagePath 各自缓存', () async {
      int callCount = 0;
      final svc = FaceDetectionService(
        detectFn: (path, bytes) async {
          callCount++;
          return const <FaceContours>[];
        },
      );

      await svc.detect('/photo/a.jpg');
      await svc.detect('/photo/b.jpg');
      await svc.detect('/photo/a.jpg'); // 命中

      expect(callCount, 2, reason: 'a 一次 + b 一次 = 2');
    });

    test('clearCache 后下次 detect 重新走底层', () async {
      int callCount = 0;
      final svc = FaceDetectionService(
        detectFn: (path, bytes) async {
          callCount++;
          return const <FaceContours>[];
        },
      );

      await svc.detect('/photo/a.jpg');
      svc.clearCache();
      await svc.detect('/photo/a.jpg');

      expect(callCount, 2, reason: '清缓存后应当重新调用');
    });

    test('底层抛异常时向上抛（不静默吞）', () async {
      final svc = FaceDetectionService(
        detectFn: (path, bytes) async {
          throw Exception('ml kit native missing');
        },
      );

      expect(
        () => svc.detect('/photo/a.jpg'),
        throwsA(isA<Exception>()),
        reason: '失败应向上抛，让 ViewModel 决定降级',
      );
    });
  });
}