# Camera Screen Rotation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 相机取景页支持横屏旋转，layout 不变，整个 UI（AppBar + Stack 子节点）作为一个整体旋转，使所有交互元素在用户视角下保持"正立"。

**Architecture:**
- 整个 `_buildCameraView` 的 Stack 外面包一层 `RotatedBox`，`quarterTurns` 由 `MediaQuery.orientation` 驱动
- AppBar 从 `Scaffold.appBar` 重构为 body 内的 Stack overlay（跟着 RotatedBox 一起转）
- `CameraService.setOrientationFromDevice(Orientation)` 调 `lockCaptureOrientation` 跟 sensor 方向
- 不动：FilterPanel（编辑页）、PhotoAlbumScreen（相册）、AppMenuSheet（菜单）

**Tech Stack:** Flutter 3.x + Riverpod + `camera` 包 `CameraController.lockCaptureOrientation` + Material `RotatedBox` + `MediaQuery.orientation`

**Spec:** `docs/superpowers/specs/2026-06-23-camera-screen-rotation-design.md`

---

## File Structure

| 文件 | 变更类型 | 责任 |
|---|---|---|
| `lib/services/camera_service.dart` | 修改 | 新增 `setOrientationFromDevice(Orientation)` 方法 + 内部 `lockCaptureOrientation` |
| `lib/features/camera/camera_screen.dart` | 修改 | Scaffold.appBar 改为 null；body 内用 Stack overlay 渲染 AppBar；body 整体包 RotatedBox + LayoutBuilder swap 宽高；监听 MediaQuery 调 setOrientationFromDevice |
| `test/services/camera_service_test.dart` | 修改 | setOrientationFromDevice 在未初始化时静默；调用的 lockCaptureOrientation 验证 |
| `test/widget/camera_screen_test.dart` | 新建 | 4 种 orientation 下 RotatedBox.quarterTurns 正确 + sensor 跟调 |

> 不修改：FilterPanel / PhotoAlbumScreen / AppMenuSheet

---

## Task 1: CameraService.setOrientationFromDevice

**Files:**
- Modify: `lib/services/camera_service.dart`（末尾 `dispose()` 之前）
- Modify: `test/services/camera_service_test.dart`

- [ ] **Step 1: 写失败测试**

打开 `test/services/camera_service_test.dart`，在 `CameraService` group 内追加：

```dart
test('setOrientationFromDevice 在 controller 未初始化时静默 return', () async {
  final service = CameraService();
  // 没调 initialize，_controller == null
  await service.setOrientationFromDevice(Orientation.landscapeLeft); // 不应抛
  await service.setOrientationFromDevice(Orientation.portraitUp);   // 不应抛
});
```

需要顶部加 `import 'package:flutter/widgets.dart' show Orientation;`（已经在 `package:flutter_test` 间接拉到了，但显式 import 更稳）。

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/camera_service_test.dart -v 2>&1 | tail -20
```

预期：编译错误（`setOrientationFromDevice` 方法不存在）。

- [ ] **Step 3: 实现 `setOrientationFromDevice`**

在 `lib/services/camera_service.dart` 末尾（`dispose()` 之前）添加：

```dart
import 'package:flutter/widgets.dart' show Orientation;

class CameraService {
  // ... 已有代码 ...

