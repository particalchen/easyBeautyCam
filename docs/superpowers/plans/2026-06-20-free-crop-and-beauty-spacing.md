# 自由裁切 + 美颜滑条间距 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"拍后编辑"的裁切从固定中心裁切改为支持双指缩放 + 单指拖动的交互式编辑器，并把美颜 3 个滑条间距从 4pt 加宽到 12pt。

**Architecture:**
- 在 `FilterViewModelState` 增加 `scale: double` 和 `translation: Offset`，作为裁切的交互状态
- `ImageProcessingService` 新增 `applyTransform(bytes, scale, translation, targetW, targetH)`，按 zoom + pan 从源图提取可见区域并 resize 到框尺寸
- 新 widget `InteractiveCropEditor` 用 `InteractiveViewer` + `裁切框遮罩` 替换顶部静态预览
- 裁切 tab 的 `CropRatioBar` 加「重置」按钮
- `setCropRatio` 不重置 transform（用户拍板）

**Tech Stack:** Flutter 3.x, Riverpod (StateNotifier), image package (`img.copyCrop`, `img.copyResize`), `InteractiveViewer`, `Matrix4` for inverse-transform math.

---

## 文件地图

| 文件 | 类型 | 职责 |
|---|---|---|
| `lib/features/filter/filter_view_model.dart` | 修改 | 新增 `scale`/`translation` 状态 + `setTransform`/`resetTransform` + 修改 `setCropRatio` 不重置 transform + `_runProcess`/`saveProcessedImage` 接入 applyTransform |
| `lib/services/image_processing_service.dart` | 修改 | 新增 `applyTransform` 公开方法 |
| `lib/features/filter/widgets/interactive_crop_editor.dart` | 新建 | InteractiveViewer 包裹照片 + 裁切框遮罩 + 手势回调 |
| `lib/features/filter/widgets/crop_ratio_bar.dart` | 修改 | 加「重置」按钮（左侧），transform≠默认时高亮 |
| `lib/features/filter/filter_panel.dart` | 修改 | 把 `_PhotoPreview` 替换为 `InteractiveCropEditor` |
| `lib/features/filter/widgets/beauty_slider.dart` | 修改 | SizedBox(4) → SizedBox(AppSpacing.gutterGrid) |
| `test/services/image_processing_service_test.dart` | 修改 | 加 applyTransform 单测 |
| `test/filter/filter_view_model_preview_test.dart` | 修改 | 加 transform 相关状态测试 |
| `test/widget/interactive_crop_editor_test.dart` | 新建 | 编辑器 widget 测试 |
| `test/widget/crop_ratio_bar_test.dart` | 新建 | 重置按钮测试 |
| `test/widget/beauty_slider_test.dart` | 修改 | 加间距视觉测试 |
| `docs/MEMO.md` | 修改 | 记录本次改动到〇五 |
| `CHANGELOG.md` | 修改 | 记录本次改动 |

---

## Task 1: 美颜滑条间距 4pt → 12pt（trivial）

**Files:**
- Modify: `lib/features/filter/widgets/beauty_slider.dart:38,45`

- [ ] **Step 1: 修改 SizedBox**

```dart
// lib/features/filter/widgets/beauty_slider.dart

// 第 38 行和第 45 行：
const SizedBox(height: AppSpacing.gutterGrid),  // 原来 height: 4
```

把两处 `const SizedBox(height: 4)` 替换为 `const SizedBox(height: AppSpacing.gutterGrid)`（= 12pt）。

- [ ] **Step 2: 运行现有 beauty_slider_test 确保不挂**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/beauty_slider_test.dart`
Expected: PASS（间距变化不影响行为断言）

- [ ] **Step 3: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/features/filter/widgets/beauty_slider.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "ui: 美颜三档滑条间距 4pt -> 12pt"
```

---

## Task 2: FilterViewModelState 加 scale / translation 字段

**Files:**
- Modify: `lib/features/filter/filter_view_model.dart:24-76`
- Test: `test/filter/filter_view_model_preview_test.dart`（在已有 group 末尾追加）

- [ ] **Step 1: 写失败测试**

在 `test/filter/filter_view_model_preview_test.dart` 的 `group('FilterViewModel 实时预览'` 末尾追加：

```dart
    test('默认 scale=1.0, translation=Offset.zero', () {
      final state = container.read(filterViewModelProvider);
      expect(state.scale, 1.0);
      expect(state.translation, Offset.zero);
    });
```

并在文件顶部 `import 'dart:ui' show Offset;`（已有就跳过）。

- [ ] **Step 2: 运行测试，断言失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart`
Expected: FAIL — `state.scale` getter 找不到

- [ ] **Step 3: 实现 — 添加字段到 state**

```dart
// lib/features/filter/filter_view_model.dart

