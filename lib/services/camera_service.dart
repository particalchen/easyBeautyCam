import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart' show Offset, Orientation;

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _controller = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    // 曝光走相机默认参数（+1.0 在某些机型上偏亮，已回退）
    await _queryZoomRange();
  }

  CameraController? get controller => _controller;

  /// 硬件支持的最小/最大变焦倍数；空表示未查询
  double? _minZoom;
  double? _maxZoom;

  /// UI 用：当前硬件支持的最小变焦
  double get minZoomLevel => _minZoom ?? 1.0;
  /// UI 用：当前硬件支持的最大变焦
  double get maxZoomLevel => _maxZoom ?? 5.0;

  Future<void> _queryZoomRange() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      _minZoom = await c.getMinZoomLevel();
      _maxZoom = await c.getMaxZoomLevel();
    } catch (_) {
      // 老版本 camera 包可能没这两个 API；保留默认 1.0 / 5.0
      _minZoom ??= 1.0;
      _maxZoom ??= 5.0;
    }
  }

  /// 把用户传入的 zoom 限制到硬件支持的范围
  double _clampToHardware(double zoom) {
    final lo = _minZoom ?? 1.0;
    final hi = _maxZoom ?? 5.0;
    return zoom.clamp(lo, hi);
  }

  Future<void> setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setZoomLevel(_clampToHardware(zoom));
  }

  Future<void> switchCamera(int index) async {
    if (index < 0 || index >= _cameras.length) return;
    _controller?.dispose();
    _controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    await _queryZoomRange();
  }

  Future<XFile?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    return await _controller!.takePicture();
  }

  /// 在归一化坐标 ([0,1]) 处设置对焦点 + 曝光点
  /// point = (x, y) ∈ [0,1]²，预览区域的相对位置
  Future<void> focusAndExposeAt(Offset point) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setFocusPoint(point);
      await c.setExposurePoint(point);
    } catch (_) {
      // 模拟器/不支持点对焦的设备静默跳过
    }
  }

  /// 暂停相机预览（CameraController 实例保留，停止后台采集）
  Future<void> pausePreview() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.pausePreview();
    } catch (_) {
      // 老版本 camera 包可能没这 API，静默跳过
    }
  }

  /// 恢复相机预览
  Future<void> resumePreview() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.resumePreview();
    } catch (_) {}
  }

  /// 把相机 sensor 锁到指定设备方向，让预览方向跟 UI 旋转一致
  ///
  /// 注意：2-value Orientation（portrait/landscape）足以覆盖本应用场景；
  /// portraitUp vs portraitDown 的细分在 spec 中不要求。
  Future<void> setOrientationFromDevice(Orientation orientation) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.lockCaptureOrientation(mapOrientationToDeviceOrientation(orientation));
    } catch (_) {
      // 老版本 camera 包 / 模拟器 / 不支持的设备静默跳过
    }
  }

  void dispose() {
    _controller?.dispose();
  }
}

/// 2-value Orientation → DeviceOrientation 映射
///
/// 测试用：纯函数，无副作用。`lockCaptureOrientation` 接受 4-value
/// `DeviceOrientation`，但本应用只区分 portrait/landscape，所以
/// 两种输入对应两个最常见的 `DeviceOrientation` 值。
@visibleForTesting
DeviceOrientation mapOrientationToDeviceOrientation(Orientation orientation) {
  return switch (orientation) {
    Orientation.portrait => DeviceOrientation.portraitUp,
    Orientation.landscape => DeviceOrientation.landscapeLeft,
  };
}