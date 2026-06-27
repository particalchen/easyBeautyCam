# 相机主屏 UI 重构 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) 或 superpowers:executing-plans 来逐任务执行。步骤用 checkbox (`- [ ]`) 跟踪。

**Goal:** 把 `CameraScreen` 改成 iOS 风格布局——焦段行上移、拍照按钮居中、相机切换按钮最右；修 AppBar 置灰；前置时焦段行只显示 1x；相机切换按钮和相册按钮视觉统一。

**Architecture:**
- 新增 `AppCircleIconButton` 可复用小组件，统一相机切换按钮和相册按钮的视觉风格（白边 + 半透黑底 + 线性图标）。
- `CameraControls` 焦段按钮的回调从 `onCameraSwitch(int)` 改为 `onZoomSelect(double)`，把"切相机"和"调焦段"两件事彻底解耦。
- `CameraScreen` AppBar 显式设 `foregroundColor: Colors.white` + 半透黑底，绕开 M3 主题的 `onSurfaceVariant` 灰色。
- 前置相机时焦段行只渲染 `1x`（写死常量），姿势缩略图条整行 `Visibility(visible: ...)` 隐藏。

**Tech Stack:** Flutter 3.x / Riverpod / `camera` plugin / `flutter_test`

---

## 文件结构

| 文件 | 状态 | 职责 |
|---|---|---|
| `lib/features/camera/widgets/app_circle_icon_button.dart` | 新增 | 通用圆环 icon 按钮（白边+半透黑底+线性图标），接受 `icon / onPressed / size` |
| `lib/features/camera/widgets/camera_switch_button.dart` | 新增 | 复用 `AppCircleIconButton`，固定 `Icons.cameraswitch` 图标 |
| `lib/features/camera/widgets/camera_controls.dart` | 修改 | 焦段按钮回调从 `onCameraSwitch(int)` → `onZoomSelect(double)`；最右加 `CameraSwitchButton` |
| `lib/features/camera/camera_screen.dart` | 修改 | AppBar 颜色修；调焦段接线；姿势条按前置隐藏；相册按钮用 `AppCircleIconButton` |
| `test/widget/app_circle_icon_button_test.dart` | 新增 | 单元 widget test |
| `test/widget/camera_switch_button_test.dart` | 新增 | 单元 widget test |
| `test/widget/camera_controls_test.dart` | 新增 | 单元 widget test（mock 状态） |

---

## Task 1: 新增 `AppCircleIconButton` 通用圆环按钮

**Files:**
- Create: `lib/features/camera/widgets/app_circle_icon_button.dart`
- Test: `test/widget/app_circle_icon_button_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/widget/app_circle_icon_button_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/camera/widgets/app_circle_icon_button.dart';

void main() {
  group('AppCircleIconButton', () {
    testWidgets('点击触发 onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () => tapped = true,
                size: 56,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppCircleIconButton));
      expect(tapped, isTrue);
    });

    testWidgets('onPressed 为 null 时不响应点击', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.cameraswitch,
                onPressed: null,
                size: 56,
              ),
            ),
          ),
        ),
      );
      // 不应崩即可
      await tester.tap(find.byType(AppCircleIconButton));
      await tester.pump();
    });

    testWidgets('size 参数决定按钮直径', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () {},
                size: 64,
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(AppCircleIconButton));
      expect(size.width, 64);
      expect(size.height, 64);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/widget/app_circle_icon_button_test.dart`
Expected: 失败 — `Target of URI doesn't exist: 'package:easy_beauty_cam/features/camera/widgets/app_circle_icon_button.dart'`

- [ ] **Step 3: 实现 `AppCircleIconButton`**

创建 `lib/features/camera/widgets/app_circle_icon_button.dart`：

```dart
import 'package:flutter/material.dart';

/// 通用圆环 icon 按钮 —— 相机切换按钮、相册按钮复用
///
/// 视觉规范：
/// - 半透黑底（0x66000000）
/// - 1.5pt 白色边框
/// - 线性 / outline 图标
class AppCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x66000000),
      shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 1.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/widget/app_circle_icon_button_test.dart`