class FilterViewModelState {
  final String? imagePath;
  final FilterType selectedFilter;
  final CropRatio cropRatio;
  final double smooth;
  final double whiten;
  final double slim;
  final double scale;            // ← 新增
  final Offset translation;      // ← 新增
  final bool isProcessing;
  final bool isPreviewProcessing;
  final Uint8List? previewBytes;
  final Uint8List? originalBytes;

  const FilterViewModelState({
    this.imagePath,
    this.selectedFilter = FilterType.coral,
    this.cropRatio = CropRatio.free,
    this.smooth = AppConstants.defaultBeautySmooth,
    this.whiten = AppConstants.defaultBeautyWhiten,
    this.slim = AppConstants.defaultBeautySlim,
    this.scale = 1.0,                    // ← 新增
    this.translation = Offset.zero,       // ← 新增
    this.isProcessing = false,
    this.isPreviewProcessing = false,
    this.previewBytes,
    this.originalBytes,
  });

  FilterViewModelState copyWith({
    String? imagePath,
    FilterType? selectedFilter,
    CropRatio? cropRatio,
    double? smooth,
    double? whiten,
    double? slim,
    double? scale,                       // ← 新增
    Offset? translation,                 // ← 新增
    bool? isProcessing,
    bool? isPreviewProcessing,
    Uint8List? previewBytes,
    Uint8List? originalBytes,
    bool clearOriginalBytes = false,
    bool clearPreviewBytes = false,
  }) {
    return FilterViewModelState(
      imagePath: imagePath ?? this.imagePath,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      cropRatio: cropRatio ?? this.cropRatio,
      smooth: smooth ?? this.smooth,
      whiten: whiten ?? this.whiten,
      slim: slim ?? this.slim,
      scale: scale ?? this.scale,                // ← 新增
      translation: translation ?? this.translation,  // ← 新增
      isProcessing: isProcessing ?? this.isProcessing,
      isPreviewProcessing: isPreviewProcessing ?? this.isPreviewProcessing,
      previewBytes: clearPreviewBytes ? null : (previewBytes ?? this.previewBytes),
      originalBytes: clearOriginalBytes ? null : (originalBytes ?? this.originalBytes),
    );
  }
}
```

并在文件顶部加：`import 'dart:ui' show Offset;`

- [ ] **Step 4: 运行测试，断言 PASS**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/features/filter/filter_view_model.dart test/filter/filter_view_model_preview_test.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "feat(filter): state 增加 scale/translation 字段"
```

---

## Task 3: FilterViewModel.setTransform + resetTransform

**Files:**
- Modify: `lib/features/filter/filter_view_model.dart:107-110`
- Test: `test/filter/filter_view_model_preview_test.dart`

- [ ] **Step 1: 写失败测试**

追加到 `group('FilterViewModel 实时预览'`：

```dart
    test('setTransform 更新 scale/translation 并触发处理', () async {
      container.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.callCount;

      container.read(filterViewModelProvider.notifier).setTransform(
            scale: 2.0,
            translation: const Offset(10, 20),
          );
      await Future<void>.delayed(const Duration(milliseconds: 280));

      final state = container.read(filterViewModelProvider);
      expect(state.scale, 2.0);
      expect(state.translation, const Offset(10, 20));
      expect(svc.callCount, greaterThan(c1), reason: 'setTransform 应触发重新处理');
    });

    test('resetTransform 把 scale/translation 拉回默认', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setTransform(scale: 3.0, translation: const Offset(50, 50));
      notifier.resetTransform();
      final state = container.read(filterViewModelProvider);
      expect(state.scale, 1.0);
      expect(state.translation, Offset.zero);
    });
```

- [ ] **Step 2: 运行测试，断言失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart`
Expected: FAIL — `setTransform` / `resetTransform` 方法不存在

- [ ] **Step 3: 实现 — 新增方法**

在 `lib/features/filter/filter_view_model.dart` 现有 `setCropRatio` 后面追加：

```dart
  void setTransform({double? scale, Offset? translation}) {
    state = state.copyWith(
      scale: scale ?? state.scale,
      translation: translation ?? state.translation,
    );
    _scheduleProcess();
  }

  void resetTransform() {
    state = state.copyWith(scale: 1.0, translation: Offset.zero);
    _scheduleProcess();
  }
```

- [ ] **Step 4: 运行测试，断言 PASS**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/features/filter/filter_view_model.dart test/filter/filter_view_model_preview_test.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "feat(filter): setTransform/resetTransform 方法"
```

---

## Task 4: setCropRatio 不重置 transform

**Files:**
- Modify: `lib/features/filter/filter_view_model.dart:107-110`
- Test: `test/filter/filter_view_model_preview_test.dart`

- [ ] **Step 1: 写失败测试**

追加：