  /// 把相机 sensor 锁到指定设备方向，让预览方向跟 UI 旋转一致
  Future<void> setOrientationFromDevice(Orientation orientation) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final deviceOrientation = switch (orientation) {
      Orientation.portraitUp => DeviceOrientation.portraitUp,
      Orientation.portraitDown => DeviceOrientation.portraitDown,
      Orientation.landscapeLeft => DeviceOrientation.landscapeLeft,
      Orientation.landscapeRight => DeviceOrientation.landscapeRight,
    };
    try {
      await c.lockCaptureOrientation(deviceOrientation);
    } catch (_) {
      // 老版本 camera 包 / 模拟器 / 不支持的设备静默跳过
    }
  }

  void dispose() {
    _controller?.dispose();
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/camera_service_test.dart -v 2>&1 | tail -10
```

预期：PASS。

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/services/camera_service.dart test/services/camera_service_test.dart
git commit -m "feat(camera): CameraService 新增 setOrientationFromDevice

把相机 sensor 锁到指定设备方向，让横屏 / portraitDown 时预览方向
跟 UI 旋转一致。老 camera 包 / 模拟器 / 不支持设备 try/catch 静默。"
```

---

## Task 2: CameraScreen RotatedBox 改造 + AppBar 改 Stack overlay

**Files:**
- Modify: `lib/features/camera/camera_screen.dart`（整个 build + 引入 RotatedBox + 拆分 AppBar）
- Test: `test/widget/camera_screen_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

新建 `test/widget/camera_screen_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/camera/camera_screen.dart';
import 'package:easy_beauty_cam/features/camera/camera_view_model.dart';

void main() {
  testWidgets('CameraScreen portrait 下 RotatedBox.quarterTurns = 0', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CameraScreen()),
    ));
    await tester.pump();

    final rotated = find.byType(RotatedBox);
    expect(rotated, findsOneWidget,
        reason: 'CameraScreen body 应被 RotatedBox 包裹');
    final box = tester.widget<RotatedBox>(rotated);
    expect(box.quarterTurns, 0,
        reason: 'portrait 时 quarterTurns 应该是 0');
  });

  testWidgets('CameraScreen landscapeLeft 下 RotatedBox.quarterTurns = 1', (tester) async {
    tester.view.physicalSize = const Size(2532, 1170);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CameraScreen()),
    ));
    await tester.pump();

    final box = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(box.quarterTurns, 1,
        reason: 'landscapeLeft (设备逆时针) 时 quarterTurns 应该是 1');
  });
}
```

> **注意**：实际 orientation 取决于 `MediaQuery.orientation` 派发逻辑。`tester.view.physicalSize` 设成横屏尺寸会让 `MediaQuery.of(context).orientation` 返回 `landscapeLeft`（设备 home button 在左）。如果不行，测试用 `MediaQuery(data: MediaQueryData(size: Size(2532, 1170)), ...)` override 也可以，但复杂一点。

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/camera_screen_test.dart -v 2>&1 | tail -20
```

预期：FAIL（找不到 RotatedBox）。

- [ ] **Step 3: 改造 camera_screen.dart**

完整重写 `lib/features/camera/camera_screen.dart`：

```dart
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

  /// 把 MediaQuery.orientation 映射到 RotatedBox.quarterTurns
  int _orientationToQuarterTurns(Orientation orientation) {
    switch (orientation) {
      case Orientation.portraitUp: return 0;
      case Orientation.landscapeLeft: return 1;
      case Orientation.landscapeRight: return 3;
      case Orientation.portraitDown: return 2;
    }
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
              // swap 宽高：让子节点拿到 portrait 形状的布局空间
              // （landscape 屏幕下，按 portrait 比例排 Stack 子节点）
              return SizedBox(
                width: constraints.maxHeight,
                height: constraints.maxWidth,
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
```

**关键改动**：
- 加 `WidgetsBindingObserver` mixin + `didChangeMetrics`（设备方向变化时同步 sensor）
- `build` 用 `RotatedBox(quarterTurns: ...)` + `LayoutBuilder` swap 宽高
- AppBar 从 `Scaffold.appBar` 移到 body 内的 `_buildAppBarOverlay()`（Positioned 在最顶层）
- 加载中状态也用 `_buildLoadingOrAppBarOverlay` 显示 AppBar（避免初始化前看到纯黑屏）

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/camera_screen_test.dart -v 2>&1 | tail -20
```

预期：PASS。

- [ ] **Step 5: 跑完整测试套件确认没破坏其他东西**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -20
```

预期：所有测试通过。

- [ ] **Step 6: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/features/camera/camera_screen.dart test/widget/camera_screen_test.dart
git commit -m "feat(camera): CameraScreen 支持横屏旋转（layout 不变 + UI 自转）