Expected: 3 个测试全过

- [ ] **Step 5: 跑全量测试确认无回归**

Run: `flutter test`
Expected: 现有 widget_test.dart + 3 个新测试全过

- [ ] **Step 6: 提交**

```bash
git add lib/features/camera/widgets/app_circle_icon_button.dart test/widget/app_circle_icon_button_test.dart
git commit -m "feat(camera): 新增 AppCircleIconButton 通用圆环按钮组件"
```

---

## Task 2: 新增 `CameraSwitchButton`

**Files:**
- Create: `lib/features/camera/widgets/camera_switch_button.dart`
- Test: `test/widget/camera_switch_button_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/widget/camera_switch_button_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/camera/widgets/camera_switch_button.dart';

void main() {
  group('CameraSwitchButton', () {
    testWidgets('渲染 cameraswitch 图标', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CameraSwitchButton(onPressed: () {}),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.cameraswitch), findsOneWidget);
    });

    testWidgets('点击触发 onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CameraSwitchButton(onPressed: () => tapped = true),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CameraSwitchButton));
      expect(tapped, isTrue);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/widget/camera_switch_button_test.dart`
Expected: 失败 — URI 找不到

- [ ] **Step 3: 实现 `CameraSwitchButton`**

创建 `lib/features/camera/widgets/camera_switch_button.dart`：

```dart
import 'package:flutter/material.dart';
import 'app_circle_icon_button.dart';

/// 相机前/后置切换按钮 —— 复用 AppCircleIconButton
class CameraSwitchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CameraSwitchButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AppCircleIconButton(
      icon: Icons.cameraswitch,
      onPressed: onPressed,
      size: 56,
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/widget/camera_switch_button_test.dart`
Expected: 2 个测试全过

- [ ] **Step 5: 跑全量测试**

Run: `flutter test`
Expected: 全过

- [ ] **Step 6: 提交**

```bash
git add lib/features/camera/widgets/camera_switch_button.dart test/widget/camera_switch_button_test.dart
git commit -m "feat(camera): 新增 CameraSwitchButton 前/后置切换按钮"
```

---

## Task 3: 修改 `CameraControls` 焦段按钮回调 + 加相机切换按钮

**Files:**
- Modify: `lib/features/camera/widgets/camera_controls.dart`
- Test: `test/widget/camera_controls_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `test/widget/camera_controls_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/features/camera/widgets/camera_controls.dart';

