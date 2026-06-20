# Crop Bugfix (iOS-Style Crop Editor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复裁切编辑器两个核心 bug ——（1）切换比例时图片被强制拉伸变形；（2）用户无法自由缩放/平移图片进行裁切。改造为 iOS Photos 风格：预览与裁切分离（预览=未裁切原图，保存时一次性裁切）；InteractiveViewer 允许 <1x 拉远；图片用 cover 铺满 viewport。

**Architecture:**
- **预览 / 裁切分离**：`previewBytes` 永远是"滤镜+美颜后未裁切"的原图比例；切换比例**不再**触发 `_runProcess`，只更新遮罩；保存时在 `saveProcessedImage` 内**一次性**应用 transform + 目标比例裁切。
- **`applyTransform` 重写**：取消"scale=1/translation=0 早期 resize"的逻辑，**永远**先按 scale+translation 计算源图可见矩形，crop 出来；如果指定目标比例，再在可见矩形上按比例裁切（保持原图宽高比，**不拉伸**）。
- **InteractiveCropEditor 改造**：`Image(fit: BoxFit.cover)` 让图片铺满 viewport（保持原比例，超出 viewport 部分被 clipRect 裁掉）；`minScale: 0.5` 允许拉远；InteractiveViewer 用 viewport 中心作为 transform 原点。

**Tech Stack:** Flutter 3.x + Riverpod (StateNotifier) + image 包 (img.copyCrop / copyResize) + InteractiveViewer + TransformationController

**Spec:** `docs/superpowers/specs/2026-06-20-free-crop-and-beauty-spacing-design.md`（已有的自由裁切设计；本 plan 是 bugfix，不重写 spec）

**Bug report (来自用户):**
1. 切换比例时图片被拉扯变形 —— 绝对不可以
2. 无法自由移动图片和缩放图片进行裁切 —— 参照 iOS 相册剪裁编辑

**Root cause (from systematic-debugging):**
- Bug 1：`image_processing_service.dart:284-292` `applyTransform` 在 `scale≤1 && translation==zero` 时直接 `copyResize(width:targetW, height:targetH)`，目标尺寸与原图不等时强制拉伸；同时 `filter_view_model.dart:117-120` `setCropRatio` 触发 `_runProcess` 让预览在每次切换比例时被重裁切。
- Bug 2：`interactive_crop_editor.dart:42-43` `minScale=1.0` 强制图片必须先放大才能平移；`Image(fit: BoxFit.contain)` 让 Image 渲染区域小于 viewport，触摸热区小。

---

## File Structure

| 文件 | 变更类型 | 责任 |
|---|---|---|
| `lib/services/image_processing_service.dart` | 修改 | `applyTransform` 重写：始终基于 scale+translation crop 源图可见矩形，按目标比例二次裁切，**保持原图宽高比** |
| `lib/features/filter/filter_view_model.dart` | 修改 | `setCropRatio` 不再触发 `_scheduleProcess`；`_runProcess` 不再调用 `applyTransform`；`saveProcessedImage` 在 processImage 后统一应用 transform + 裁切 |
| `lib/features/filter/widgets/interactive_crop_editor.dart` | 修改 | `minScale=0.5`；`Image(fit: BoxFit.cover)`；translation 归一化用 viewport 半尺寸 |
| `test/services/image_processing_service_test.dart` | 修改 | 补充 applyTransform 新行为测试（不拉伸） |
| `test/filter/filter_view_model_preview_test.dart` | 修改 | 补充 setCropRatio 不触发、_runProcess 不裁切、saveProcessedImage 一次性裁切测试 |
| `test/widget/interactive_crop_editor_test.dart` | 修改 | 补充 minScale / BoxFit.cover 测试 |
| `docs/MEMO.md` | 修改 | 〇五 章节记录修复 |
| `CHANGELOG.md` | 修改 | Unreleased 2026-06-20 加 bugfix 条目 |

---

