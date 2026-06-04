import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_view_model.dart';
import 'widgets/pose_overlay.dart';
import 'widgets/pose_thumb_strip.dart';
import 'widgets/camera_controls.dart';
import '../filter/filter_view_model.dart';
import '../filter/filter_panel.dart';

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
        // 双指缩放手势层（姿势轮廓不跟随缩放）
        GestureDetector(
          onScaleUpdate: (details) {
            final zoom = (state.currentZoom * details.scale).clamp(1.0, 5.0);
            notifier.setZoom(zoom);
          },
          child: Center(child: CameraPreview(controller)),
        ),
        // 姿势轮廓叠加（不跟随缩放）
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
            onCapture: () async {
              final path = await notifier.takePicture();
              if (path != null && context.mounted) {
                ref.read(filterViewModelProvider.notifier).setImage(path);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const FilterPanel(),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}