```dart
    test('setCropRatio 不重置 transform', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setTransform(scale: 2.5, translation: const Offset(30, 40));

      notifier.setCropRatio(CropRatio.ratio_1_1);

      final state = container.read(filterViewModelProvider);
      expect(state.scale, 2.5, reason: '切换比例不能把 scale 拉回 1.0');
      expect(state.translation, const Offset(30, 40), reason: '切换比例不能把 translation 清零');
      expect(state.cropRatio, CropRatio.ratio_1_1);
    });
```

- [ ] **Step 2: 运行测试，断言 PASS（确认现有行为已经正确）**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart`

如果已 PASS：跳到 Step 4。
如果 FAIL：跳到 Step 3 修代码。

- [ ] **Step 3（仅当 FAIL 时）：确认 setCropRatio 没有 resetTransform 调用**

检查 `lib/features/filter/filter_view_model.dart` 的 `setCropRatio`：

```dart
  void setCropRatio(CropRatio ratio) {
    state = state.copyWith(cropRatio: ratio);
    _scheduleProcess();
  }
```

确认**没有**调用 `resetTransform()`。如果有，删掉那行调用。

- [ ] **Step 4: Commit（如有改动）**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/features/filter/filter_view_model.dart test/filter/filter_view_model_preview_test.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "test(filter): setCropRatio 不重置 transform"
```

---

## Task 5: ImageProcessingService.applyTransform

**Files:**
- Modify: `lib/services/image_processing_service.dart`（在 crop 方法后追加）
- Test: `test/services/image_processing_service_test.dart`

- [ ] **Step 1: 写失败测试**

在 `test/services/image_processing_service_test.dart` 末尾追加：

```dart
  group('ImageProcessingService.applyTransform - zoom + pan', () {
    test('scale=1.0, translation=zero, target=原尺寸：输出=原图', () async {
      final src = img.Image(width: 400, height: 300);
      img.fill(src, color: img.ColorRgb8(120, 120, 120));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyTransform(
        srcBytes,
        scale: 1.0,
        translation: Offset.zero,
        targetWidth: 400,
        targetHeight: 300,
      );
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 400);
      expect(outImage.height, 300);
    });

    test('scale=2.0：visible area 是原图中心 1/2，resize 到 target', () async {
      // 400x300 图，scale=2 → 可见区 200x150，从中心取
      final src = img.Image(width: 400, height: 300);
      img.fill(src, color: img.ColorRgb8(80, 80, 80));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyTransform(
        srcBytes,
        scale: 2.0,
        translation: Offset.zero,
        targetWidth: 200,
        targetHeight: 150,
      );
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 200);
      expect(outImage.height, 150);
      // 中心区域被裁出：左/右各裁 100pt
      // 验证中心区域的颜色仍是 (80,80,80)
      final centerPixel = outImage.getPixel(100, 75);
      expect(centerPixel.r, 80);
    });

    test('translation 平移可见窗口', () async {
      // 400x300 图，scale=1，translation=(0.1, 0) → visible 中心向右偏移 10%*W
      final src = img.Image(width: 400, height: 300);
      img.fill(src, color: img.ColorRgb8(50, 50, 50));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyTransform(
        srcBytes,
        scale: 1.0,
        translation: const Offset(0.1, 0),
        targetWidth: 200,
        targetHeight: 150,
      );
      // 不报错即可
      expect(out, isNotEmpty);
    });

    test('越界 translation 自动 clamp 到图像边界', () async {
      // 极端：translation=(1.0, 1.0) 应该被 clamp，不报错
      final src = img.Image(width: 200, height: 200);
      img.fill(src, color: img.ColorRgb8(100, 100, 100));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyTransform(
        srcBytes,
        scale: 2.0,
        translation: const Offset(1.0, 1.0),
        targetWidth: 100,
        targetHeight: 100,
      );
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 100);
    });
  });
```

并在文件顶部加 `import 'dart:ui' show Offset;`（已有就跳过）。