## Task 1: 修复 `applyTransform` 拉伸变形（核心 bug）

**Files:**
- Modify: `lib/services/image_processing_service.dart:277-319`
- Test: `test/services/image_processing_service_test.dart`

**背景：** 当前 `applyTransform` 在 `scale≤1 && translation==Offset.zero` 时直接 `copyResize` 到 `targetWidth × targetHeight`。当目标比例 ≠ 原图比例时，`targetWidth/Height` ≠ 原图宽高，resize 强制拉伸位图。这是 Bug 1 的根因。

**新行为：**
- 永远基于 scale + translation 计算源图可见矩形（保持原图宽高比），crop 出来
- 如果指定目标比例（targetRatio ≠ null），在可见矩形上按比例二次裁切（保留原图宽高比，**不拉伸**）
- 如果 targetRatio == null（自由比例），直接返回可见矩形
- scale 范围扩展到 [0.5, 4.0]

- [ ] **Step 1: 写失败测试 —— 1:1 比例不拉伸**

在 `test/services/image_processing_service_test.dart` 添加：

```dart
test('applyTransform 1:1 比例从 4:3 原图裁出 3000x3000 不拉伸', () async {
  // 构造 4000x3000 (4:3) 的红色测试图
  final src = img.Image(width: 4000, height: 3000);
  img.fill(src, color: img.ColorRgb8(255, 0, 0));
  final bytes = Uint8List.fromList(img.encodePng(src));

  final service = ImageProcessingService();
  final out = await service.applyTransform(
    bytes,
    scale: 1.0,
    translation: Offset.zero,
    targetRatio: 1.0, // 新签名：传 targetRatio 而非 targetWidth/Height
  );

  final decoded = img.decodeImage(out)!;
  expect(decoded.width, 3000, reason: '1:1 比例应输出 3000x3000 中心裁切');
  expect(decoded.height, 3000);
});

test('applyTransform 16:9 比例从 4:3 原图裁出 5333x3000 不拉伸', () async {
  final src = img.Image(width: 4000, height: 3000);
  img.fill(src, color: img.ColorRgb8(0, 255, 0));
  final bytes = Uint8List.fromList(img.encodePng(src));

  final service = ImageProcessingService();
  final out = await service.applyTransform(
    bytes,
    scale: 1.0,
    translation: Offset.zero,
    targetRatio: 16 / 9,
  );

  final decoded = img.decodeImage(out)!;
  expect(decoded.width, 5333);
  expect(decoded.height, 3000);
});

test('applyTransform 原比例 4:3 + 目标比例 4:3 输出原尺寸', () async {
  final src = img.Image(width: 4000, height: 3000);
  img.fill(src, color: img.ColorRgb8(0, 0, 255));
  final bytes = Uint8List.fromList(img.encodePng(src));

  final service = ImageProcessingService();
  final out = await service.applyTransform(
    bytes,
    scale: 1.0,
    translation: Offset.zero,
    targetRatio: 4 / 3,
  );

  final decoded = img.decodeImage(out)!;
  expect(decoded.width, 4000);
  expect(decoded.height, 3000);
});

test('applyTransform 自由比例 (targetRatio=null) 输出按 scale/translation 决定的区域', () async {
  final src = img.Image(width: 4000, height: 3000);
  img.fill(src, color: img.ColorRgb8(255, 255, 0));
  final bytes = Uint8List.fromList(img.encodePng(src));

  final service = ImageProcessingService();
  final out = await service.applyTransform(
    bytes,
    scale: 2.0, // 中心 1/2 区域
    translation: Offset.zero,
    targetRatio: null,
  );

  final decoded = img.decodeImage(out)!;
  expect(decoded.width, 2000);
  expect(decoded.height, 1500);
});

test('applyTransform scale=0.7 拉远时不报错', () async {
  final src = img.Image(width: 4000, height: 3000);
  img.fill(src, color: img.ColorRgb8(0, 255, 255));
  final bytes = Uint8List.fromList(img.encodePng(src));

  final service = ImageProcessingService();
  final out = await service.applyTransform(
    bytes,
    scale: 0.7,
    translation: Offset.zero,
    targetRatio: 1.0,
  );

  final decoded = img.decodeImage(out)!;
  expect(decoded.width, 3000);
  expect(decoded.height, 3000);
});
```