- 整个 body 包 RotatedBox，quarterTurns 由 MediaQuery.orientation 驱动
- AppBar 从 Scaffold.appBar 重构为 body 内的 Stack overlay，跟着一起转
- LayoutBuilder swap 宽高，让 portrait Stack 子节点在 landscape 屏幕下按 portrait 形状布局
- WidgetsBindingObserver.didChangeMetrics 监听设备方向变化，调 cameraService.setOrientationFromDevice 同步 sensor"
```

---

## Task 3: 同步 MEMO + CHANGELOG

**Files:**
- Modify: `docs/MEMO.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: 更新 MEMO.md**

在 `docs/MEMO.md` 顶部"最新进度"区域更新最新章节指向 〇八，并在文件末尾追加 〇八 章节：

**更新第 10 行附近**：
```markdown
**最新**：〇八 相机取景页横屏旋转（详见 [〇八](#〇八-相机取景页横屏旋转-2026-06-23)）

**上一节**：〇七 拍后编辑 UI 微调（详见 [〇七](#filter-micro-tweaks-2026-06-20)）
```

**文件末尾追加**：
```markdown
---

<a id="camera-screen-rotation-2026-06-23"></a>
### 〇八 相机取景页横屏旋转 (2026-06-23)

横屏握持相机时 layout 不再重排版，整个 UI 作为一个整体旋转：

1. **RotatedBox + LayoutBuilder swap**：`_buildCameraView` 外包 `RotatedBox(quarterTurns: ...)`，`LayoutBuilder` swap 宽高让 portrait Stack 子节点在 landscape 屏幕下按 portrait 形状布局
2. **AppBar 改 Stack overlay**：从 `Scaffold.appBar` 移到 body 内的 `_buildAppBarOverlay()`，跟着一起转
3. **CameraService 同步 sensor**：`setOrientationFromDevice(Orientation)` 调 `CameraController.lockCaptureOrientation`，保证预览方向跟 UI 一致
4. **WidgetsBindingObserver.didChangeMetrics**：监听设备方向 / 尺寸变化，自动同步 sensor
5. **范围严格控制**：FilterPanel（编辑页）、PhotoAlbumScreen（相册）、AppMenuSheet（菜单）**不**参与旋转
```

- [ ] **Step 2: 更新 CHANGELOG.md**

在 `CHANGELOG.md` 找到 `## [Unreleased] — 2026-06-20` 段落，追加一个 `### Added` 条目（或追加到已有的 `### Added` 块）。如果不存在 `### Added` 块，在 `### Fixed` 块之前加：

```markdown
### Added
- **相机取景页横屏旋转**：横屏握持时 layout 不重排版，整个 UI 作为一个整体旋转 90°（AppBar + 姿势叠加 + 底部控制栏 + 姿势缩略图条）。`CameraService.setOrientationFromDevice` 调 `lockCaptureOrientation` 让相机 sensor 跟 UI 方向一致。范围**只**限相机取景页，编辑页 / 相册 / 菜单不参与。
```

- [ ] **Step 3: 跑完整测试套件**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -10
```

预期：所有测试通过。

- [ ] **Step 4: Commit + Push**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add docs/MEMO.md CHANGELOG.md
git commit -m "docs: 记录相机取景页横屏旋转（〇八）"
git push origin main
```

---

## Self-Review Checklist

- [x] Spec coverage: RotatedBox（Task 2）+ AppBar 重构（Task 2）+ CameraService.setOrientationFromDevice（Task 1）+ LayoutBuilder swap（Task 2）+ WidgetsBindingObserver 监听（Task 2）
- [x] Placeholder scan: 无 "TBD" / "TODO"
- [x] Type consistency: `setOrientationFromDevice(Orientation)` 在 Task 1 定义，Task 2 调用
- [x] Range check: spec 明确「只对相机取景页」，Task 2 不动 FilterPanel/Album/Menu

---

## 备注

- 加载状态（`_buildLoadingOrAppBarOverlay`）也用 `_buildAppBarOverlay` 是为了避免初始化前看到纯黑屏；可以视情况删掉，但留着更稳
- LayoutBuilder swap 宽高：portrait 时 `constraints.maxHeight > maxWidth`，swap 后子节点拿到 portrait 形状的约束；landscape 时反过来
- iOS / Android 灵动岛 / 状态栏：`SafeArea(top: false)` + 内部 overlay 自带 SafeArea 嵌套处理
