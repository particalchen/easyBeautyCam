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
  }

  Future<XFile?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    return await _controller!.takePicture();
  }

  void dispose() {
    _controller?.dispose();
  }
}