注意：新签名是 `targetRatio: double?` 而非 `targetWidth: int, targetHeight: int`。

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test test/services/image_processing_service_test.dart -v 2>&1 | tail -40`

Expected: 编译错误（applyTransform 不接受 targetRatio）或 assertion 失败

- [ ] **Step 3: 重写 `applyTransform` 实现**

修改 `lib/services/image_processing_service.dart:277-319`，完整替换 `applyTransform` 方法为：

```dart
/// 按 scale + translation 提取源图可见区域，按目标比例二次裁切。
///
/// 参数：
/// - [scale] ∈ [0.5, 4.0]：1.0 = 全图可见；>1 放大（只显示中心区域）；<1 拉远（保留更多）
/// - [translation] ∈ [-1, 1]：相对图像中心的归一化偏移
/// - [targetRatio] == null（CropRatio.free）→ 输出按 scale/translation 决定的可见矩形，保持原图宽高比
/// - [targetRatio] != null → 在可见矩形上按目标宽高比二次裁切，保持原图宽高比（**不拉伸**）
Future<Uint8List> applyTransform(
  Uint8List imageBytes, {
  required double scale,
  required Offset translation,
  required double? targetRatio,
}) async {
  final image = img.decodeImage(imageBytes);
  if (image == null) return imageBytes;

  final srcW = image.width;
  final srcH = image.height;
  final s = scale.clamp(0.5, 4.0);

  // 1) 计算"可见区域"在源图中的矩形（按原图宽高比）
  final visibleW = (srcW / s).round();
  final visibleH = (srcH / s).round();

  // 2) translation 偏移中心
  final tx = translation.dx.clamp(-1.0, 1.0);
  final ty = translation.dy.clamp(-1.0, 1.0);
  var cx = (srcW / 2.0 - tx * srcW).round();
  var cy = (srcH / 2.0 - ty * srcH).round();

  // 3) clamp 到源图边界
  final halfW = visibleW ~/ 2;
  final halfH = visibleH ~/ 2;
  cx = cx.clamp(halfW, srcW - halfW);
  cy = cy.clamp(halfH, srcH - halfH);

  final x = cx - halfW;
  final y = cy - halfH;
  final visible = img.copyCrop(image, x: x, y: y, width: visibleW, height: visibleH);

  // 4) 如果没有目标比例，直接返回可见区域
  if (targetRatio == null) {
    return Uint8List.fromList(img.encodePng(visible));
  }

  // 5) 在可见区域上按目标比例二次裁切（保持原图宽高比，**不拉伸**）
  final vW = visible.width;
  final vH = visible.height;
  final currentRatio = vW / vH;

  int finalW;
  int finalH;
  if ((currentRatio - targetRatio).abs() < 0.001) {
    // 等比
    return Uint8List.fromList(img.encodePng(visible));
  } else if (currentRatio > targetRatio) {
    // visible 比目标宽 → 裁左右
    finalH = vH;
    finalW = (vH * targetRatio).round();
  } else {
    // visible 比目标窄（更竖）→ 裁上下
    finalW = vW;
    finalH = (vW / targetRatio).round();
  }

  final fx = (vW - finalW) ~/ 2;
  final fy = (vH - finalH) ~/ 2;
  final cropped = img.copyCrop(visible, x: fx, y: fy, width: finalW, height: finalH);
  return Uint8List.fromList(img.encodePng(cropped));
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test test/services/image_processing_service_test.dart -v 2>&1 | tail -40`

Expected: 5 个新测试全部 PASS

- [ ] **Step 5: 跑完整测试套件确认没有回归**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test 2>&1 | tail -20`

Expected: 旧 applyTransform 测试可能失败（因为签名变了：targetWidth/Height → targetRatio），记下失败用例，下一个任务会修复 ViewModel

- [ ] **Step 6: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/services/image_processing_service.dart test/services/image_processing_service_test.dart
git commit -m "fix(service): applyTransform 改为按比例裁切，不拉伸位图

重构 applyTransform 签名：移除 targetWidth/Height，新增 targetRatio（可为 null 表示自由比例）。
新行为：
- 始终基于 scale + translation crop 源图可见矩形，保持原图宽高比
- 指定 targetRatio 时在可见矩形上按比例二次裁切，**不拉伸**位图
- scale 范围扩展到 [0.5, 4.0]，允许拉远查看全图

修复 Bug：4:3 原图切 1:1 时不再被强制 resize 成 3000x3000 方形，而是按 1:1 中心裁出 3000x3000 自然比例区域。"
```

---

## Task 2: ViewModel 调用方适配新签名 + `setCropRatio` 不再触发预览

**Files:**
- Modify: `lib/features/filter/filter_view_model.dart:117-120, 162-209, 211-256`
- Test: `test/filter/filter_view_model_preview_test.dart`

**背景：** applyTransform 签名变了（移除 targetWidth/Height，新增 targetRatio），ViewModel 调用方需要适配。同时 `setCropRatio` 不再触发 `_runProcess`（预览 = 未裁切图，比例只改遮罩），`_runProcess` 不再调用 applyTransform。

- [ ] **Step 1: 写失败测试 —— `setCropRatio` 不触发 `_runProcess`**

在 `test/filter/filter_view_model_preview_test.dart` 添加：

```dart
test('setCropRatio 切换比例不触发 applyTransform (预览保持原图)', () async {
  // 准备
  final processing = _CapturingProcessingService();
  final writer = _StubPhotoAlbumWriter();
  final repo = _StubAppPhotoRepository();
  final vm = FilterViewModel(processing, writer, repo);
  await vm.setImage('/test/path.png');

  processing.applyTransformCallCount = 0; // 重置计数

  // 切到 1:1
  vm.setCropRatio(CropRatio.ratio_1_1);
  await Future.delayed(const Duration(milliseconds: 300)); // 等 debounce + 处理

  expect(processing.applyTransformCallCount, 0,
      reason: 'setCropRatio 不应触发 applyTransform（预览保持未裁切原图）');
});
```

需要确认 `_CapturingProcessingService` 类已经在测试文件里。如果存在 `applyTransformCallCount` 字段但当前是 `int`，直接用即可。

- [ ] **Step 2: 写失败测试 —— `_runProcess` 不调用 `applyTransform`**

```dart
test('_runProcess 不调用 applyTransform (预览只跑滤镜+美颜)', () async {
  final processing = _CapturingProcessingService();
  final writer = _StubPhotoAlbumWriter();
  final repo = _StubAppPhotoRepository();
  final vm = FilterViewModel(processing, writer, repo);
  await vm.setImage('/test/path.png');
  await Future.delayed(const Duration(milliseconds: 300));

  expect(processing.applyTransformCallCount, 0,
      reason: '_runProcess 只跑滤镜+美颜，不做裁切');
});
```

- [ ] **Step 3: 写失败测试 —— `saveProcessedImage` 调用 `applyTransform` 用新签名**

```dart
test('saveProcessedImage 在 1:1 比例下输出 3000x3000 (不拉伸 4000x3000 原图)', () async {
  final processing = _RealProcessingService(); // 用真实 service 跑
  final writer = _StubPhotoAlbumWriter();
  final repo = _StubAppPhotoRepository();

  // 构造 4000x3000 测试图
  final src = img.Image(width: 4000, height: 3000);
  img.fill(src, color: img.ColorRgb8(255, 0, 0));
  final testPath = '${Directory.systemTemp.path}/test_4000x3000.png';
  File(testPath).writeAsBytesSync(Uint8List.fromList(img.encodePng(src)));

  final vm = FilterViewModel(processing, writer, repo);
  await vm.setImage(testPath);
  await Future.delayed(const Duration(milliseconds: 300));

  vm.setCropRatio(CropRatio.ratio_1_1);
  await Future.delayed(const Duration(milliseconds: 300));

  // 拦截 saveImage 抓输出
  Uint8List? savedBytes;
  writer.onSave = (bytes, filename) async {
    savedBytes = bytes;
  };

  await vm.saveProcessedImage();

  expect(savedBytes, isNotNull);
  final out = img.decodeImage(savedBytes!)!;
  expect(out.width, 3000, reason: '1:1 比例应输出 3000x3000');
  expect(out.height, 3000);

  // 清理
  File(testPath).deleteSync();
});
```

注意：`saveProcessedImage` 内部用 `state.previewBytes` 作为起点（已包含滤镜+美颜），但不再裁切。所以保存时仍然需要把 transform + 比例应用上去。

可能需要临时创建 `_RealProcessingService`（直接用 `ImageProcessingService()`），不需要 mock。`_StubPhotoAlbumWriter` 当前是否存在 `onSave` 回调字段？如果没有，要么扩展 stub，要么用 `verify` mock。

查看现有 stub 设计：
```dart
class _StubPhotoAlbumWriter extends PhotoAlbumWriter {
  // ... 现有 stub 实现
}
```

如果 `saveImage` 内部直接调用 `PhotoAlbumWriter.saveImage`（用 platform channel），可能需要 mock platform channel。或者 stub 覆盖 `saveImage`。

**简化方法：** 直接 verify `PhotoAlbumWriter.saveImage` 被调用时的 bytes 参数。如果 stub 已有可注入字段 `lastSavedBytes` 就用它；否则用 `Mock` from `mocktail`（如果项目已用）或者注入 `void Function(Uint8List)? onSave`。

**推荐方法：** 直接给 `_StubPhotoAlbumWriter` 加 `Uint8List? lastSavedBytes` 字段，`saveImage` 内部 `lastSavedBytes = bytes`。

- [ ] **Step 4: 跑测试确认失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test test/filter/filter_view_model_preview_test.dart -v 2>&1 | tail -50`

Expected: 3 个新测试失败（setCropRatio 仍然触发 applyTransform；_runProcess 仍然调用 applyTransform；saveProcessedImage 编译错误因为签名变了）

- [ ] **Step 5: 修改 `setCropRatio` 不再触发预览**

修改 `lib/features/filter/filter_view_model.dart:117-120`：

```dart
void setCropRatio(CropRatio ratio) {
  state = state.copyWith(cropRatio: ratio);
  // 不再触发 _runProcess：预览 = 未裁切原图，比例切换只改遮罩
}
```

- [ ] **Step 6: 修改 `_runProcess` 移除 applyTransform**

修改 `lib/features/filter/filter_view_model.dart:186-202`（删除裁切 + transform 整块）：

```dart
    var processed = await _processingService.processImage(
      origBytes,
      filter: state.selectedFilter,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
    );

    // 预览只跑滤镜+美颜，不再做裁切；裁切 + transform 只在 saveProcessedImage 内执行

    if (!mounted) return;
    state = state.copyWith(
      previewBytes: processed,
      isPreviewProcessing: false,
    );
```

- [ ] **Step 7: 修改 `saveProcessedImage` 用新签名调用 applyTransform**

修改 `lib/features/filter/filter_view_model.dart:226-242`（保留裁切 + transform 块，但调用新签名）：

```dart
    // 裁切 + transform（自由比例 = 不裁切）
    final ratio = state.cropRatio;
    if (ratio != CropRatio.free && bytes != null) {
      bytes = await _processingService.applyTransform(
        bytes,
        scale: state.scale,
        translation: state.translation,
        targetRatio: ratio.ratio,
      );
    } else if (ratio == CropRatio.free && state.scale != 1.0 && bytes != null) {
      // 自由比例 + 用户缩放了 → 应用 scale (但不需要按比例裁切)
      bytes = await _processingService.applyTransform(
        bytes,
        scale: state.scale,
        translation: state.translation,
        targetRatio: null,
      );
    }
```

注意：自由比例下即使 scale=1.0 translation=Offset.zero 也不需要处理。如果用户缩放过（scale != 1.0），就按可见区域裁切。

实际上自由比例应该**永远**应用 transform（即使 scale=1.0）：如果用户平移过（translation != Offset.zero），也应该 crop。简化处理：自由比例下只要 scale != 1.0 或 translation != Offset.zero 就应用 transform：

```dart
} else if (ratio == CropRatio.free && bytes != null &&
    (state.scale != 1.0 || state.translation != Offset.zero)) {
  bytes = await _processingService.applyTransform(
    bytes,
    scale: state.scale,
    translation: state.translation,
    targetRatio: null,
  );
}
```

需要 import `dart:ui' show Offset`（已经存在）。

- [ ] **Step 8: 跑 ViewModel 测试确认通过**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test test/filter/filter_view_model_preview_test.dart -v 2>&1 | tail -50`

Expected: 3 个新测试 PASS，旧测试也通过（之前旧测试可能调用过 setCropRatio 后 applyTransformCallCount > 0，现在需要更新断言）

- [ ] **Step 9: 跑完整测试套件**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test 2>&1 | tail -20`

Expected: 全部通过

- [ ] **Step 10: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/features/filter/filter_view_model.dart test/filter/filter_view_model_preview_test.dart
git commit -m "fix(filter): 预览/裁切分离，切换比例不重裁切预览

ViewModel 改造：
- setCropRatio 不再触发 _runProcess，预览 = 未裁切原图
- _runProcess 只跑滤镜+美颜，不再调用 applyTransform
- saveProcessedImage 统一应用 transform + 比例裁切（targetRatio 签名）

修复 Bug：切换比例时预览图被强制重裁切造成视觉跳变。"
```

---

## Task 3: InteractiveCropEditor `minScale=0.5` 允许拉远

**Files:**
- Modify: `lib/features/filter/widgets/interactive_crop_editor.dart:42-43, 74-88`
- Test: `test/widget/interactive_crop_editor_test.dart`

- [ ] **Step 1: 写失败测试 —— `minScale=0.5`**

在 `test/widget/interactive_crop_editor_test.dart` 添加：

```dart
testWidgets('InteractiveCropEditor minScale 为 0.5（允许拉远）', (tester) async {
  // 用真实 ImageProcessingService 跑一张 1x1 测试图，构造 previewBytes
  final src = img.Image(width: 1, height: 1);
  final bytes = Uint8List.fromList(img.encodePng(src));

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 300,
        child: InteractiveCropEditor(
          previewBytes: bytes,
          imagePath: null,
          cropRatio: CropRatio.ratio_1_1,
          scale: 0.5,
          translation: Offset.zero,
          onTransformChanged: (_, __) {},
        ),
      ),
    ),
  ));
  await tester.pump();

  final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
  expect(viewer.minScale, 0.5);
  expect(viewer.maxScale, 4.0);
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test test/widget/interactive_crop_editor_test.dart -v 2>&1 | tail -30`

Expected: FAIL（当前 minScale=1.0）

- [ ] **Step 3: 修改 `minScale = 0.5`**

修改 `lib/features/filter/widgets/interactive_crop_editor.dart:42-43`：

```dart
  static const _minScale = 0.5;
  static const _maxScale = 4.0;
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test test/widget/interactive_crop_editor_test.dart -v 2>&1 | tail -30`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/features/filter/widgets/interactive_crop_editor.dart test/widget/interactive_crop_editor_test.dart
git commit -m "feat(filter): InteractiveCropEditor minScale 改为 0.5

允许用户双指缩小到 0.5x 拉远查看全图，符合 iOS 裁切语义。"
```

