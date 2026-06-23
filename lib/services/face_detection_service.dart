import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'face_detection/ios_face_detector.dart';

/// 一个人脸的轮廓点集（不依赖任何平台 SDK）
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
/// 生产实现：iOS → Apple Vision（via `IOSFaceDetector`），Android → 空 stub（TODO）。
/// 测试里直接传 fake。
typedef FaceDetectFn = Future<List<FaceContours>> Function(
  String imagePath,
  Uint8List? bytes,
);

/// 人脸检测服务（静态图）
///
/// 缓存策略：key = imagePath（每张照片唯一）；ViewModel 切照片时调
/// [clearCache] 释放内存。缓存上限不做 LRU（照片编辑场景，10 张以内够用）。
///
/// 构造方式：
/// - `FaceDetectionService()` —— 生产模式，根据平台路由（iOS → Vision，Android → 空 stub）
/// - `FaceDetectionService(detectFn: ...)` —— 测试模式，注入 fake
class FaceDetectionService {
  final FaceDetectFn _detect;

  /// path → 缓存的脸轮廓
  final Map<String, List<FaceContours>> _cache = {};

  FaceDetectionService({FaceDetectFn? detectFn})
      : _detect = detectFn ?? _platformRouterDetector();

  Future<List<FaceContours>> detect(String imagePath, {Uint8List? bytes}) async {
    final cached = _cache[imagePath];
    if (cached != null) return cached;
    final result = await _detect(imagePath, bytes);
    _cache[imagePath] = result;
    return result;
  }

  void clearCache() => _cache.clear();

  /// 释放资源（当前实现没有 native handle 需关，留空兼容未来扩展）
  void dispose() {}

  // ---- 内部：平台路由 ----

  /// 默认 detector：根据平台路由
  ///
  /// - iOS → Apple Vision（MethodChannel → FaceDetectionPlugin.swift）
  /// - Android → 空 stub（返回 `const []`，触发「未检测到人脸」降级 UI）
  ///
  /// Android 端的人脸检测是 TODO：之前用 google_mlkit_face_detection 但其
  /// iOS pod 不发 arm64 simulator 切片，会让 iOS 26+ Apple Silicon sim 跑不起来。
  /// 删 ML Kit 后 iOS sim 通了；Android 端需要重写时建议用平台通道调 Android
  /// 原生 FaceDetector API 或新找一个不发 iOS pod 的纯 Android 库。
  static FaceDetectFn _platformRouterDetector() {
    if (Platform.isIOS) {
      final detector = IOSFaceDetector();
      return detector.detect;
    }
    return _androidStubDetector;
  }

  /// Android 临时 stub：返回空列表（= 永远检测不到人脸 → 美颜不生效 + UI 提示）
  static Future<List<FaceContours>> _androidStubDetector(
    String imagePath,
    Uint8List? bytes,
  ) async =>
      const [];
}