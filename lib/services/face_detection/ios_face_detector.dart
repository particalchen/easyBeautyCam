import 'package:flutter/services.dart';

import '../face_detection_service.dart';

/// iOS 平台的人脸检测实现（包装 Apple Vision framework）
///
/// 通过 MethodChannel 调 Swift 端 `FaceDetectionPlugin`。
/// 失败时抛异常向上传，由 `FaceDetectionService` 决定是否降级到 mask=null。
///
/// 签名匹配 [FaceDetectFn]：positional 参数（imagePath, bytes）。
class IOSFaceDetector {
  static const _channel = MethodChannel('easy_beauty_cam/face_detection');

  Future<List<FaceContours>> detect(String imagePath, Uint8List? bytes) async {
    final dynamic raw = await _channel.invokeMethod('detect', {
      'imagePath': imagePath,
    });
    if (raw is! List) {
      throw StateError('iOS FaceDetection returned non-list: ${raw.runtimeType}');
    }
    return raw.map((face) => _convertFace(face as Map)).toList();
  }

  FaceContours _convertFace(Map<dynamic, dynamic> json) {
    Offset ptFromPoint(Map<dynamic, dynamic> p) =>
        Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble());

    List<Offset>? parsePoly(dynamic raw) {
      if (raw is! List || raw.isEmpty) return null;
      return raw.map((p) => ptFromPoint(p as Map)).toList();
    }

    return FaceContours(
      face: parsePoly(json['face']) ?? const [],
      leftEye: parsePoly(json['leftEye']),
      rightEye: parsePoly(json['rightEye']),
      // iOS Vision 把上下唇合并成 outerLips + innerLips；ML Kit 是 lipUpper + lipLower。
      // 这里用 outerLips 同时填两个字段（mask builder 用 OR 逻辑）
      lipUpper: parsePoly(json['outerLips']),
      lipLower: parsePoly(json['innerLips']),
    );
  }
}