---

## Task 4: InteractiveCropEditor 改用 `BoxFit.cover`

**Files:**
- Modify: `lib/features/filter/widgets/interactive_crop_editor.dart:104, 106, 80-86`
- Test: `test/widget/interactive_crop_editor_test.dart`

- [ ] **Step 1: 写失败测试 —— Image 用 BoxFit.cover**

在 `test/widget/interactive_crop_editor_test.dart` 添加：

```dart
testWidgets('InteractiveCropEditor 内 Image 用 BoxFit.cover 铺满', (tester) async {
  final src = img.Image(width: 1, height: 1);
  final bytes = Uint8List.fromList(img.encodePng(src));

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 300,
        child: InteractiveCropEditor(
          previewBytes: bytes,
          imagePath: null,
          cropRatio: CropRatio.ratio_1_1,
          scale: 1.0,
          translation: Offset.zero,
          onTransformChanged: (_, __) {},
        ),
      ),
    ),
  ));
  await tester.pump();

  // 找到 InteractiveViewer 内的 Image
  final images = tester.widgetList<Image>(find.descendant(
    of: find.byType(InteractiveViewer),
    matching: find.byType(Image),
  ));
  expect(images, isNotEmpty);
  // 找到非 painter 用的 Image（RawImage/Image.memory）
  final coverImages = images.where((img) => img.fit == BoxFit.cover);
  expect(coverImages.length, greaterThan(0),
      reason: 'Image 应该用 BoxFit.cover 铺满 viewport 而非 contain');
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test test/widget/interactive_crop_editor_test.dart -v 2>&1 | tail -30`

