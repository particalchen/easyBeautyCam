import 'dart:ui' show Offset;

import 'package:camera/camera.dart';

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

  void dispose() {
    _controller?.dispose();
  }
}