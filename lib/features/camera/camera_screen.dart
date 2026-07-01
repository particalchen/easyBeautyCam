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
import '../../services/camera_service.dart';
import 'widgets/pose_overlay.dart';
import 'widgets/pose_long_press_preview.dart';
import 'widgets/app_circle_icon_button.dart';
import 'widgets/app_menu_sheet.dart';
import 'widgets/camera_controls.dart';
import 'widgets/zoom_pill_bar.dart';
import '../filter/filter_view_model.dart';
import '../filter/filter_panel.dart';

/// 相机主屏幕（横屏自动旋转，layout 不变）
///
/// 布局（横屏时整体旋转，layout 仍是 portrait 结构）：
/// 1. 顶部 AppBar
/// 2. 取景区（Expanded）—— CameraPreview + 姿势轮廓 + 焦段 pill 浮在 preview 底部
/// 3. 取景区与 PoseStrip 之间的 16pt 空隙
/// 4. PoseStrip 横向缩略图（前置相机隐藏）
/// 5. 12pt 空隙
/// 6. 控制栏（快门 + 相机切换）
/// 7. SafeArea(bottom) —— 留出 home indicator
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
      // AppBar 改为 null；自己在 body 内渲染，跟着 RotatedBox 转
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
                    : _buildLoadingState(l10n),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 加载中：居中进度条 + 顶部 AppBar
  Widget _buildLoadingState(AppLocalizations l10n) {
    return Column(
      children: [
        _buildAppBar(l10n),
        const Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }

  /// AppBar 本身（不带 Positioned 包装）
  Widget _buildAppBar(AppLocalizations l10n) {
    return Container(
      color: AppColors.scrimLight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 标题居中
            Text(
              l10n.appTitle,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 左：菜单按钮
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.menu, size: 24),
                color: AppColors.onPrimary,
                tooltip: l10n.cameraMenu,
                onPressed: _openMenu,
              ),
            ),
            // 右：相册按钮（无描边 + 靠右）
            Align(
              alignment: Alignment.centerRight,
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () => context.push('/album'),
                size: 36,
                iconSize: 20,
                bordered: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 主视图：Column + Expanded 结构
  ///
  /// 自上而下：
  /// 1. AppBar（52pt）
  /// 2. 取景区（Expanded）—— Stack[preview + 焦段 pill 浮在底部 + flash]
  /// 3. SizedBox 16pt —— preview 与 PoseStrip 之间的安全空隙
  /// 4. CameraControls（PoseStrip + 12pt gap + 快门+切换）—— 用 SafeArea 留 home indicator
  Widget _buildCameraView(CameraViewModelState state, CameraViewModel notifier, AppLocalizations l10n) {
    final cameraService = ref.watch(cameraServiceProvider);
    final controller = cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final minZoom = cameraService.minZoomLevel;
    final maxZoom = cameraService.maxZoomLevel;

    return Column(
      children: [
        // 1. AppBar
        _buildAppBar(l10n),
        // 2. 取景区
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 3:4 preview，居中在 Expanded 区域
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRect(
                      child: _buildPreviewFrame(
                          controller, state, notifier, cameraService),
                    ),
                  ),
                ),
              ),
              // 焦段 pill 浮层 —— 压在 preview 底部边缘
              // bottom: 8 让 pill bar 距离 Expanded 底部 8pt（视觉上紧贴 preview 底部）
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: ZoomPillBar(
                  cameraIndex: state.cameraIndex,
                  minZoom: minZoom,
                  maxZoom: maxZoom,
                  lastSelectedPillZoom: state.lastSelectedPillZoom,
                  onSelect: (zoom) => notifier.setZoom(zoom, fromPill: true),
                ),
              ),
              // 拍照闪光
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
            ],
          ),
        ),
        // 3. preview 底部与 PoseStrip 之间的 16pt 空隙
        //    （pill bar 距 preview 底部 8pt + 8pt 视觉外距 + PoseStrip 自身 80pt）
        const SizedBox(height: 16),
        // 4. 相机控制栏（PoseStrip + 快门 + 切换）；SafeArea 留 home indicator
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: CameraControls(
              cameraIndex: state.cameraIndex,
              showPoseStrip: state.cameraIndex != 1,
              onCameraSwitch: (index) => notifier.switchCamera(index),
              onCapture: () => _capture(notifier),
            ),
          ),
        ),
      ],
    );
  }

  /// 3:4 预览框内部：sensor cover 填满 + 对焦 + pose 叠加
  ///
  /// iOS 的 camera plugin 报 previewSize 用的是**原始 sensor 方向**（landscape 1920×1080），
  /// 但 texture 实际内容已经被 `connection.videoOrientation` 旋到**显示方向**（portrait 1080×1920）。
  /// 所以 portrait 设备下要倒过来用 1/aspectRatio，否则 SizedBox 比例对不上 → texture 被拉变形。
  Widget _buildPreviewFrame(
    CameraController controller,
    CameraViewModelState state,
    CameraViewModel notifier,
    CameraService cameraService,
  ) {
    final previewSize = controller.value.previewSize;
    final rawAspect = previewSize != null && previewSize.height > 0
        ? previewSize.width.toDouble() / previewSize.height.toDouble()
        : 4 / 3; // iPhone 后置 sensor 默认 4:3 (landscape)
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final displayAspect = isLandscape ? rawAspect : (1 / rawAspect);
    return GestureDetector(
      onScaleStart: (details) {
        _gestureBaseZoom = state.currentZoom;
      },
      onScaleUpdate: (details) {
        final zoom = (_gestureBaseZoom * details.scale)
            .clamp(cameraService.minZoomLevel, cameraService.maxZoomLevel);
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
        // frame 点击坐标换算成 sensor 坐标（AVFoundation 的 focusPointOfInterest
        // 用的是 sensor 空间，不是显示空间；详见 CameraService.mapTapToSensorFocusPoint）
        final sensorPoint = mapTapToSensorFocusPoint(
          tapInDisplayFrame: point,
          sensorAspect: rawAspect,
          displayFrameAspect: 3 / 4, // AspectRatio 写在逻辑层，永远 3/4
          isLandscape: isLandscape,
        );
        notifier.focusAndExposeAt(sensorPoint);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 用 SizedBox 给明确的有限尺寸（保持显示方向的宽高比），FittedBox cover 填满 3:4 框
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: displayAspect,
                height: 1,
                child: CameraPreview(controller),
              ),
            ),
          ),
          if (_focusPoint != null) _buildFocusIndicator(),
          const PoseOverlay(),
          // 长按 PoseThumbStrip 缩略图时的半透明 pose 原图覆盖层
          const PoseLongPressPreview(),
        ],
      ),
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

    try {
      debugPrint('[CAPTURE] start, calling takePicture');
      final path = await notifier.takePicture();
      debugPrint('[CAPTURE] takePicture returned: $path');

      if (path == null) {
        _showCaptureError('拍照失败：未获取到图片');
        return;
      }
      if (!mounted) {
        debugPrint('[CAPTURE] widget disposed before push, abort');
        return;
      }

      ref.read(filterViewModelProvider.notifier).setImage(path);
      final cameraService = ref.read(cameraServiceProvider);
      unawaited(cameraService.pausePreview());

      debugPrint('[CAPTURE] pushing FilterPanel');
      final savedPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const FilterPanel(),
          fullscreenDialog: true,
        ),
      );
      debugPrint('[CAPTURE] FilterPanel returned: $savedPath');

      if (mounted) {
        unawaited(cameraService.resumePreview());
      }
    } catch (e, stack) {
      debugPrint('[CAPTURE] ERROR: $e\n$stack');
      _showCaptureError('拍照失败：$e');
    }
  }

  void _showCaptureError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
