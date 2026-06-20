# Filter Panel Fullscreen + Crop Redesign Design

**Date:** 2026-06-20
**Author:** Claude (via brainstorming with user)
**Status:** Approved
**Spec for:** `easyBeautyCam` Flutter camera app

## Background & Motivation

拍完照后的编辑面板 (`FilterPanel`) 当前用 `showModalBottomSheet` 弹出，约占屏幕 50% 高度（其他 50% 还是相机预览）。当前存在三个 UX 问题：

1. **编辑空间受限**：底部 BottomSheet 上半部分仍是相机预览，编辑区视觉上"挤在屏幕下半"
2. **摄像头在后台运行**：编辑期间相机仍在采集/预览，浪费电且可能发热
3. **裁切 tab UI 不够直观**：
   - "自由" 名字含义模糊（用户不清楚"自由" = 不裁切 vs 自由调整）
   - 比例 chip 只有文字，没有图示（iOS 风格有矩形宽高比图标）
   - 重置按钮和比例 chip 视觉差异不够大

iOS 相册剪裁编辑提供参考：进入编辑 = 全屏覆盖 + 工具栏 + 实时预览；退出 = 返回相册原页。

## Goals

1. 编辑面板全屏覆盖相机预览
2. 编辑期间暂停摄像头预览（释放后台资源）
3. 裁切 UI 符合 iOS 习惯：清晰的比例图示 + 明确的重置入口 + 直观的"原图"选项
4. 切换比例时图片不被拉伸（沿用前次 fix）
5. 自由缩放/平移进行裁切（沿用前次 fix）

## Non-Goals

- 不重做相机页布局
- 不重做美颜/滤镜算法
- 不改动照片保存流程（路径、命名、app grid 写入）
- 不增加新的裁切比例

## Design

### 1. 全屏弹框 + 摄像头开关

**`camera_screen.dart` 调用方改造**：

```dart
Future<void> _capture(CameraViewModel notifier) async {
  _flashController.forward(from: 0);
  unawaited(SystemSound.play(SystemSoundType.click));

  final path = await notifier.takePicture();
  if (path != null && mounted) {
    ref.read(filterViewModelProvider.notifier).setImage(path);
    // 暂停相机预览（CameraController 实例保留，释放后台采集）
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
      // 处理保存
      if (savedPath != null) {
        // 已有逻辑：刷新相册等（如有）
      }
    }
  }
}
```

**`camera_service.dart` 新增方法**：

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

**`filter_panel.dart` 改造**：

- 删除 `Container(decoration: BoxDecoration(color: AppColors.overlayBg, borderRadius: AppRadii.sheetTop))` 的圆角 sheet 容器
- 顶层改为 `Scaffold(backgroundColor: AppColors.overlayBg, body: SafeArea(child: Column(...)))`
- 删除拖动条（`SizedBox(height: AppSpacing.sm) + Container(width: 36, height: 4, ...)`），全屏不需要
- 顶部栏保留：取消 / "编辑" / 保存
- 底部 TabBarView 高度保持 150
- 中间预览区高度从 `MediaQuery * 0.38` 改为 `Expanded`（占满中间所有空间）

### 2. 「原图」替代「自由」

**`image_processing_service.dart` enum 改动**：

```dart
enum CropRatio {
  original,  // 替代 free：保持原图比例，按 transform 提取可见区域
  ratio_16_9,
  ratio_4_3,
  ratio_1_1,
  ratio_3_4,
  ratio_9_16,
}

extension CropRatioX on CropRatio {
  double? get ratio {
    switch (this) {
      case CropRatio.original:
        return null;  // 自由裁切 = 按 transform 提取
      case CropRatio.ratio_16_9: return 16 / 9;
      case CropRatio.ratio_4_3:  return 4 / 3;
      case CropRatio.ratio_1_1:  return 1.0;
      case CropRatio.ratio_3_4:  return 3 / 4;
      case CropRatio.ratio_9_16: return 9 / 16;
    }
  }

  String get label {
    switch (this) {
      case CropRatio.original:   return '原图';
      case CropRatio.ratio_16_9: return '16:9';
      case CropRatio.ratio_4_3:  return '4:3';
      case CropRatio.ratio_1_1:  return '1:1';
      case CropRatio.ratio_3_4:  return '3:4';
      case CropRatio.ratio_9_16: return '9:16';
    }
  }
}
```

**`filter_view_model.dart` 默认值改动**：

```dart
const FilterViewModelState({
  ...
  this.cropRatio = CropRatio.original,  // 替代 free
  ...
});
```

`saveProcessedImage` 中对应分支改名：
```dart
if (ratio != CropRatio.original) {
  bytes = await _processingService.applyTransform(
    bytes,
    scale: state.scale,
    translation: state.translation,
    targetRatio: ratio.ratio,
  );
} else if (state.scale != 1.0 || state.translation != Offset.zero) {
  // 原图 + 用户缩放/平移过 → 按可见区域裁切
  bytes = await _processingService.applyTransform(
    bytes,
    scale: state.scale,
    translation: state.translation,
    targetRatio: null,
  );
}
```

