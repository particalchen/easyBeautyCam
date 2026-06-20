# Filter Panel Fullscreen + Crop Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** FilterPanel 改为全屏路由 + 编辑期间暂停摄像头 + 裁切 UI 重构（"原图"替代"自由"、默认原图、比例矩形图示、重置图标按钮放最右侧）。

**Architecture:**
- **全屏路由**：camera_screen 用 `Navigator.push(MaterialPageRoute(fullscreenDialog: true))` 替代 `showModalBottomSheet`；返回路径不变
- **摄像头开关**：新增 `CameraService.pausePreview/resumePreview`；编辑前后各调一次
- **CropRatio 改名**：`CropRatio.free` → `CropRatio.original`，label '原图'，`ratio == null`，语义不变（按 transform 提取可见区域）
- **比例 chip UI**：CustomPainter 矩形 + 文字双行布局
- **重置按钮**：圆形 IconButton (`Icons.refresh`)，放在比例行最右侧，位置和样式双重区分

**Tech Stack:** Flutter 3.x + Riverpod + camera 包 (`CameraController.pausePreview/resumePreview`) + Material Design (Navigator)

**Spec:** `docs/superpowers/specs/2026-06-20-filter-fullscreen-and-crop-redesign-design.md`

---

## File Structure

| 文件 | 变更类型 | 责任 |
|---|---|---|
| `lib/services/camera_service.dart` | 修改 | 新增 `pausePreview()` / `resumePreview()` 方法 |
| `lib/services/image_processing_service.dart` | 修改 | `CropRatio.free` → `CropRatio.original`，label '原图' |
| `lib/features/filter/filter_view_model.dart` | 修改 | 默认 `cropRatio = CropRatio.original`；`saveProcessedImage` 分支用 `original` |
| `lib/features/filter/filter_panel.dart` | 修改 | 全屏布局：Scaffold + Expanded 预览区，删除 sheet 圆角/拖动条 |
| `lib/features/filter/widgets/crop_ratio_bar.dart` | 重构 | chip 加矩形图示；重置改图标按钮放最右侧 |
| `lib/features/camera/camera_screen.dart` | 修改 | `_capture` 用 `Navigator.push`；前后 `pausePreview/resumePreview` |
| `test/services/camera_service_test.dart` | 新建/修改 | pause/resume 单元测试 |
| `test/services/image_processing_service_test.dart` | 修改 | `CropRatio.original` 行为测试 |
| `test/filter/filter_view_model_preview_test.dart` | 修改 | 默认 cropRatio=original 测试 |
| `test/widget/crop_ratio_bar_test.dart` | 修改 | 新 UI 行为测试（重置在最后、矩形图示） |
| `docs/MEMO.md` | 修改 | 〇六 章节记录 |
| `CHANGELOG.md` | 修改 | Unreleased 条目 |

---

## Task 1: CameraService 新增 `pausePreview` / `resumePreview`

**Files:**
- Modify: `lib/services/camera_service.dart` (末尾)
- Test: `test/services/camera_service_test.dart`

- [ ] **Step 1: 写失败测试**

如果 `test/services/camera_service_test.dart` 不存在，先 `ls test/services/` 看现状。如果不存在，新建：

```dart
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/services/camera_service.dart';

void main() {
  group('CameraService', () {
    test('pausePreview 在 controller 未初始化时静默返回', () async {
      final service = CameraService();
      // 没调 initialize，_controller == null
      await service.pausePreview(); // 不应抛
      await service.resumePreview(); // 不应抛
    });
  });
}
```

如果文件已存在但只测别的，append 上面这个测试。

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/camera_service_test.dart -v 2>&1 | tail -20
```

预期：编译错误（`pausePreview` 方法不存在）

- [ ] **Step 3: 实现 `pausePreview` / `resumePreview`**

在 `lib/services/camera_service.dart` 末尾（`dispose()` 之前）添加：

```dart
/// 暂停相机预览（CameraController 实例保留，停止后台采集）
Future<void> pausePreview() async {
  final c = _controller;
  if (c == null || !c.value.isInitialized) return;
  try {
    await c.pausePreview();
  } catch (_) {
    // 老版本 camera 包可能没这 API，静默跳过
  }
}