Expected: FAIL（当前 fit=BoxFit.contain）

- [ ] **Step 3: 修改 Image 的 `fit` 为 `BoxFit.cover`**

修改 `lib/features/filter/widgets/interactive_crop_editor.dart:104` 和 `106`：

```dart
                  ? Image.memory(widget.previewBytes!, fit: BoxFit.cover)
                  : (widget.imagePath != null
                      ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                      : const SizedBox.shrink()),
```

- [ ] **Step 4: 调整 translation 归一化基准**

修改 `lib/features/filter/widgets/interactive_crop_editor.dart:80-86`，让 translation 归一化用 viewport 半尺寸：

```dart
  void _onInteractionEnd() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final m = _ctrl.value;
      final s = m.getMaxScaleOnAxis().clamp(_minScale, _maxScale);
      final tx = m.getTranslation().x;
      final ty = m.getTranslation().y;
      final size = context.size ?? const Size(300, 300);
      // 用 viewport 半尺寸归一化：translation = size.width/2 时 ntx=1
      final ntx = size.width > 0 ? (tx / (size.width / 2)).clamp(-1.0, 1.0) : 0.0;
      final nty = size.height > 0 ? (ty / (size.height / 2)).clamp(-1.0, 1.0) : 0.0;
      widget.onTransformChanged(s, Offset(ntx, nty));
    });
  }
```