### 3. 比例图示（CustomPainter 矩形 + 文字）

**chip 结构**（替代现在的"文字-only chip"）：

```
┌─────────────┐
│   ┌─┐       │  ← 矩形图示（按比例显示宽高，1.5pt AppColors.primary 边框）
│   │ │  16:9 │  ← 文字
│   └─┘       │
└─────────────┘
```

**实现**：`CropRatioBar` 用 `CustomPaint` 画矩形。每个 chip 是一个固定宽度 64pt 的 column：
- 上半部分（高 28）：按比例的矩形（用 `AspectRatio` 包裹或直接 CustomPainter）
- 下半部分（高 16）：比例文字

"原图" chip 的矩形：宽高 1:1（方形），但加个 "Original" 或 "原图" 文字标签——视觉上和数字比例区分（用户一看就知道"原图" = 不裁切）。

### 4. 重置按钮：图标 + 放在比例行最右侧

**位置变更**：从「重置 chip + 6 个比例 chip」改为「6 个比例 chip + 重置图标按钮」。

**重置按钮**：
- 圆形 IconButton（`Icons.refresh`）
- 直径 32pt
- enabled（transform 不为默认）时：实色 `AppColors.primary`
- disabled 时：`AppColors.onSurfaceVariant` 半透明
- 放在 `CropRatioBar` 行的最右侧

**比例 chip 视觉保持**：实色边框 + 实色背景（选中）/ 浅灰背景（未选中）

视觉差异通过**位置和样式双重区分**：
- 比例 chip：矩形 + 文字 + 实色边框
- 重置：圆形 + 图标 + 无边框

### 5. 状态栏/安全区

全屏后：
- 顶部 SafeArea 处理刘海
- 底部 SafeArea 处理 home indicator
- 取消/保存按钮在 SafeArea 内

## Files to Modify

| 文件 | 变更 |
|---|---|
| `lib/services/camera_service.dart` | 新增 `pausePreview()` + `resumePreview()` |
| `lib/services/image_processing_service.dart` | `CropRatio.free` → `CropRatio.original`，label '原图' |
| `lib/features/filter/filter_view_model.dart` | 默认 `cropRatio = CropRatio.original`；saveProcessedImage 分支改名 |
| `lib/features/filter/filter_panel.dart` | 改全屏布局（删除 sheet 圆角 + 拖动条，预览区 Expanded） |
| `lib/features/filter/widgets/crop_ratio_bar.dart` | chip 加矩形图示；重置改图标按钮放最右侧 |
| `lib/features/camera/camera_screen.dart` | `showModalBottomSheet` → `Navigator.push`；前后 pause/resume |

## Tests

### CameraService
- `pausePreview()` 在 controller 未初始化时静默返回
- `pausePreview()` 在已初始化时调用底层 `pausePreview`
- `resumePreview()` 同上
- 模拟老版本 camera 包没 API：try/catch 不抛

### ImageProcessingService
- `CropRatio.original.ratio` 返回 `null`
- `CropRatio.original.label` 返回 `'原图'`
- `applyTransform(targetRatio: null)` 在 `CropRatio.original` + scale!=1 时按可见区域裁切

### FilterViewModel
- 默认 `cropRatio = CropRatio.original`
- `setCropRatio(CropRatio.ratio_1_1)` 不触发 applyTransform（已有测试）
- `saveProcessedImage` 在 `cropRatio = original` + scale=2 时调用 applyTransform(targetRatio: null)

### FilterPanel widget
- 全屏布局：顶层 Scaffold，无 sheet 圆角/拖动条
- 预览区使用 Expanded
- 中间 TabBarView 仍存在

### CropRatioBar widget
- 渲染 6 个比例 chip（含原图）+ 1 个重置图标按钮
- 重置按钮位置：行最右侧
- 重置按钮 enabled 状态：scale != 1.0 || translation != Offset.zero 时启用

### CameraScreen integration
- `_capture` 调 `cameraService.pausePreview()` 后 push FilterPanel
- push 完成后 `cameraService.resumePreview()`

## Out of Scope

- 不重做相机页 UI
- 不改美颜滑条间距（已修）
- 不改图片保存路径/格式
- 不增加新比例
- 不改 `applyTransform` 内部算法

## Risks

1. **pausePreview 兼容性**：老版本 `camera` 包可能没这 API → 用 try/catch 兜底
2. **iOS 上 Navigator.push fullscreenDialog 体验**：iOS 风格从右滑入，符合 iOS 习惯；Android 上是普通页面切换，无明显问题
3. **CropRatio 重命名破坏外部状态**：如果用户旧版本保存了 `cropRatio = free` 到相册元数据（实际上没有），会有问题。但当前没存这个状态到外部，OK。
