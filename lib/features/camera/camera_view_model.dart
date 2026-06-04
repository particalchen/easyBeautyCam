import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/camera_service.dart';

final cameraServiceProvider = Provider<CameraService>((ref) => CameraService());

final cameraViewModelProvider = StateNotifierProvider<CameraViewModel, CameraViewModelState>((ref) {
  return CameraViewModel(ref.watch(cameraServiceProvider));
});

class CameraViewModelState {
  final bool isInitialized;
  final int cameraIndex;
  final double currentZoom;

  const CameraViewModelState({
    this.isInitialized = false,
    this.cameraIndex = 0,
    this.currentZoom = 1.0,
  });

  CameraViewModelState copyWith({
    bool? isInitialized,
    int? cameraIndex,
    double? currentZoom,
  }) {
    return CameraViewModelState(
      isInitialized: isInitialized ?? this.isInitialized,
      cameraIndex: cameraIndex ?? this.cameraIndex,
      currentZoom: currentZoom ?? this.currentZoom,
    );
  }
}

class CameraViewModel extends StateNotifier<CameraViewModelState> {
  final CameraService _cameraService;

  CameraViewModel(this._cameraService) : super(const CameraViewModelState());

  Future<void> initialize() async {
    await _cameraService.initialize();
    state = state.copyWith(isInitialized: true);
  }

  Future<void> setZoom(double zoom) async {
    await _cameraService.setZoom(zoom);
    state = state.copyWith(currentZoom: zoom);
  }

  Future<void> switchCamera(int index) async {
    await _cameraService.switchCamera(index);
    state = state.copyWith(cameraIndex: index);
  }

  Future<String?> takePicture() async {
    final file = await _cameraService.takePicture();
    return file?.path;
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}