注意：因为现在用 BoxFit.cover，图片渲染尺寸可能超出 viewport。InteractiveViewer 的 `getTranslation()` 返回的是 child 中心相对 viewport 中心的实际像素偏移。

- [ ] **Step 5: 跑测试确认通过**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test test/widget/interactive_crop_editor_test.dart -v 2>&1 | tail -30`

Expected: PASS

- [ ] **Step 6: 跑完整测试套件确认没有回归**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test 2>&1 | tail -20`

Expected: 全部通过

- [ ] **Step 7: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/features/filter/widgets/interactive_crop_editor.dart test/widget/interactive_crop_editor_test.dart
git commit -m "feat(filter): InteractiveCropEditor 用 BoxFit.cover + viewport 半尺寸归一化

- Image fit 从 BoxFit.contain 改为 BoxFit.cover：图片铺满 viewport（保持原比例，超出部分被 ClipRect 裁掉）
- translation 归一化用 viewport 半尺寸：scale 大时能拖出裁切框外（露出黑色），符合 iOS 裁切语义

修复 Bug：图片不再 contain 在 viewport 内有黑边导致触摸热区小；用户可以拖出裁切框查看。"
```

---

## Task 5: 同步文档

**Files:**
- Modify: `docs/MEMO.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: 更新 MEMO.md 〇五 章节**