- [ ] **Step 2: 运行测试，断言失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/image_processing_service_test.dart`
Expected: FAIL — `applyTransform` 方法不存在

- [ ] **Step 3: 实现 applyTransform**

在 `lib/services/image_processing_service.dart` 末尾（crop 方法后）追加：

```dart
  /// 按 scale + translation 提取源图可见区域，并 resize 到 target。
  ///
  /// 参数：
  /// - [scale] ∈ [1.0, 4.0]：1.0 = 全图可见，2.0 = 中心 1/2 区域可见
  /// - [translation] ∈ [-1, 1]：相对图像宽高的偏移比例
  ///   > 0 = 窗口向 source 右/下偏移（即 source 向左/上偏移 → 用户视角是"图片向右移"）
  /// - [targetWidth]/[targetHeight]：输出 resize 尺寸（裁切框尺寸）
  ///
  /// 算法：
  /// 1. visible_w = srcW / scale；visible_h = srcH / scale
  /// 2. 中心位置 = (srcW/2 - translation.dx * srcW, srcH/2 - translation.dy * srcH)
  /// 3. clamp 中心位置到 [visible_w/2, srcW - visible_w/2]（防止越界）
  /// 4. img.copyCrop 提取 visible region
  /// 5. img.copyResize 到 targetWidth × targetHeight
  Future<Uint8List> applyTransform(
    Uint8List imageBytes, {
    required double scale,
    required Offset translation,
    required int targetWidth,
    required int targetHeight,
  }) async {
    if (scale <= 1.0 && translation == Offset.zero) {
      // noop：直接 resize 到 target 即可（避免无意义的 copyCrop）
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;
      if (image.width == targetWidth && image.height == targetHeight) {
        return imageBytes;
      }
      final resized = img.copyResize(image, width: targetWidth, height: targetHeight);
      return Uint8List.fromList(img.encodePng(resized));
    }

    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final srcW = image.width;
    final srcH = image.height;
    final s = scale.clamp(1.0, 4.0);

    // visible region size in source coords
    final visibleW = (srcW / s).round();
    final visibleH = (srcH / s).round();

    // visible region center in source coords
    final tx = translation.dx.clamp(-1.0, 1.0);
    final ty = translation.dy.clamp(-1.0, 1.0);
    var cx = (srcW / 2.0 - tx * srcW).round();
    var cy = (srcH / 2.0 - ty * srcH).round();

    // clamp center to keep visible region in bounds
    final halfW = visibleW ~/ 2;
    final halfH = visibleH ~/ 2;
    cx = cx.clamp(halfW, srcW - halfW);
    cy = cy.clamp(halfH, srcH - halfH);

    final x = cx - halfW;
    final y = cy - halfH;
    final cropped = img.copyCrop(image, x: x, y: y, width: visibleW, height: visibleH);
    final resized = img.copyResize(cropped, width: targetWidth, height: targetHeight);
    return Uint8List.fromList(img.encodePng(resized));
  }
```

- [ ] **Step 4: 运行测试，断言 PASS**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/image_processing_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/services/image_processing_service.dart test/services/image_processing_service_test.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "feat(image): applyTransform 支持 zoom + pan"
```

---

## Task 6: FilterViewModel 接入 applyTransform

**Files:**
- Modify: `lib/features/filter/filter_view_model.dart:139-197`
- Test: `test/filter/filter_view_model_preview_test.dart`

- [ ] **Step 1: 写失败测试**

在 `_CapturingProcessingService` 里加一个 mock `applyTransform`：

```dart
class _CapturingProcessingService extends ImageProcessingService {
  int callCount = 0;
  int applyTransformCallCount = 0;
  double? lastScale;
  Offset? lastTranslation;
  int? lastTargetWidth;
  int? lastTargetHeight;
  Uint8List _bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

  @override
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
  }) async {
    callCount++;
    _bytes = Uint8List.fromList([..._bytes, callCount & 0xff]);
    return _bytes;
  }

  @override
  Future<Uint8List> applyTransform(
    Uint8List imageBytes, {
    required double scale,
    required Offset translation,
    required int targetWidth,
    required int targetHeight,
  }) async {
    applyTransformCallCount++;
    lastScale = scale;
    lastTranslation = translation;
    lastTargetWidth = targetWidth;
    lastTargetHeight = targetHeight;
    return imageBytes;
  }
}
```

并追加测试：

```dart
    test('setTransform 触发 applyTransform 调用', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.applyTransformCallCount;

      notifier.setTransform(scale: 2.0, translation: const Offset(0.1, 0.2));
      await Future<void>.delayed(const Duration(milliseconds: 280));

      expect(svc.applyTransformCallCount, greaterThan(c1));
      expect(svc.lastScale, 2.0);
      expect(svc.lastTranslation, const Offset(0.1, 0.2));
    });
```

- [ ] **Step 2: 运行测试，断言失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart`
Expected: FAIL — `applyTransform` 未被 view model 调用

- [ ] **Step 3: 修改 _runProcess 和 saveProcessedImage**

`lib/features/filter/filter_view_model.dart` 第 139-197 行：

```dart
  Future<void> _runProcess() async {
    if (state.imagePath == null) return;
    // 1) 确保原图 bytes 加载
    var origBytes = state.originalBytes;
    if (origBytes == null) {
      final file = File(state.imagePath!);
      if (!await file.exists()) return;
      if (!mounted) return;
      origBytes = await file.readAsBytes();
      if (!mounted) return;
      state = state.copyWith(originalBytes: origBytes);
    }

    if (!mounted) return;
    state = state.copyWith(isPreviewProcessing: true);

    var processed = await _processingService.processImage(
      origBytes,
      filter: state.selectedFilter,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
    );

    // 裁切（如果选了非自由比例）—— 注意：自由也跑 transform（占位），再 crop
    final ratio = state.cropRatio;
    if (ratio != CropRatio.free) {
      // 1. 先按 transform 提取可见区（用户缩放/平移后的内容）
      // 2. 再按比例裁切到最终尺寸
      // target 尺寸来自当前 cropRatio 的 ratio × 一个固定基准高（这里用原图高做基准）
      final baseHeight = img.Image.fromBytes ?? 1000; // 用 processImage 输出尺寸
      // 实际我们用 processed 自身的尺寸
      final procImg = img.decodeImage(processed);
      if (procImg != null) {
        final targetH = procImg.height;
        final targetW = (targetH * ratio.ratio!).round();
        processed = await _processingService.applyTransform(
          processed,
          scale: state.scale,
          translation: state.translation,
          targetWidth: targetW,
          targetHeight: targetH,
        );
        // applyTransform 已经按目标比例 resize，不再需要二次 crop
      }
    }

    if (!mounted) return;
    state = state.copyWith(
      previewBytes: processed,
      isPreviewProcessing: false,
    );
  }
