import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import 'camera_view_model.dart';
import 'widgets/pose_overlay.dart';
import 'widgets/pose_thumb_strip.dart';
import 'widgets/app_circle_icon_button.dart';
import 'widgets/app_menu_sheet.dart';
import 'widgets/camera_controls.dart';
import '../filter/filter_view_model.dart';
import '../filter/filter_panel.dart';

/// 相机主屏幕（横屏自动旋转，layout 不变）
///
/// 布局（横屏时整体旋转，layout 仍是 portrait Stack 结构）：
/// 1. 取景框（CameraPreview）—— 双指缩放 + 点击对焦曝光
/// 2. 姿势轮廓叠加（不跟随缩放，跟着 RotatedBox 一起转）
/// 3. 顶部 AppBar overlay（Stack 子节点，跟着转）
/// 4. 底部姿势缩略图条
/// 5. 底部相机控制栏
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _kPoseStripGap = 32;
  double _gestureBaseZoom = 1.0;
  late final AnimationController _flashController;
  late final Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flashAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 150,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 200,
      ),
    ]).animate(_flashController);
    Future.microtask(() => ref.read(cameraViewModelProvider.notifier).initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 设备方向 / 尺寸变化时同步相机 sensor
    _syncSensorOrientation();
  }

  void _syncSensorOrientation() {
    final orientation = MediaQuery.of(context).orientation;
    final cameraService = ref.read(cameraServiceProvider);
    unawaited(cameraService.setOrientationFromDevice(orientation));
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AppMenuSheet(
        onPoseLibrary: () { Navigator.of(sheetContext).pop(); },
        onSettings: () { Navigator.of(sheetContext).pop(); },
        onAbout: () { Navigator.of(sheetContext).pop(); },
      ),
    );
  }

  /// 把 2-value MediaQuery.orientation 映射到 RotatedBox.quarterTurns
  int _orientationToQuarterTurns(Orientation orientation) {
    // portrait → 0（无视觉变化）
    // landscape → 1（90° 顺时针，匹配 sensor landscapeLeft）
    return switch (orientation) {
      Orientation.portrait => 0,
      Orientation.landscape => 1,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orientation = MediaQuery.of(context).orientation;
    final quarterTurns = _orientationToQuarterTurns(orientation);
    final cameraState = ref.watch(cameraViewModelProvider);
    final cameraNotifier = ref.read(cameraViewModelProvider.notifier);

    // 同步 sensor（initState 后第一次 build 也调一次）
    _syncSensorOrientation();

    return Scaffold(
      backgroundColor: Colors.black,
      // AppBar 改为 null；自己在 body 内 Stack overlay 渲染，跟着 RotatedBox 转
      body: SafeArea(
        bottom: false,
        child: RotatedBox(
          quarterTurns: quarterTurns,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // RotatedBox 内部已经 swap 了 constraints：
              //   landscape 时 LayoutBuilder 看到的是 portrait 形状 (宽 < 高)
              //   portrait 时 LayoutBuilder 看到的是 portrait 形状 (宽 < 高)
              // 所以这里直接用 constraints 即可，不要再手动 swap，否则会变成横屏形状。
              return SizedBox(
                key: const ValueKey('cameraContentSizedBox'),
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: cameraState.isInitialized
                    ? _buildCameraView(cameraState, cameraNotifier, l10n)
                    : _buildLoadingOrAppBarOverlay(l10n),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrAppBarOverlay(AppLocalizations l10n) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        // 加载中也显示 AppBar overlay
        _buildAppBarOverlay(l10n),
      ],
    );
  }

  Widget _buildAppBarOverlay(AppLocalizations l10n) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          color: AppColors.scrimLight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, size: 24),
                color: AppColors.onPrimary,
                tooltip: l10n.cameraMenu,
                onPressed: _openMenu,
              ),
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
        ),
      ),
    );
  }

  Widget _buildCameraView(CameraViewModelState state, CameraViewModel notifier, AppLocalizations l10n) {
    final cameraService = ref.watch(cameraServiceProvider);
    final controller = cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final minZoom = cameraService.minZoomLevel;
    final maxZoom = cameraService.maxZoomLevel;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onScaleStart: (details) {
            _gestureBaseZoom = state.currentZoom;
          },
          onScaleUpdate: (details) {
            final zoom = (_gestureBaseZoom * details.scale).clamp(minZoom, maxZoom);
            notifier.setZoom(zoom);
          },
          onTapUp: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(details.globalPosition);
            final size = box.size;
            final point = Offset(
              (local.dx / size.width).clamp(0.0, 1.0),
              (local.dy / size.height).clamp(0.0, 1.0),
            );
            _showFocusIndicator(point, size);
            notifier.focusAndExposeAt(point);
          },
          child: Center(child: CameraPreview(controller)),
        ),
        if (_focusPoint != null) _buildFocusIndicator(),
        const PoseOverlay(),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.thumbHotzone + AppSpacing.shutterSize + _kPoseStripGap,
          child: Visibility(
            visible: state.cameraIndex != 1,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: const PoseThumbStrip(),
          ),
        ),
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
                minZoom: minZoom,
                maxZoom: maxZoom,
                onCameraSwitch: (index) => notifier.switchCamera(index),
                onZoomSelect: (zoom) => notifier.setZoom(zoom),
                onCapture: () => _capture(notifier),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, _) {
              final opacity = _flashAnimation.value;
              if (opacity <= 0) return const SizedBox.shrink();
              return Container(color: Colors.white.withValues(alpha: opacity));
            },
          ),
        ),
        // AppBar 浮在最顶层
        _buildAppBarOverlay(l10n),
      ],
    );
  }

  Offset? _focusPoint;
  Size? _focusSize;
  Timer? _focusTimer;

  void _showFocusIndicator(Offset normalizedPoint, Size widgetSize) {
    setState(() {
      _focusPoint = normalizedPoint;
      _focusSize = widgetSize;
    });
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  Widget _buildFocusIndicator() {
    final p = _focusPoint!;
    final size = _focusSize ?? MediaQuery.of(context).size;
    return Positioned(
      left: p.dx * size.width - 40,
      top: p.dy * size.height - 40,
      child: IgnorePointer(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Future<void> _capture(CameraViewModel notifier) async {
    _flashController.forward(from: 0);
    unawaited(SystemSound.play(SystemSoundType.click));

    final path = await notifier.takePicture();
    if (path != null && mounted) {
      ref.read(filterViewModelProvider.notifier).setImage(path);
      final cameraService = ref.read(cameraServiceProvider);
      unawaited(cameraService.pausePreview());

      final savedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const FilterPanel(),
          fullscreenDialog: true,
        ),
      );

      if (mounted) {
        unawaited(cameraService.resumePreview());
      }
    }
  }
}
