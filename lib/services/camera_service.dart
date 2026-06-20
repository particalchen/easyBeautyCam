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
    // 补偿 iOS 上预览/拍照曝光不一致（真机报过「环境光够但照片偏暗」）
    // +1.0 是经验值；setExposureOffset 在不支持的设备上会抛，需 try 兜底
    await _applyExposureOffset(1.0);
  }

  CameraController? get controller => _controller;

  Future<void> setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setZoomLevel(zoom);
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
    await _applyExposureOffset(1.0);
  }

  /// 软应用曝光补偿；老设备/模拟器可能抛 CameraException，静默吞掉
  Future<void> _applyExposureOffset(double offset) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setExposureOffset(offset);
    } catch (_) {
      // 不支持曝光补偿的设备（模拟器/部分 Android）直接跳过
    }
  }

  Future<XFile?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    return await _controller!.takePicture();
  }

  void dispose() {
    _controller?.dispose();
  }
}