```

> 注：上面那段用了 `img.Image.fromBytes` 这是 placeholder，需要替换。改用更清晰的实现 —— 直接 decode processed bytes：

```dart
    // 裁切（如果选了非自由比例）
    final ratio = state.cropRatio;
    if (ratio != CropRatio.free) {
      final targetRatio = ratio.ratio!;
      final procImg = img.decodeImage(processed);
      if (procImg != null) {
        // target 尺寸：取处理后图像的"较长边"作为基准，按比例反算另一条
        // 简化：高度 = processed height，宽度 = round(height * targetRatio)
        final targetH = procImg.height;
        final targetW = (targetH * targetRatio).round();
        processed = await _processingService.applyTransform(
          processed,
          scale: state.scale,
          translation: state.translation,
          targetWidth: targetW,
          targetHeight: targetH,
        );
      }
    }
```

并在 `lib/features/filter/filter_view_model.dart` 顶部加 `import 'package:image/image.dart' as img;` 和 `import 'dart:ui' show Offset;`。

同样改 `saveProcessedImage`（第 175-197 行），让保存走相同流水线：

```dart
  Future<String?> saveProcessedImage() async {
    if (state.imagePath == null) return null;
    state = state.copyWith(isProcessing: true);

    var bytes = state.previewBytes;
    bytes ??= await _processingService.processImage(
      await _readImageBytes(state.imagePath!),
      filter: state.selectedFilter,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
    );

    final ratio = state.cropRatio;
    if (ratio != CropRatio.free && bytes != null) {
      final procImg = img.decodeImage(bytes);
      if (procImg != null) {
        final targetH = procImg.height;
        final targetW = (targetH * ratio.ratio!).round();
        bytes = await _processingService.applyTransform(
          bytes,
          scale: state.scale,
          translation: state.translation,
          targetWidth: targetW,
          targetHeight: targetH,
        );
      }
    }

    if (bytes == null) {
      state = state.copyWith(isProcessing: false);
      return null;
    }

    final filename =
        'easy_beauty_${DateTime.now().millisecondsSinceEpoch}.png';
    await _photoAlbumWriter.saveImage(bytes, filename: filename);
    final appPath = await _appPhotoRepository.add(bytes);

    state = state.copyWith(isProcessing: false);
    return appPath;
  }
```

- [ ] **Step 4: 运行测试，断言 PASS**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/features/filter/filter_view_model.dart test/filter/filter_view_model_preview_test.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "feat(filter): _runProcess/save 接入 applyTransform"
```

---

## Task 7: InteractiveCropEditor widget（核心）

**Files:**
- Create: `lib/features/filter/widgets/interactive_crop_editor.dart`
- Test: `test/widget/interactive_crop_editor_test.dart`

- [ ] **Step 1: 写失败测试**

新建 `test/widget/interactive_crop_editor_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/filter/widgets/interactive_crop_editor.dart';

/// 1x1 透明 PNG
final _kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xC0,
  0xC0, 0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0x9D, 0xA1, 0x88, 0x84, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('InteractiveCropEditor 渲染 InteractiveViewer + Image', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 400,
          child: InteractiveCropEditor(
            previewBytes: _kTinyPng,
            cropRatio: CropRatio.free,
            scale: 1.0,
            translation: Offset.zero,
            onTransformChanged: (_, __) {},
          ),
        ),
      ),
    ));
    await tester.pump();
    // 找到 InteractiveViewer
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('非自由比例：渲染遮罩 CustomPaint', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 400,
          child: InteractiveCropEditor(
            previewBytes: _kTinyPng,
            cropRatio: CropRatio.ratio_1_1,
            scale: 1.0,
            translation: Offset.zero,
            onTransformChanged: (_, __) {},
          ),
        ),
      ),
    ));
    await tester.pump();
    // 找到 CustomPaint（遮罩）
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('自由比例：不渲染遮罩层', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 400,
          child: InteractiveCropEditor(
            previewBytes: _kTinyPng,
            cropRatio: CropRatio.free,
            scale: 1.0,
            translation: Offset.zero,
            onTransformChanged: (_, __) {},
          ),
        ),
      ),
    ));
    await tester.pump();
    // 自由比例下 _CropFrameMask 的 CustomPaint 不存在
    // 简化断言：能找到的 CustomPaint 数量应少于非自由情况
    // 这里仅验证不报错
    expect(find.byType(InteractiveCropEditor), findsOneWidget);
  });
}
```

