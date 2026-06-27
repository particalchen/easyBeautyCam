import 'dart:ui' show Offset;

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
  /// 最近一次点 pill 选中的焦段值；用户改用双指 pinch 缩放后会被清空。
  /// null 表示当前 zoom 不是通过 pill 选中的（pinch / 初始 / 切换相机后）。
  final double? lastSelectedPillZoom;

  const CameraViewModelState({
    this.isInitialized = false,
    this.cameraIndex = 0,
    this.currentZoom = 1.0,
    this.lastSelectedPillZoom,
  });

  CameraViewModelState copyWith({
    bool? isInitialized,
    int? cameraIndex,
    double? currentZoom,
    double? lastSelectedPillZoom,
    bool clearLastSelectedPillZoom = false,
  }) {
    return CameraViewModelState(
      isInitialized: isInitialized ?? this.isInitialized,
      cameraIndex: cameraIndex ?? this.cameraIndex,
      currentZoom: currentZoom ?? this.currentZoom,
      lastSelectedPillZoom: clearLastSelectedPillZoom
          ? null
          : (lastSelectedPillZoom ?? this.lastSelectedPillZoom),
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

  /// 设置变焦
  ///
  /// [fromPill] true 表示用户点了焦段 pill —— 把这次的值记到 [lastSelectedPillZoom]，
  /// pill 会高亮；false 表示用户用双指 pinch 缩放或初始 zoom —— 清空 [lastSelectedPillZoom]，
  /// pill 取消高亮（即使用户缩放后刚好等于某个 pill 值）。
  Future<void> setZoom(double zoom, {bool fromPill = false}) async {
    await _cameraService.setZoom(zoom);
    state = state.copyWith(
      currentZoom: zoom,
      lastSelectedPillZoom: fromPill ? zoom : null,
      clearLastSelectedPillZoom: !fromPill,
    );
  }

  Future<void> switchCamera(int index) async {
    await _cameraService.switchCamera(index);
    state = state.copyWith(cameraIndex: index);
  }

  Future<String?> takePicture() async {
    final file = await _cameraService.takePicture();
    return file?.path;
  }

  /// 在归一化坐标 ([0,1]) 处设置对焦点 + 曝光点
  Future<void> focusAndExposeAt(Offset normalizedPoint) async {
    await _cameraService.focusAndExposeAt(normalizedPoint);
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}