在 `/Users/partical/Documents/_vibeCoding/easyBeautyCam/docs/MEMO.md` 〇五 章节末尾追加：

```markdown
### 〇五-2 bugfix (2026-06-20)

修复裁切编辑器两个 bug：

1. **切换比例图片被拉扯变形** —— `applyTransform` 重写为"按比例裁切保持原图宽高比"，不再强制 resize；ViewModel `setCropRatio` 不再触发预览重裁切（预览 = 未裁切原图）
2. **无法自由缩放/平移** —— InteractiveCropEditor `minScale` 从 1.0 改为 0.5；Image `fit` 从 `BoxFit.contain` 改为 `BoxFit.cover`；translation 归一化用 viewport 半尺寸

修复后行为对齐 iOS Photos 裁切编辑器：
- 预览 = 滤镜处理后未裁切图，比例切换只改遮罩
- 双指缩放范围 [0.5, 4.0]，单指可拖出裁切框边界（露出黑色遮罩）
- 保存时一次性按 transform + 目标比例裁切，输出保持原图宽高比
```

- [ ] **Step 2: 更新 CHANGELOG.md**

在 `/Users/partical/Documents/_vibeCoding/easyBeautyCam/CHANGELOG.md` Unreleased 2026-06-20 段落追加：

```markdown
- **fix(filter)**: 裁切编辑器对齐 iOS 风格
  - 切换比例时图片不再被强制拉伸（applyTransform 改为按比例裁切）
  - 切换比例不再触发预览重裁切（setCropRatio 仅改遮罩）
  - InteractiveCropEditor 允许 <1x 拉远（minScale=0.5）
  - 图片用 BoxFit.cover 铺满 viewport，触摸热区更大
```