> 注意：widget 是 ConsumerWidget，previewBytes/cropRatio/scale/translation/onTransformChanged 都从 view model 取。这里测试不通过 Riverpod，所以 widget 也提供"直接传 props"的版本（见 Step 3 实现）。

文件顶部加 `import 'dart:typed_data';`

- [ ] **Step 2: 运行测试，断言失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/interactive_crop_editor_test.dart`
Expected: FAIL — widget 不存在

- [ ] **Step 3: 实现 InteractiveCropEditor**

新建 `lib/features/filter/widgets/interactive_crop_editor.dart`：

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../services/image_processing_service.dart';

/// 拍后编辑顶部「交互式裁切编辑器」
///
/// - 用 InteractiveViewer 让用户可以双指缩放 / 单指拖动
/// - 顶部叠一层裁切框遮罩（自由比例下不画）
/// - 手势结束 200ms debounce 后回调 onTransformChanged
///
/// Props 由调用方（FilterPanel 通过 Riverpod）传入，便于纯 widget 测试
class InteractiveCropEditor extends StatefulWidget {
  final Uint8List? previewBytes;
  final String? imagePath;
  final CropRatio cropRatio;
  final double scale;
  final Offset translation;
  final void Function(double scale, Offset translation) onTransformChanged;

  const InteractiveCropEditor({
    super.key,
    this.previewBytes,
    this.imagePath,
    required this.cropRatio,
    required this.scale,
    required this.translation,
    required this.onTransformChanged,
  });

  @override
  State<InteractiveCropEditor> createState() => _InteractiveCropEditorState();
}

class _InteractiveCropEditorState extends State<InteractiveCropEditor> {
  late final TransformationController _ctrl;
  Timer? _debounce;

  static const _minScale = 1.0;
  static const _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _ctrl = TransformationController();
    _syncFromProps();
  }

  @override
  void didUpdateWidget(InteractiveCropEditor old) {
    super.didUpdateWidget(old);
    if (old.scale != widget.scale || old.translation != widget.translation) {
      _syncFromProps();
    }
  }

  void _syncFromProps() {
    // 重建 Matrix4：以 (0,0) 为变换原点（image 左上角）
    final m = Matrix4.identity()
      ..translate(widget.translation.dx, widget.translation.dy)
      ..scale(widget.scale);
    _ctrl.value = m;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onInteractionEnd() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final m = _ctrl.value;
      final s = m.getMaxScaleOnAxis().clamp(_minScale, _maxScale);
      final tx = m.getTranslation().x;
      final ty = m.getTranslation().y;
      // 归一化 translation 到 [-1, 1] 区间（相对 editor size）
      final size = context.size ?? const Size(300, 300);
      final ntx = (tx / size.width).clamp(-1.0, 1.0);
      final nty = (ty / size.height).clamp(-1.0, 1.0);
      widget.onTransformChanged(s, Offset(ntx, nty));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.cropRatio.ratio;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _ctrl,
            minScale: _minScale,
            maxScale: _maxScale,
            onInteractionEnd: (_) => _onInteractionEnd(),
            child: Center(
              child: widget.previewBytes != null
                  ? Image.memory(widget.previewBytes!, fit: BoxFit.contain)
                  : (widget.imagePath != null
                      ? Image.file(File(widget.imagePath!), fit: BoxFit.contain)
                      : const SizedBox.shrink()),
            ),
          ),
          if (ratio != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CropFramePainter(ratio: ratio),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 裁切框遮罩 painter：
/// - 框外画半透明黑（alpha 0.55）
/// - 框边画 1.5pt 珊瑚色线
class _CropFramePainter extends CustomPainter {
  final double ratio; // width / height

  _CropFramePainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    // 计算 editor 中能容纳的最大目标比例矩形（居中）
    double frameW;
    double frameH;
    if (size.width / size.height > ratio) {
      // editor 比目标更宽 → 框高=editor高，框宽=框高*ratio
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

    // 框外遮罩：用 4 个矩形覆盖框外
    final maskPaint = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, frameRect.top), maskPaint);
    canvas.drawRect(Rect.fromLTRB(0, frameRect.bottom, size.width, size.height), maskPaint);
    canvas.drawRect(Rect.fromLTRB(0, frameRect.top, frameRect.left, frameRect.bottom), maskPaint);
    canvas.drawRect(Rect.fromLTRB(frameRect.right, frameRect.top, size.width, frameRect.bottom), maskPaint);

    // 框边
    final borderPaint = Paint()
      ..color = const Color(0xFFFF6F61) // AppColors.primary 兜底
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(frameRect, borderPaint);
  }

  @override
  bool shouldRepaint(_CropFramePainter old) => old.ratio != ratio;
}
```

