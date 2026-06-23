import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// 一个人脸的轮廓点集（不依赖 ML Kit 的 Face 类）
///
/// - [face]    整脸轮廓（用于 fillPolygon 主区域）
/// - [leftEye] / [rightEye] / [lipUpper] / [lipLower] 用于 mask 内部"打洞"
///   —— 这些区域不磨皮，保留眼睛 / 嘴唇细节
class FaceContours {
  final List<Offset> face;
  final List<Offset>? leftEye;
  final List<Offset>? rightEye;
  final List<Offset>? lipUpper;
  final List<Offset>? lipLower;

  const FaceContours({
    required this.face,
    this.leftEye,
    this.rightEye,
    this.lipUpper,
    this.lipLower,
  });
}

/// 底层人脸检测函数签名：path + bytes → FaceContours 列表
///
/// 生产实现是 ML Kit；测试里直接传 fake。
typedef FaceDetectFn = Future<List<FaceContours>> Function(
  String imagePath,
  Uint8List? bytes,
);

/// ML Kit 人脸检测服务（静态图）
///
/// 缓存策略：key = imagePath（每张照片唯一）；ViewModel 切照片时调
/// [clearCache] 释放内存。缓存上限不做 LRU（照片编辑场景，10 张以内够用）。
///
/// 构造方式：
/// - `FaceDetectionService()` —— 生产模式，自带 ML Kit detector
/// - `FaceDetectionService(detectFn: ...)` —— 测试模式，注入 fake
class FaceDetectionService {
  FaceDetectFn? _detect;
  final Map<String, List<FaceContours>> _cache = {};
  FaceDetector? _defaultDetector;

  FaceDetectionService({FaceDetectFn? detectFn}) {
    if (detectFn != null) {
      _detect = detectFn;
    } else {
      _initDefaultDetector();
    }
  }

  void _initDefaultDetector() {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: false,
        performanceMode: FaceDetectorMode.fast,
        enableClassification: false,
        enableTracking: false,
        minFaceSize: 0.15,
      ),
    );
    _defaultDetector = detector;
    _detect = _makeMlKitDetector(detector);
  }

  Future<List<FaceContours>> detect(String imagePath, {Uint8List? bytes}) async {
    final cached = _cache[imagePath];
    if (cached != null) return cached;
    final result = await _detect!(imagePath, bytes);
    _cache[imagePath] = result;
    return result;
  }

  void clearCache() => _cache.clear();

  /// 释放 ML Kit detector 资源（仅当用了默认 detector）
  void dispose() {
    _defaultDetector?.close();
    _defaultDetector = null;
  }

  // ---- 内部：ML Kit 默认 detector ----

  static FaceDetectFn _makeMlKitDetector(FaceDetector detector) {
    return (String path, Uint8List? bytes) async {
      final InputImage input;
      if (bytes != null) {
        input = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: const Size(1, 1),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: bytes.length,
          ),
        );
      } else {
        input = InputImage.fromFilePath(path);
      }
      final faces = await detector.processImage(input);
      return faces.map(_convert).toList();
    };
  }

  static FaceContours _convert(Face face) {
    Offset pt(Point<int> p) =>
        Offset(p.x.toDouble(), p.y.toDouble());
    final fc = face.contours;
    List<Offset>? get(FaceContourType t) =>
        fc[t]?.points.map(pt).toList();
    return FaceContours(
      face: fc[FaceContourType.face]?.points.map(pt).toList() ?? const [],
      leftEye: get(FaceContourType.leftEye),
      rightEye: get(FaceContourType.rightEye),
      // 上唇 = upperLipTop；下唇 = lowerLipBottom
      lipUpper: get(FaceContourType.upperLipTop),
      lipLower: get(FaceContourType.lowerLipBottom),
    );
  }
}