- [ ] **Step 3: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add docs/MEMO.md CHANGELOG.md
git commit -m "docs: 记录裁切编辑器 iOS 风格 bugfix"
```

---

## Task 6: 推送 GitHub

- [ ] **Step 1: 跑全部测试**

Run: `cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && fvm flutter test 2>&1 | tail -5`

Expected: All tests passed

- [ ] **Step 2: 推送**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git push origin main
```

Expected: 5 个新提交推送到 main

---

## Self-Review Checklist

- [x] Spec coverage: Bug 1（拉伸）→ Task 1 + 2；Bug 2（无法自由缩放/移动）→ Task 3 + 4
- [x] Placeholder scan: 无 "TBD" / "TODO" / "类似"；所有代码块完整
- [x] Type consistency: `applyTransform` 新签名 `targetRatio: double?` 在 Task 1 定义、在 Task 2 调用；`CropRatio` enum 不变；`Offset` 类型导入一致

---

## 备注

- 测试可能需要先查看现有 stub 实现（`_CapturingProcessingService`、`_StubPhotoAlbumWriter` 等）的字段，必要时扩展 stub 而非换框架
- `_StubAppPhotoRepository` 当前是否实现 `add` 方法？需要确认 stub 完整
- InteractiveCropEditor widget 测试中 `find.byType(InteractiveViewer)` 是否能找到（被 `ClipRect + Stack` 包裹）；如果找不到，可能需要 `find.byKey` 或调整 finder
- Task 2 的"自由比例 + 用户缩放过"分支是新增功能，但 iOS 自由比例下也允许用户缩放裁切——符合 spec 隐含语义