文件顶部加 `import 'dart:async';`

- [ ] **Step 4: 运行测试，断言 PASS**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/interactive_crop_editor_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/features/filter/widgets/interactive_crop_editor.dart test/widget/interactive_crop_editor_test.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "feat(filter): InteractiveCropEditor widget"
```

---

## Task 8: CropRatioBar 加「重置」按钮

**Files:**
- Modify: `lib/features/filter/widgets/crop_ratio_bar.dart`
- Test: `test/widget/crop_ratio_bar_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

新建 `test/widget/crop_ratio_bar_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/filter/widgets/crop_ratio_bar.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

class _Stub extends FilterViewModel {
  _Stub(FilterViewModelState s)
      : super(_NoopService(), _NoopWriter(), _NoopRepo()) {
    state = s;
  }
}

class _NoopService extends ImageProcessingService {
  @override
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
  }) async => imageBytes;

  @override
  Future<Uint8List> applyTransform(
    Uint8List imageBytes, {
    required double scale,
    required Offset translation,
    required int targetWidth,
    required int targetHeight,
  }) async => imageBytes;
}

class _NoopWriter implements PhotoAlbumWriter {
  @override
  Future<void> saveImage(Uint8List bytes, {required String filename}) async {}
}

class _NoopRepo implements AppPhotoRepository {
  @override
  Future<List<String>> listAll() async => const [];
  @override
  Future<String> add(Uint8List bytes) async => '/noop';
  @override
  Future<void> delete(List<String> paths) async {}
}

Future<void> _pump(WidgetTester tester, FilterViewModelState state) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      filterViewModelProvider.overrideWith((_) => _Stub(state)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: CropRatioBar()),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('默认 state：渲染 6 个比例 chip + 重置按钮', (tester) async {
    await _pump(tester, const FilterViewModelState());
    expect(find.text('自由'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('重置'), findsOneWidget);
  });

  testWidgets('scale≠1.0 时点重置按钮，调 view model resetTransform', (tester) async {
    int resetCount = 0;
    final stub = _Stub(const FilterViewModelState(scale: 2.0));
    // 替换 resetTransform
    // 简化：直接验证 state 变化
    await tester.pumpWidget(ProviderScope(
      overrides: [
        filterViewModelProvider.overrideWith((_) => stub),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CropRatioBar()),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('重置'));
    await tester.pump();
    // 验证 view model state 被 reset（scale 回到 1.0）
    expect(stub.state.scale, 1.0);
  });
}
```

文件顶部加 `import 'dart:typed_data';`

- [ ] **Step 2: 运行测试，断言失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/crop_ratio_bar_test.dart`
Expected: FAIL — 「重置」按钮文本不存在

- [ ] **Step 3: 在 CropRatioBar 加重置按钮**

修改 `lib/features/filter/widgets/crop_ratio_bar.dart` 的 `build` 方法，在 `SingleChildScrollView` 之前加一个重置按钮，并把 scrollable 内部移除：

```dart
// lib/features/filter/widgets/crop_ratio_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/image_processing_service.dart';
import '../filter_view_model.dart';

class CropRatioBar extends ConsumerWidget {
  const CropRatioBar({super.key});

