import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import 'camera_view_model.dart';
import 'widgets/pose_overlay.dart';
import 'widgets/pose_thumb_strip.dart';
import 'widgets/app_circle_icon_button.dart';
import 'widgets/camera_controls.dart';
import '../filter/filter_view_model.dart';
import '../filter/filter_panel.dart';

/// 相机主屏幕
///
/// 布局（自底向上）：
/// 1. 取景框（CameraPreview）—— 占满 + 双指缩放手势
/// 2. 姿势轮廓叠加（不跟随缩放）
/// 3. 顶部 AppBar（菜单 / 标题 / 相册）—— 浮于取景框之上，避让刘海
/// 4. 底部姿势缩略图条
/// 5. 底部相机控制栏（相册/快门/变焦）
///
/// 安全区：
/// - 顶部 SafeArea + 灵动岛 适配由 `AppBar` 自动处理
/// - 底部 SafeArea 防止 home indicator 遮挡
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  /// 姿势缩略图条距底部控制栏的垂直间距
  static const double _kPoseStripGap = 32;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cameraViewModelProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cameraState = ref.watch(cameraViewModelProvider);
    final cameraNotifier = ref.read(cameraViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // AppBar 浮于取景框之上
      appBar: AppBar(
        backgroundColor: AppColors.scrimLight,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 24),
          tooltip: l10n.cameraMenu,
          onPressed: () {
            // TODO: 打开侧边菜单
          },
        ),
        title: Text(
          l10n.appTitle,
          style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 4),
            child: AppCircleIconButton(
              icon: Icons.photo_library_outlined,
              onPressed: () => context.push('/album'),
              size: 36,
              iconSize: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        bottom: false, // 底部控制栏会自己处理 home indicator
        child: cameraState.isInitialized
            ? _buildCameraView(cameraState, cameraNotifier)
            : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
    );
  }

  Widget _buildCameraView(CameraViewModelState state, CameraViewModel notifier) {
    final controller = ref.watch(cameraServiceProvider).controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1) 双指缩放手势层（姿势轮廓不跟随缩放）
        GestureDetector(
          onScaleUpdate: (details) {
            // TODO: 修复累计缩放 bug —— 当前是增量乘 base，应记录 baseZoom
            final zoom = (state.currentZoom * details.scale).clamp(1.0, 5.0);
            notifier.setZoom(zoom);
          },
          child: Center(child: CameraPreview(controller)),
        ),
        // 2) 姿势轮廓叠加（不跟随缩放）
        const PoseOverlay(),
        // 3) 底部姿势缩略图条（前置相机隐藏；避让控制栏 + home indicator）
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.thumbHotzone + AppSpacing.shutterSize + _kPoseStripGap, // 控制栏上方
          child: Visibility(
            visible: state.cameraIndex != 1,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: const PoseThumbStrip(),
          ),
        ),
        // 4) 底部相机控制栏
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: CameraControls(
                cameraIndex: state.cameraIndex,
                currentZoom: state.currentZoom,
                onCameraSwitch: (index) => notifier.switchCamera(index),
                onZoomSelect: (zoom) => notifier.setZoom(zoom),
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
          ),
        ),
      ],
    );
  }
}