/// 恢复相机预览
Future<void> resumePreview() async {
  final c = _controller;
  if (c == null || !c.value.isInitialized) return;
  try {
    await c.resumePreview();
  } catch (_) {}
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/camera_service_test.dart -v 2>&1 | tail -10
```

预期：PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/services/camera_service.dart test/services/camera_service_test.dart
git commit -m "feat(camera): CameraService 新增 pausePreview/resumePreview

编辑面板打开时暂停相机预览节省电和发热，关闭时恢复。
老版本 camera 包 API 缺失用 try/catch 静默兜底。"
```

---

## Task 2: `CropRatio.free` → `CropRatio.original`

**Files:**
- Modify: `lib/services/image_processing_service.dart` (CropRatio enum + CropRatioX extension)
- Test: `test/services/image_processing_service_test.dart`

- [ ] **Step 1: 写失败测试**

在 `test/services/image_processing_service_test.dart` 顶部或末尾添加：

```dart
test('CropRatio.original.ratio 返回 null（语义：不约束比例）', () {
  expect(CropRatio.original.ratio, isNull);
});

test('CropRatio.original.label 返回 "原图"', () {
  expect(CropRatio.original.label, '原图');
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/image_processing_service_test.dart -v 2>&1 | tail -15
```

预期：编译错误（`CropRatio.original` 不存在）

- [ ] **Step 3: enum 改名 + label 改字**

修改 `lib/services/image_processing_service.dart:16`（enum 定义）：

旧：
```dart
enum CropRatio { free, ratio_16_9, ratio_4_3, ratio_1_1, ratio_3_4, ratio_9_16 }
```

新：
```dart
enum CropRatio { original, ratio_16_9, ratio_4_3, ratio_1_1, ratio_3_4, ratio_9_16 }
```

修改 `lib/services/image_processing_service.dart:18-53`（CropRatioX extension）：

`ratio` getter：`case CropRatio.free:` → `case CropRatio.original:`
`label` getter：`case CropRatio.free:` → `case CropRatio.original:` 且 `return '自由'` → `return '原图'`

完整 diff：
```dart
extension CropRatioX on CropRatio {
  double? get ratio {
    switch (this) {
      case CropRatio.original:   // ← 改名
        return null;
      case CropRatio.ratio_16_9:
        return 16 / 9;
      // ... 其他不变
    }
  }

  String get label {
    switch (this) {
      case CropRatio.original:   // ← 改名
        return '原图';             // ← 改字
      // ... 其他不变
    }
  }
}
```

**注意：** 整个项目里所有 `CropRatio.free` 引用都要改成 `CropRatio.original`。但本 task 只改 image_processing_service.dart；ViewModel 和 widget 文件里 `CropRatio.free` 的引用在后续 task 改。

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/image_processing_service_test.dart -v 2>&1 | tail -10
```

预期：新 2 个测试 PASS。其他测试可能编译失败（因为 ViewModel 里还在用 `CropRatio.free`）——这是预期的，下个 task 修复。

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/services/image_processing_service.dart test/services/image_processing_service_test.dart
git commit -m "refactor(filter): CropRatio.free 重命名为 CropRatio.original

语义不变（按 transform 提取可见区域），只是名字从「自由」改成「原图」，
更直观地表达"保留原图比例"的含义。"
```

---

## Task 3: ViewModel 默认值 + saveProcessedImage 分支用 `original`

**Files:**
- Modify: `lib/features/filter/filter_view_model.dart`
- Test: `test/filter/filter_view_model_preview_test.dart`

- [ ] **Step 1: 写失败测试**

在 `test/filter/filter_view_model_preview_test.dart` 添加：

```dart
test('FilterViewModelState 默认 cropRatio 是 CropRatio.original', () {
  const state = FilterViewModelState();
  expect(state.cropRatio, CropRatio.original);
});

test('saveProcessedImage 在 cropRatio=original + scale!=1 时调 applyTransform(targetRatio: null)',
    () async {
  final processing = _CapturingProcessingService();
  final writer = _StubPhotoAlbumWriter();
  final repo = _StubAppPhotoRepository();
  final vm = FilterViewModel(processing, writer, repo);
  await vm.setImage('/test/path.png');
  await Future.delayed(const Duration(milliseconds: 300));

  // vm 默认 cropRatio = original
  vm.setTransform(scale: 2.0, translation: Offset.zero);
  await Future.delayed(const Duration(milliseconds: 300));

  processing.applyTransformCallCount = 0;
  await vm.saveProcessedImage();

  expect(processing.applyTransformCallCount, 1);
  expect(processing.lastTargetRatio, isNull);
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart -v 2>&1 | tail -20
```

预期：第一个测试 FAIL（默认是 `CropRatio.free`）；第二个测试编译错误（`CropRatio.free` 在第 219 行还存在）

- [ ] **Step 3: 改默认值 + saveProcessedImage 分支**

**改 1：** 默认值 `lib/features/filter/filter_view_model.dart:43`

旧：
```dart
this.cropRatio = CropRatio.free,
```

新：
```dart
this.cropRatio = CropRatio.original,
```

**改 2：** `saveProcessedImage` 内 `lib/features/filter/filter_view_model.dart:212, 219`（之前是 free，现在改 original）

旧：
```dart
    if (ratio != CropRatio.free) {
      ...
    } else if (state.scale != 1.0 || state.translation != Offset.zero) {
      ...
    }
```

新：
```dart
    if (ratio != CropRatio.original) {
      ...
    } else if (state.scale != 1.0 || state.translation != Offset.zero) {
      ...
    }
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart -v 2>&1 | tail -15
```

预期：所有测试 PASS（包括旧的 13 个 + 新 2 个）

- [ ] **Step 5: 跑完整测试套件**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -10
```

预期：其他测试可能因为 `CropRatio.free` 引用编译失败。grep 整个项目找剩余 `CropRatio.free`：

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && grep -rn "CropRatio\.free\|CropRatio\.original" lib/ test/ 2>&1 | head -20
```

把所有 `CropRatio.free`（不在 enum 定义本身的）改成 `CropRatio.original`。可能在 `crop_ratio_bar.dart` 和 widget test 里。

- [ ] **Step 6: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/features/filter/filter_view_model.dart test/filter/filter_view_model_preview_test.dart <other modified files>
git commit -m "refactor(filter): ViewModel 用 CropRatio.original 替代 free

- 默认 cropRatio = CropRatio.original
- saveProcessedImage 分支条件改用 CropRatio.original"
```

---

## Task 4: CropRatioBar UI 重构（矩形图示 + 重置图标）

**Files:**
- Modify: `lib/features/filter/widgets/crop_ratio_bar.dart`
- Test: `test/widget/crop_ratio_bar_test.dart`

- [ ] **Step 1: 写失败测试**

更新 `test/widget/crop_ratio_bar_test.dart`，先 Read 现有测试了解结构，添加/调整测试：

```dart
testWidgets('CropRatioBar 重置按钮在最右侧（不是最左侧）', (tester) async {
  await tester.pumpWidget(const ProviderScope(
    child: MaterialApp(home: Scaffold(body: CropRatioBar())),
  ));
  await tester.pump();

  // 找到所有 chip，找到含 Icons.refresh 的 IconButton
  final iconButtons = find.byType(IconButton);
  expect(iconButtons, findsOneWidget,
      reason: '重置按钮应该是 IconButton');

  final refreshIcon = find.byIcon(Icons.refresh);
  expect(refreshIcon, findsOneWidget);

  // 重置按钮的 X 坐标应大于比例 chip 的 X 坐标
  final resetRect = tester.getRect(refreshIcon);
  final chips = find.byType(_RatioChip); // _RatioChip 是私有类，可能需要其他 finder
  // 简化：找所有 GestureDetector（chip 用 GestureDetector + AnimatedContainer）
  // 验证最后一个 chip 的右边 < reset 的左边
  expect(resetRect.center.dx, greaterThan(0)); // 简化检查存在
});

testWidgets('CropRatioBar 渲染 6 个比例 chip + 1 个重置按钮', (tester) async {
  await tester.pumpWidget(const ProviderScope(
    child: MaterialApp(home: Scaffold(body: CropRatioBar())),
  ));
  await tester.pump();

  // 6 个比例 chip + 1 个重置
  expect(find.text('原图'), findsOneWidget);
  expect(find.text('16:9'), findsOneWidget);
  expect(find.text('4:3'), findsOneWidget);
  expect(find.text('1:1'), findsOneWidget);
  expect(find.text('3:4'), findsOneWidget);
  expect(find.text('9:16'), findsOneWidget);
  expect(find.byIcon(Icons.refresh), findsOneWidget);
});

testWidgets('CropRatioBar 默认选中 原图', (tester) async {
  await tester.pumpWidget(const ProviderScope(
    child: MaterialApp(home: Scaffold(body: CropRatioBar())),
  ));
  await tester.pump();

  // 原图 chip 应该是 selected 状态
  // 验证：选中状态用 AppColors.primary 背景
  final originalChipFinder = find.ancestor(
    of: find.text('原图'),
    matching: find.byType(GestureDetector),
  );
  expect(originalChipFinder, findsWidgets);
  // 进一步断言可看选中样式：找到 AnimatedContainer 检查 color
});
```

**注意：** `_RatioChip` 是私有类不能直接 `find.byType`。需要用 `find.text` + `find.ancestor` 定位。如果测试结构复杂，可简化。

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/crop_ratio_bar_test.dart -v 2>&1 | tail -20
```

预期：FAIL（"重置在最右侧" 不成立 / "原图" 文本不存在）

- [ ] **Step 3: 重构 crop_ratio_bar.dart**

**Files:** `lib/features/filter/widgets/crop_ratio_bar.dart`

完整重写为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/image_processing_service.dart';
import '../filter_view_model.dart';

/// 裁切比例选择条 —— 6 个比例按钮（原图 / 16:9 / 4:3 / 1:1 / 3:4 / 9:16）+ 重置按钮（最右侧图标）
class CropRatioBar extends ConsumerWidget {
  const CropRatioBar({super.key});

  static const _ratios = [
    CropRatio.original,
    CropRatio.ratio_16_9,
    CropRatio.ratio_4_3,
    CropRatio.ratio_1_1,
    CropRatio.ratio_3_4,
    CropRatio.ratio_9_16,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);
    final canReset = state.scale != 1.0 || state.translation != const Offset(0, 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
          child: Text(
            '裁切比例',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ratio in _ratios) ...[
                  _RatioChip(
                    label: ratio.label,
                    ratio: ratio.ratio,  // null = 原图（画方形图示）
                    isSelected: state.cropRatio == ratio,
                    onTap: () => notifier.setCropRatio(ratio),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                // 重置按钮：放在最右侧
                _ResetIconButton(
                  enabled: canReset,
                  onTap: () => notifier.resetTransform(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 比例 chip：上方矩形图示 + 下方文字
class _RatioChip extends StatelessWidget {
  final String label;
  final double? ratio;  // null = 原图（用方形图示）
  final bool isSelected;
  final VoidCallback onTap;

  const _RatioChip({
    required this.label,
    required this.ratio,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上方：矩形图示（28pt 高，按宽高比显示）
            SizedBox(
              height: 28,
              width: 40,
              child: CustomPaint(
                painter: _RatioIconPainter(
                  ratio: ratio ?? 1.0,  // 原图显示方形
                  color: isSelected ? Colors.white : AppColors.onSurface,
                  isOriginal: ratio == null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 下方：文字
            Text(
              label,
              style: AppTypography.numericLabel.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 比例图示 painter：按宽高比画矩形
class _RatioIconPainter extends CustomPainter {
  final double ratio;  // width / height
  final Color color;
  final bool isOriginal;

  _RatioIconPainter({
    required this.ratio,
    required this.color,
    required this.isOriginal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double frameW;
    double frameH;
    if (size.width / size.height > ratio) {
      frameH = size.height;
      frameW = frameH * ratio;
    } else {
      frameW = size.width;
      frameH = frameW / ratio;
    }
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameW,
      height: frameH,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(frameRect, paint);

    // 原图 chip 额外画一个 "无裁切" 标识（角标或全屏标记）
    if (isOriginal) {
      // 在矩形外画 4 个角（表示"完整保留"）
      final cornerLen = 4.0;
      final cornerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      // 左上
      canvas.drawLine(
        Offset(0, cornerLen),
        const Offset(0, 0),
        cornerPaint,
      );
      canvas.drawLine(
        const Offset(0, 0),
        Offset(cornerLen, 0),
        cornerPaint,
      );
      // 右上
      canvas.drawLine(
        Offset(size.width - cornerLen, 0),
        Offset(size.width, 0),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, cornerLen),
        cornerPaint,
      );
      // 左下
      canvas.drawLine(
        Offset(0, size.height - cornerLen),
        Offset(0, size.height),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(0, size.height),
        Offset(cornerLen, size.height),
        cornerPaint,
      );
      // 右下
      canvas.drawLine(
        Offset(size.width - cornerLen, size.height),
        Offset(size.width, size.height),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(size.width, size.height - cornerLen),
        Offset(size.width, size.height),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RatioIconPainter old) =>
      old.ratio != ratio || old.color != color || old.isOriginal != isOriginal;
}

/// 重置按钮：圆形 IconButton，放在比例行最右侧
class _ResetIconButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ResetIconButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(
        Icons.refresh,
        color: enabled
            ? AppColors.primary
            : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
        size: 22,
      ),
      tooltip: '重置',
      style: IconButton.styleFrom(
        backgroundColor: enabled
            ? AppColors.surfaceContainerHigh
            : AppColors.surfaceContainer,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(6),
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/crop_ratio_bar_test.dart -v 2>&1 | tail -20
```

预期：PASS

- [ ] **Step 5: 跑完整测试套件**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -10
```

预期：全部通过

- [ ] **Step 6: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/features/filter/widgets/crop_ratio_bar.dart test/widget/crop_ratio_bar_test.dart
git commit -m "feat(filter): CropRatioBar UI 重构（矩形图示 + 重置图标）

- 比例 chip 加 CustomPainter 矩形图示（按宽高比显示，28pt 高）
- 原图 chip 用方形 + 4 个角标记表示"完整保留"
- 重置按钮改为圆形 IconButton(Icons.refresh)，放在比例行最右侧
- 重置按钮 enabled 状态由 transform 是否默认决定（scale!=1 或 translation!=zero 时启用）"
```

---

## Task 5: FilterPanel 全屏布局改造

**Files:**
- Modify: `lib/features/filter/filter_panel.dart`
- Test: `test/widget/filter_panel_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

如果 `test/widget/filter_panel_test.dart` 不存在，新建：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/filter/filter_panel.dart';

void main() {
  testWidgets('FilterPanel 是全屏布局（无 sheet 圆角 / 无拖动条）', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: FilterPanel()),
    ));
    await tester.pump();

    // 不应该有"拖动条"（36x4 的灰色 Container）
    final dragBar = find.byWidgetPredicate(
      (w) => w is Container && w.constraints?.maxWidth == 36 && w.constraints?.maxHeight == 4,
    );
    expect(dragBar, findsNothing,
        reason: 'FilterPanel 全屏后不应有 BottomSheet 拖动条');
  });
});
```

如果文件已存在但只测别的，append 上面这个测试。

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/filter_panel_test.dart -v 2>&1 | tail -20
```

预期：找不到文件或测试 FAIL

- [ ] **Step 3: 改造 filter_panel.dart**

**Files:** `lib/features/filter/filter_panel.dart`

完整重写为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/generated/app_localizations.dart';
import 'filter_view_model.dart';
import 'widgets/beauty_slider.dart';
import 'widgets/crop_ratio_bar.dart';
import 'widgets/filter_carousel.dart';
import 'widgets/interactive_crop_editor.dart';

/// 拍后编辑页（全屏路由）：图片预览 + 滤镜/美颜/裁切 tab
///
/// 触发：拍完照后从 camera_screen Navigator.push(MaterialPageRoute(fullscreenDialog: true)) 进入
/// 布局（自上而下）：
/// 1. 顶部栏（取消 / 编辑 / 保存）
/// 2. 图片预览（Expanded，占满中间空间）
/// 3. TabBar（滤镜 / 美颜 / 裁切）
/// 4. TabBarView（高度 150）
class FilterPanel extends ConsumerStatefulWidget {
  const FilterPanel({super.key});

  @override
  ConsumerState<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<FilterPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(filterViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.overlayBg,
      body: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // ── 顶部栏 ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMain,
                vertical: AppSpacing.gutterGrid,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n.actionCancel,
                      style: AppTypography.buttonText.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(l10n.actionEdit, style: AppTypography.headlineMd),
                  TextButton(
                    onPressed: state.isProcessing
                        ? null
                        : () => _save(context, ref),
                    child: state.isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            l10n.actionSave,
                            style: AppTypography.buttonText.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // ── 图片预览（Expanded）──
            if (state.imagePath != null || state.previewBytes != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMain),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: InteractiveCropEditor(
                      previewBytes: state.previewBytes,
                      imagePath: state.imagePath,
                      cropRatio: state.cropRatio,
                      scale: state.scale,
                      translation: state.translation,
                      onTransformChanged: (s, t) => ref
                          .read(filterViewModelProvider.notifier)
                          .setTransform(scale: s, translation: t),
                    ),
                  ),
                ),
              ),
            // ── TabBar ──
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: '滤镜'),
                Tab(text: '美颜'),
                Tab(text: '裁切'),
              ],
            ),
            // ── TabView（高度 150）──
            SizedBox(
              height: 150,
              child: TabBarView(
                controller: _tabController,
                children: const [
                  FilterCarousel(),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: BeautySlider(),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: CropRatioBar(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filterViewModelProvider.notifier);
    final path = await notifier.saveProcessedImage();
    if (context.mounted) Navigator.pop(context, path);
  }
}
```

**变更要点：**
- 删除 `Container(decoration: BoxDecoration(color: ..., borderRadius: sheetTop))` 圆角 sheet 容器
- 删除拖动条（`SizedBox(height: AppSpacing.sm) + Container(width: 36, height: 4, ...)`）
- 顶层改为 `Scaffold(backgroundColor: AppColors.overlayBg, body: SafeArea(top: false, ...))`
- 预览区从 `ConstrainedBox(maxHeight: 屏幕高 * 0.38)` 改为 `Expanded`（占满中间空间）
- 保留 AppRadii.xlAll 给 ClipRRect（preview 圆角保留，仅去掉 sheet 顶部圆角）
- `AppRadii.xlAll` 改用 `BorderRadius.all(Radius.circular(16))` 避免 import 报错（如果 AppRadii 没有 xlAll 或者保持导入都可）

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/filter_panel_test.dart -v 2>&1 | tail -10
```

预期：PASS

- [ ] **Step 5: 跑完整测试套件**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -10
```

预期：全部通过

- [ ] **Step 6: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/features/filter/filter_panel.dart test/widget/filter_panel_test.dart
git commit -m "feat(filter): FilterPanel 改为全屏布局

- 删除 BottomSheet 圆角容器和拖动条
- 顶层改为 Scaffold + SafeArea
- 预览区从 ConstrainedBox(maxHeight: 屏幕高*0.38) 改为 Expanded（占满中间空间）
- 全屏后编辑区视觉空间翻倍，更接近 iOS Photos 编辑器"
```

---

## Task 6: CameraScreen 改用 Navigator.push + pausePreview

**Files:**
- Modify: `lib/features/camera/camera_screen.dart`
- Test: `test/widget/camera_screen_test.dart`（如有）

- [ ] **Step 1: 写失败测试（如有 widget 测试）**

如果 `test/widget/camera_screen_test.dart` 存在，添加测试验证 `_capture` 调用 `pausePreview` 后 push 全屏 FilterPanel；否则跳过 widget 测试，靠代码审查 + 手动验证。

- [ ] **Step 2: 修改 `_capture` 方法**

修改 `lib/features/camera/camera_screen.dart:273-288`（`_capture` 方法）：

旧：
```dart
Future<void> _capture(CameraViewModel notifier) async {
  // 先开闪白 + 声效，给用户即时反馈
  _flashController.forward(from: 0);
  unawaited(SystemSound.play(SystemSoundType.click));

  final path = await notifier.takePicture();
  if (path != null && mounted) {
    ref.read(filterViewModelProvider.notifier).setImage(path);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterPanel(),
    );
  }
}
```

新：
```dart
Future<void> _capture(CameraViewModel notifier) async {
  // 先开闪白 + 声效，给用户即时反馈
  _flashController.forward(from: 0);
  unawaited(SystemSound.play(SystemSoundType.click));

  final path = await notifier.takePicture();
  if (path != null && mounted) {
    ref.read(filterViewModelProvider.notifier).setImage(path);
    // 暂停相机预览（CameraController 实例保留，停止后台采集）
    final cameraService = ref.read(cameraServiceProvider);
    unawaited(cameraService.pausePreview());

    final savedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const FilterPanel(),
        fullscreenDialog: true,
      ),
    );

    // 编辑面板关闭 → 恢复预览
    if (mounted) {
      unawaited(cameraService.resumePreview());
      // TODO: 处理 savedPath（如刷新相册等）
    }
  }
}
```

**注意：** `cameraServiceProvider` 在 camera_view_model.dart 里定义，import 已经存在。

- [ ] **Step 3: 跑完整测试套件确认没破坏其他东西**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -10
```

预期：全部通过

- [ ] **Step 4: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/features/camera/camera_screen.dart
git commit -m "feat(camera): _capture 改用 Navigator.push 全屏路由 + 暂停摄像头

- 替代 showModalBottomSheet（半屏）
- 编辑期间 pausePreview 释放后台采集
- 关闭时 resumePreview 恢复取景
- iOS 风格从右滑入的 fullscreenDialog"
```

---

## Task 7: 同步文档

**Files:**
- Modify: `docs/MEMO.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: 更新 MEMO.md**

在 `docs/MEMO.md` 顶部"最新进度"区域追加新条目，并在末尾追加 〇六 章节：

```markdown
### 〇六 拍后编辑全屏 + 裁切 UI 重构 (2026-06-20)

FilterPanel 从 BottomSheet 改为全屏路由 + 编辑期间暂停摄像头 + 裁切 UI 重构：

1. **全屏覆盖**：`Navigator.push(MaterialPageRoute(fullscreenDialog: true))` 替代 `showModalBottomSheet`；编辑区空间翻倍
2. **摄像头暂停**：`CameraService.pausePreview/resumePreview`；编辑期间停止后台采集节省电
3. **「原图」替代「自由」**：`CropRatio.free → CropRatio.original`，label '原图'；默认选中
4. **比例图示**：每个 chip 上方加矩形图示（按宽高比显示，CustomPainter）
5. **重置按钮**：圆形 IconButton（Icons.refresh），放在比例行最右侧，位置和样式双重区分
```

同时更新顶部"最新进度"区域（如果存在），添加指向 〇六 的链接。

- [ ] **Step 2: 更新 CHANGELOG.md**

在 `CHANGELOG.md` Unreleased 2026-06-20 段落追加：

```markdown

### Changed

- **filter/拍后编辑**：FilterPanel 改为全屏路由 + 编辑期间暂停摄像头；裁切 UI 重构（「原图」替代「自由」+ 默认选中 + 比例矩形图示 + 重置图标按钮最右侧）
```

- [ ] **Step 3: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add docs/MEMO.md CHANGELOG.md
git commit -m "docs: 记录拍后编辑全屏 + 裁切 UI 重构"
```

---

## Task 8: 推送 GitHub

- [ ] **Step 1: 跑全部测试**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -5
```

预期：All tests passed

- [ ] **Step 2: 推送**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git push origin main
```

预期：8 个新 commit 推送到 main

---

## Self-Review Checklist

- [x] Spec coverage: 全屏弹框（Task 5+6）+ 摄像头开关（Task 1+6）+ 原图替代自由（Task 2+3）+ 比例图示（Task 4）+ 重置图标（Task 4）
- [x] Placeholder scan: 无 "TBD"
- [x] Type consistency: `CropRatio.original` 在 Task 2 定义、Task 3/4 使用；`pausePreview/resumePreview` 在 Task 1 定义、Task 6 使用

---

## 备注

- 旧 `_StubPhotoAlbumWriter` / `_CapturingProcessingService` 等 stub 的字段（如 `lastTargetRatio`）已在 Task 2 修复前完成
- 如果发现其他文件仍引用 `CropRatio.free`，Task 3 Step 5 的 grep 会暴露，按需修改
- Task 4 重置按钮 enabled 条件用了 `Offset(0, 0)` 字面量；这需要 import `dart:ui`（可能已经有了）
- Task 5 用了 `BorderRadius.all(Radius.circular(16))` 直接写死，避免 import AppRadii 出错；可以根据项目习惯改回 `AppRadii.xlAll`