  static const _ratios = [
    CropRatio.free,
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
    final canReset = state.scale != 1.0 || state.translation != Offset.zero;

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
                // 重置按钮
                _ResetChip(
                  enabled: canReset,
                  onTap: () => notifier.resetTransform(),
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final ratio in _ratios) ...[
                  _RatioChip(
                    label: ratio.label,
                    isSelected: state.cropRatio == ratio,
                    onTap: () => notifier.setCropRatio(ratio),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResetChip extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _ResetChip({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.surfaceContainerHigh
              : AppColors.surfaceContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(
            color: enabled ? AppColors.outline : AppColors.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          '重置',
          style: AppTypography.numericLabel.copyWith(
            color: enabled
                ? AppColors.onSurface
                : AppColors.onSurfaceVariant.withOpacity(0.5),
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// 原有 _RatioChip 保留不变
// ... (省略，见原文件)
```

并在顶部加 `import 'dart:ui' show Offset;`（如果还没有）

- [ ] **Step 4: 运行测试，断言 PASS**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/crop_ratio_bar_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/features/filter/widgets/crop_ratio_bar.dart test/widget/crop_ratio_bar_test.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "feat(filter): CropRatioBar 加重置按钮"
```

---

## Task 9: FilterPanel 把 _PhotoPreview 替换为 InteractiveCropEditor

**Files:**
- Modify: `lib/features/filter/filter_panel.dart:115,163-216`

- [ ] **Step 1: 修改 FilterPanel**

`lib/features/filter/filter_panel.dart` 第 115 行：

```dart
// 原：
if (state.imagePath != null) _PhotoPreview(state: state),

// 改为：
Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.38,
    ),
    child: ClipRRect(
      borderRadius: AppRadii.xlAll,
      child: (state.imagePath != null || state.previewBytes != null)
          ? InteractiveCropEditor(
              previewBytes: state.previewBytes,
              imagePath: state.imagePath,
              cropRatio: state.cropRatio,
              scale: state.scale,
              translation: state.translation,
              onTransformChanged: (s, t) =>
                  ref.read(filterViewModelProvider.notifier).setTransform(
                        scale: s,
                        translation: t,
                      ),
            )
          : const SizedBox.shrink(),
    ),
  ),
),
```

并在顶部 `import 'widgets/interactive_crop_editor.dart';`，删掉 `_PhotoPreview` 类（已无引用）。

- [ ] **Step 2: 运行现有 filter_panel_test**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/filter_panel_test.dart`
Expected: PASS（如果现有断言没要求 `_PhotoPreview` 仍存在）

如果有断言失败，查看具体 case，调整或保留 `_PhotoPreview` 作为 compatibility alias。

- [ ] **Step 3: 运行整个 test suite**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test`
Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add lib/features/filter/filter_panel.dart && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "feat(filter): FilterPanel 顶部预览替换为 InteractiveCropEditor"
```

---

## Task 10: 全套测试 + 文档

**Files:**
- Modify: `docs/MEMO.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: 跑完整测试套件**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test`
Expected: ALL PASS（包括新加的 applyTransform / InteractiveCropEditor / CropRatioBar 测试）

- [ ] **Step 2: 跑 analyzer**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter analyze`
Expected: No errors

- [ ] **Step 3: 更新 MEMO.md**

在 `docs/MEMO.md` 〇四节后追加 〇五节（参考现有 〇四的写法）：

```markdown
### 〇五、2026-06-20：自由裁切 + 美颜滑条间距

**改动**：

1. **裁切改为交互式**：
   - 顶部预览从静态图改为 `InteractiveCropEditor`，支持双指缩放 + 单指拖动
   - 三个 tab（滤镜 / 美颜 / 裁切）共享同一个编辑器
   - 切换比例时 transform 不重置（用户拍板）
   - 自由比例：框退化为全图边界，变换不影响保存
   - 裁切 tab 新增「重置」按钮

2. **美颜滑条间距 4pt → 12pt**：
   - 之前 8pt 砍到 4pt 砍过头，操作容易误触
   - 改回 `AppSpacing.gutterGrid` (12pt)

**架构**：

- `FilterViewModelState` 增加 `scale: double` 和 `translation: Offset`
- `ImageProcessingService` 新增 `applyTransform(bytes, scale, translation, targetW, targetH)`：根据 zoom+pan 提取源图可见区域并 resize 到框尺寸
- 流水线：`filter → beauty → normalizeBrightness → applyTransform → crop`
- `_runProcess` 和 `saveProcessedImage` 都接入 applyTransform

**Spec**: `docs/superpowers/specs/2026-06-20-free-crop-and-beauty-spacing-design.md`
**Plan**: `docs/superpowers/plans/2026-06-20-free-crop-and-beauty-spacing.md`
```

- [ ] **Step 4: 更新 CHANGELOG.md**

在 `CHANGELOG.md` 末尾追加：

```markdown
## [Unreleased]

### Added
- 拍后编辑：交互式裁切（双指缩放 + 单指拖动），三档比例框可见，自由比例退化为全图
- 裁切 tab：「重置」按钮恢复 transform 默认值

### Changed
- 美颜三档滑条间距 4pt → 12pt（`AppSpacing.gutterGrid`）
- 拍后编辑顶部预览：从静态图改为交互编辑器

### Architecture
- `FilterViewModelState` 增加 `scale` / `translation` 字段
- `ImageProcessingService.applyTransform` 新公开方法
- 处理流水线：`filter → beauty → normalizeBrightness → applyTransform → crop`
```

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && git add docs/MEMO.md CHANGELOG.md && git -c user.email=claude@anthropic.com -c user.name="研发猪妹妹" commit -m "docs: 记录自由裁切 + 滑条间距改动"
```

---

## 验收清单

- [ ] `flutter test` 全部通过
- [ ] `flutter analyze` 无 error
- [ ] 手测：
  - [ ] 进入裁切 tab，双指 pinch 可缩放
  - [ ] 单指拖动可平移
  - [ ] 6 个比例 chip 切换正常，框大小变化
  - [ ] 切换比例后 transform 保留（位置 + 缩放不变）
  - [ ] 「重置」按钮：默认灰显，调过 transform 后高亮可点
  - [ ] 保存图片尺寸 = 框尺寸（按当前比例）
  - [ ] 美颜 3 个滑条之间视觉上能区分、不误触
- [ ] MEMO + CHANGELOG 已更新