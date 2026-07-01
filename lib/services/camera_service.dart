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
      ResolutionPreset.max,
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
      ResolutionPreset.max,
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

/// 把取景框（AspectRatio frame）上的归一化点击坐标，换算成可以直接喂给
/// `setFocusPoint` / `setExposurePoint` 的坐标（**显示方向 / texture 坐标**）。
///
/// 为什么要换：iOS 的 `CameraPreview` 实际显示给用户的是经过裁切的取景框画面，
/// 不是 sensor 的完整画面。`FittedBox(BoxFit.cover)` 把 sensor 渲染进 AspectRatio
/// frame 时，sensor 比例（landscape 16/9 或 4/3）≠ frame 比例（portrait 3/4）
/// 时会上 / 下 或 左 / 右 裁掉一部分，**只有中间一段可见**。直接喂 frame 点击
/// 坐标给 `setFocusPoint` 会落到裁掉的那部分，焦点偏到边缘（iPhone 16 Pro
/// 上大约偏 10-15%）。
///
/// **不做 sensor 旋转反变换**：iOS `camera_avfoundation` plugin 内部已经用
/// `cgPoint(for:withOrientation:)` 做了这一步（`UIDevice.current.orientation`
/// = `.portrait` 时是 90° CCW 视觉旋转），传入的坐标是显示方向。我们再旋转一
/// 次就成了双重旋转，portrait 下焦点会从用户点击位置往右下偏（Y 偏差比 X 大）。
///
/// 参数：
/// - [tapInDisplayFrame]：frame 内的归一化点击坐标，0,0 = frame 左上，1,1 = 右下
/// - [sensorAspect]：`CameraController.value.previewSize` 的宽高比，**始终是横屏**
///   （iOS plugin 报的就是横屏方向）；如果拿不到就用 `4/3` 兜底
/// - [displayFrameAspect]：frame 的宽高比。当前 `CameraScreen` 用 `AspectRatio(3/4)`
///   在逻辑层永远是 portrait，**这里传逻辑层 aspect（始终 3/4）**——FittedBox 在逻辑层工作
/// - [isLandscape]：设备物理方向，决定 SizedBox aspect（横屏用 sensorAspect，竖屏用 1/sensorAspect）
///
/// 返回 SizedBox（= texture）归一化坐标，可直接喂 `setFocusPoint` / `setExposurePoint`。
Offset mapTapToSensorFocusPoint({
  required Offset tapInDisplayFrame,
  required double sensorAspect,
  required double displayFrameAspect,
  required bool isLandscape,
}) {
  // SizedBox 在显示方向上的比例。portrait 显示：sensor 横屏 → 1/sensorAspect；
  // landscape 显示：sensor 旋转 90° 后比例仍是横屏 → sensorAspect。
  final sizedBoxAspect =
      isLandscape ? sensorAspect : (1 / sensorAspect);

  // 反推 cover 裁切 → SizedBox（texture）内的归一化坐标
  final double sizedBoxX;
  final double sizedBoxY;
  if (displayFrameAspect >= sizedBoxAspect) {
    // frame 比 SizedBox 更"宽"（aspect 更大）→ cover 裁上下，宽度对齐
    final visibleHeightRatio = sizedBoxAspect / displayFrameAspect;
    final cropTop = (1 - visibleHeightRatio) / 2;
    sizedBoxX = tapInDisplayFrame.dx;
    sizedBoxY = cropTop + tapInDisplayFrame.dy * visibleHeightRatio;
  } else {
    // frame 比 SizedBox 更"窄"→ cover 裁左右，高度对齐
    final visibleWidthRatio = displayFrameAspect / sizedBoxAspect;
    final cropLeft = (1 - visibleWidthRatio) / 2;
    sizedBoxX = cropLeft + tapInDisplayFrame.dx * visibleWidthRatio;
    sizedBoxY = tapInDisplayFrame.dy;
  }

  return Offset(sizedBoxX, sizedBoxY);
}