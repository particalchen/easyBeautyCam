import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_view_model.dart';
import 'widgets/pose_overlay.dart';
import 'widgets/pose_thumb_strip.dart';
import 'widgets/camera_controls.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cameraViewModelProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraViewModelProvider);
    final cameraNotifier = ref.read(cameraViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: cameraState.isInitialized
          ? _buildCameraView(cameraState, cameraNotifier)
          : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildCameraView(CameraViewModelState state, CameraViewModel notifier) {
    final controller = ref.watch(cameraServiceProvider).controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 相机画面
        Center(child: CameraPreview(controller)),
        // 姿势轮廓叠加
        const PoseOverlay(),
        // 底部姿势缩略图
        const Positioned(
          left: 0,
          right: 0,
          bottom: 120,
          child: PoseThumbStrip(),
        ),
        // 控制栏
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: CameraControls(
            cameraIndex: state.cameraIndex,
            onCameraSwitch: (index) => notifier.switchCamera(index),
            onCapture: () => notifier.takePicture(),
          ),
        ),
      ],
    );
  }
}