void main() {
  Widget _wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );
  }

  group('CameraControls - 后置相机', () {
    testWidgets('渲染 4 颗焦段 pill: .5 / 1x / 2 / 3', (tester) async {
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      expect(find.text('.5'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('点击 2x 触发 onZoomSelect(2.0)，不触发 onCameraSwitch', (tester) async {
      double? zoomedTo;
      int? switchedTo;

      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (z) => zoomedTo = z,
          onCapture: () {},
        ),
      ));

      await tester.tap(find.text('2'));
      expect(zoomedTo, 2.0);
      expect(switchedTo, isNull, reason: '2x 不应该触发 onCameraSwitch');
    });

    testWidgets('点击 .5 触发 onZoomSelect(0.5)', (tester) async {
      double? zoomedTo;
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          onCameraSwitch: (_) {},
          onZoomSelect: (z) => zoomedTo = z,
          onCapture: () {},
        ),
      ));

      await tester.tap(find.text('.5'));
      expect(zoomedTo, 0.5);
    });

    testWidgets('渲染相机切换按钮，点击触发 onCameraSwitch(1)', (tester) async {
      int? switchedTo;
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.cameraswitch));
      expect(switchedTo, 1);
    });
  });

  group('CameraControls - 前置相机', () {
    testWidgets('焦段行只剩 1 颗 1x pill', (tester) async {
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 1,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      expect(find.text('1x'), findsOneWidget);
      expect(find.text('.5'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('点击 1x 触发 onZoomSelect(1.0)', (tester) async {
      double? zoomedTo;
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 1,
          onCameraSwitch: (_) {},
          onZoomSelect: (z) => zoomedTo = z,
          onCapture: () {},
        ),
      ));

      await tester.tap(find.text('1x'));
      expect(zoomedTo, 1.0);
    });

    testWidgets('点击相机切换按钮触发 onCameraSwitch(0)', (tester) async {
      int? switchedTo;
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 1,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.cameraswitch));
      expect(switchedTo, 0);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/widget/camera_controls_test.dart`
Expected: 失败 — `onZoomSelect` 参数不存在 / 编译错

- [ ] **Step 3: 重写 `CameraControls`**

覆写 `lib/features/camera/widgets/camera_controls.dart`：

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'capture_button.dart';
import 'camera_switch_button.dart';

/// 底部相机控制栏
///
/// 布局：占位 / 焦段行（位于拍照按钮上方） / 占位-快门-切换
class CameraControls extends StatelessWidget {
  final int cameraIndex;
  final Function(int) onCameraSwitch;
  final Function(double) onZoomSelect;
  final VoidCallback onCapture;

  const CameraControls({
    super.key,
    required this.cameraIndex,
    required this.onCameraSwitch,
    required this.onZoomSelect,
    required this.onCapture,
  });

  /// 写死的焦段档位（B 方案）
  /// 后置：[0.5, 1.0, 2.0, 3.0]
  /// 前置：[1.0]
  static const _backZooms = <double>[0.5, 1.0, 2.0, 3.0];
  static const _frontZooms = <double>[1.0];

  bool get _isFront => cameraIndex == 1;

  /// 0.5 → ".5", 1.0 → "1x", 2.0 → "2", 3.0 → "3"
  String _zoomLabel(double z) {
    if (z == 1.0) return '1x';
    if (z == 0.5) return '.5';
    if (z == z.truncateToDouble()) return z.toInt().toString();
    return z.toString();
  }

  @override
  Widget build(BuildContext context) {
    final zooms = _isFront ? _frontZooms : _backZooms;
    final currentZoom = _isFront ? 1.0 : 1.0; // 默认显示 1x 选中

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 焦段行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < zooms.length; i++) ...[
                _buildZoomPill(zooms[i], zooms[i] == currentZoom),
                if (i < zooms.length - 1) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.gutterGrid),
          // 控制栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: AppSpacing.thumbHotzone),
              CaptureButton(onPressed: onCapture),
              CameraSwitchButton(
                onPressed: () => onCameraSwitch(_isFront ? 0 : 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoomPill(double zoom, bool isSelected) {
    return GestureDetector(
      onTap: () => onZoomSelect(zoom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutterGrid,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.inverseSurface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        child: Text(
          _zoomLabel(zoom),
          style: AppTypography.numericLabel.copyWith(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/widget/camera_controls_test.dart`
Expected: 7 个测试全过

- [ ] **Step 5: 跑全量测试**

Run: `flutter test`
Expected: 全过；如果 `widget_test.dart` 之外还有调用 `CameraControls` 的会编译失败，继续 Task 4 修。

- [ ] **Step 6: 提交**

```bash
git add lib/features/camera/widgets/camera_controls.dart test/widget/camera_controls_test.dart
git commit -m "refactor(camera): 焦段按钮回调改为 onZoomSelect；加 CameraSwitchButton"
```

---

## Task 4: 修改 `CameraScreen` 接线 AppBar + 姿势条

**Files:**
- Modify: `lib/features/camera/camera_screen.dart:50-75`（AppBar 区域）
- Modify: `lib/features/camera/camera_screen.dart:104-131`（控制栏区域 + 姿势条）
- Test: 静态分析 + flutter test（不写新 widget test，依赖 plugin）

- [ ] **Step 1: 跑 `flutter analyze` 确认当前编译错误**

Run: `flutter analyze`
Expected: `CameraControls` 现在多了一个 `onZoomSelect` 必填参数，`camera_screen.dart` 编译失败。

- [ ] **Step 2: 修改 AppBar 颜色和相册按钮**

修改 `lib/features/camera/camera_screen.dart` 中 `appBar: AppBar(...)` 段（第 50-67 行），替换为：

```dart
      appBar: AppBar(
        backgroundColor: const Color(0x40000000), // 半透黑底
        foregroundColor: Colors.white, // 强制白色 icon/title，绕开 M3 主题置灰
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 24),
          tooltip: l10n.cameraMenu,
          color: Colors.white,
          onPressed: () {
            // TODO: 打开侧边菜单
          },
        ),
        title: Text(
          l10n.appTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
```

并在文件顶部 import 段加：
```dart
import 'widgets/app_circle_icon_button.dart';
```

- [ ] **Step 3: 修改控制栏接线 + 姿势条隐藏**

修改 `lib/features/camera/camera_screen.dart` 中的控制栏（`CameraControls(...)` 调用），替换为：

```dart
              child: CameraControls(
                cameraIndex: state.cameraIndex,
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
```

修改姿势缩略图条（`Positioned(bottom: ...) ... child: const PoseThumbStrip()` 段），替换为：

```dart
        // 3) 底部姿势缩略图条（前置时隐藏）
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.thumbHotzone + AppSpacing.shutterSize + 32 + 60, // 控制栏焦段行 + 控制栏
          child: Visibility(
            visible: state.cameraIndex != 1, // 前置时隐藏
            child: const PoseThumbStrip(),
          ),
        ),
```

- [ ] **Step 4: 跑 `flutter analyze` 确认编译过**

Run: `flutter analyze`
Expected: 无 error。可能有预存的 deprecation warning（withOpacity），忽略。

- [ ] **Step 5: 跑全量测试**

Run: `flutter test`
Expected: 全过。如果 CameraScreen 编译失败，回到上一步修。

- [ ] **Step 6: 提交**

```bash
git add lib/features/camera/camera_screen.dart
git commit -m "fix(camera): AppBar 强制白色；相册按钮走 AppCircleIconButton；姿势条前置时隐藏"
```

---

## Task 5: 代码 review

- [ ] **Step 1: 跑全量分析 + 测试**

```bash
flutter analyze
flutter test
```

Expected: 0 error，14 个测试全过（3 widget_test.dart + 3 app_circle + 2 camera_switch + 7 camera_controls - 1 = 14 个左右）。

- [ ] **Step 2: 手动 review 改动**

读 diff：
```bash
git log --oneline -5
git diff HEAD~4 -- lib/ test/
```

检查清单：
- [ ] 没有引入 print / debug 代码
- [ ] 焦段按钮接线到 `setZoom`（不是 `switchCamera`）
- [ ] AppBar `foregroundColor: Colors.white` 显式设了
- [ ] 相机切换按钮和相册按钮都用 `AppCircleIconButton`
- [ ] 前置时焦段行只显示 1x（写死在 `CameraControls`）
- [ ] 姿势缩略图条用 `Visibility` 在前置时隐藏
- [ ] 没有 hardcode 数字颜色（用 `AppColors.*` / `AppSpacing.*` token）
- [ ] 测试覆盖：按钮触发回调 / 前置时 pill 数量 / 相机切换方向

- [ ] **Step 3: 修复 review 发现的问题（如有）**

如有问题，回滚到对应 Task 修。

- [ ] **Step 4: 提交 review 修正（如有）**

```bash
git add ...
git commit -m "fix(camera): review 修正"
```

---

## 验收标准

- [ ] `flutter analyze` 0 error
- [ ] `flutter test` 全过（≥ 12 个测试）
- [ ] 后置：4 颗焦段 pill，点任一颗触发 `setZoom`（不是 `switchCamera`）
- [ ] 后置：最右圆环 → 切前置，焦段行变 1 颗 1x
- [ ] 前置：1 颗 1x pill，点它触发 `setZoom(1.0)`
- [ ] 前置：最右圆环 → 切回后置
- [ ] AppBar：菜单、标题、相册 icon 全白色清晰
- [ ] 相册按钮和相机切换按钮视觉一致（同色边框、同图标风格）
- [ ] 前置时姿势缩略图条整行隐藏
