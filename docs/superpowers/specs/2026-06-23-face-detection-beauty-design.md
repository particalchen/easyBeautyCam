# 人脸识别美颜 设计

> **For agentic workers:** 后续实现请走 writing-plans → subagent-driven-development 流程。

**Date:** 2026-06-23
**Status:** Awaiting user review
**Research:** [`../research/2026-06-23-face-beauty-research.md`](../research/2026-06-23-face-beauty-research.md)

---

## 1. 背景与目标

### 1.1 现状
- `ImageProcessingService.applyBeauty` 对**整张图**做磨皮（高斯模糊 + blend）和美白（亮度 +adjust）
- 副作用：背景也被磨皮 / 提亮，照片整体失真
- 磨皮滑到 100 时背景纹理也被平滑掉（明显的「油画感」）
- 美白对蓝天、夜景等场景也会异常提亮

### 1.2 目标
- **人脸检测**（静态图，ML Kit Face Detection）
- **按人脸区域 mask 美颜处理**（磨皮 + 美白都只在人脸像素生效）
- 眼睛 / 嘴唇等关键区域**不被磨皮**（保留细节）
- 检测不到人脸时**无美颜回退**（保持原图预览，不全图美颜）
- **性能可接受**：4K 图单次检测 + 美颜 < 1.5s（实时预览 200ms debounce 后用户不感知卡顿）

### 1.3 非目标
- 不做瘦脸算法（slim 当前是 stub，保留）
- 不做肤色调整（美白 = 亮度提亮已足够）
- 不做人脸关键点编辑（贴纸 / 滤镜 / 变形等）
- 不支持视频 / 实时美颜（仅静态图）
- 不支持批量图片

---

## 2. 设计

### 2.1 核心思路

引入人脸检测 + 区域 mask 机制，把 `applyBeauty` 改为接受 `img.Image` mask：
- mask 的像素值 ∈ [0, 1]（8-bit 灰度足够）：0 = 不处理，255 = 完全处理
- 磨皮时只在 mask > 0 的像素上做 blend
- 美白时只在 mask > 0 的像素上 +adjust

检测结果用图像 hash 缓存：**同一张图不重复检测**，避免滑杆拖动时反复检测拖慢性能。

### 2.2 组件架构

```
[User changes beauty slider (smooth / whiten)]
    ↓
FilterViewModel.setSmooth / setWhiten
    ↓
[200ms debounce] _runProcess
    ↓
1. readOriginalBytes() → Uint8List (cached)
    ↓
2. applyFilter(bytes, filter) → filteredBytes (全图滤镜)
    ↓
3. FaceDetectionService.detect(filteredBytes)
   - 命中 cache（按 imagePath 或 bytes hash）→ 返回缓存的 Face[]
   - 未命中 → 调 ML Kit → 缓存
    ↓
4. FaceMaskBuilder.buildMask(imageSize, faces) → img.Image mask
   - 用 face.contours[FaceContourType.face] 整脸椭圆点集 fillPolygon
   - 高斯羽化 mask 边缘（避免硬边）
   - 排除 eye / lip 区域（用 face.contours[FaceContourType.leftEye/rightEye/lipUpper/lipLower]）
    ↓
5. applyBeauty(filteredBytes, smooth, whiten, slim, mask) → bytes
   - smooth: 只在 mask > 0 的像素 blend
   - whiten: 只在 mask > 0 的像素 +adjust
    ↓
6. applyTransform + normalizeBrightness → finalBytes
    ↓
7. previewBytes = finalBytes
```

### 2.3 新增组件

#### 2.3.1 `lib/services/face_detection_service.dart`

```dart
class FaceDetectionService {
  final FaceDetector _detector;
  final Map<String, List<Face>> _cache = {};  // key = imagePath

  FaceDetectionService()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: true,
            enableLandmarks: false,
            performanceMode: FaceDetectorMode.fast,
            enableClassification: false,
            enableTracking: false,
            minFaceSize: 0.15,
          ),
        );

  /// 检测人脸（静态图，bytes or 文件路径）
  /// 返回的 Face 列表含 contours（用于 mask 构建）
  Future<List<Face>> detect(String imagePath, {Uint8List? bytes});

  /// 释放资源
  void dispose();
}
```

**缓存策略**：
- key = `imagePath`（照片编辑场景，每张照片唯一）
- 缓存上限 10 张（LRU 简单实现）
- ViewModel 切换 `setImage(path)` 时清空缓存（避免内存泄漏）

#### 2.3.2 `lib/services/face_mask_builder.dart`

```dart
class FaceMaskBuilder {
  /// 把人脸 contours 转成 mask image
  /// - imageSize: 原图尺寸
  /// - faces: ML Kit 检测结果
  /// - featherRadius: mask 边缘高斯羽化半径（默认 8pt）
  /// - excludeEyesLips: 是否排除眼睛/嘴唇（默认 true）
  img.Image buildMask(
    Size imageSize, {
    required List<Face> faces,
    int featherRadius = 8,
    bool excludeEyesLips = true,
  });
}
```

**算法**：
1. 创建 `img.Image(width: imageSize.w, height: imageSize.h, numChannels: 1)` 全 0
2. 对每个 face：
   - 取 `face.contours[FaceContourType.face]` 整脸点集 → `fillPolygon` 255
   - 如果 `excludeEyesLips`：`fillPolygon` 眼/唇轮廓 0（覆盖在前面画的 255 上）
3. `img.gaussianBlur(mask, radius: featherRadius)` 羽化边缘
4. 返回 mask

#### 2.3.3 修改 `lib/services/image_processing_service.dart`

`applyBeauty` 新增 `mask` 参数：

```dart
Future<Uint8List> applyBeauty(
  Uint8List imageBytes, {
  double smooth = 30,
  double whiten = 20,
  double slim = 0,
  img.Image? mask,  // null = 跳过美颜（不处理）
}) async {
  // 无 mask = 跳过美颜处理（per Q4 默认：检测不到人脸时无美颜回退）
  if (mask == null) return imageBytes;
  ...
  if (smooth > 0) {
    final blurred = img.gaussianBlur(result, radius: radius);
    final blendFactor = smooth / 500;
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final m = mask.getPixel(x, y).r / 255.0;
        if (m <= 0) continue;  // 跳过非人脸像素
        final orig = result.getPixel(x, y);
        final blur = blurred.getPixel(x, y);
        final localBlend = blendFactor * m;  // ← 边缘羽化
        result.setPixelRgba(x, y,
          ((orig.r * (1 - localBlend) + blur.r * localBlend)).round(),
          ...);
      }
    }
  }
  if (whiten > 0) {
    final adjust = (whiten / 100 * 30).round();
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final m = mask.getPixel(x, y).r / 255.0;
        if (m <= 0) continue;
        final p = result.getPixel(x, y);
        result.setPixelRgba(x, y,
          (p.r + (adjust * m).round()).clamp(0, 255),  // ← 羽化
          ...);
      }
    }
  }
  ...
}
```

`processImage` 透传 `mask` 到 `applyBeauty`。

#### 2.3.4 修改 `lib/features/filter/filter_view_model.dart`

```dart
class FilterViewModel extends StateNotifier<FilterViewModelState> {
  final FaceDetectionService _faceDetector;
  // ... 已有 deps

  Future<void> _runProcess() async {
    if (state.imagePath == null) return;
    final originalBytes = await _readOriginalBytes();
    final filterApplied = await _processing.applyFilter(originalBytes, state.selectedFilter);
    final faces = await _faceDetector.detect(state.imagePath!, bytes: filterApplied);
    final mask = faces.isEmpty
        ? null
        : _maskBuilder.buildMask(
            Size(state.imageWidth ?? 0, state.imageHeight ?? 0),
            faces: faces,
          );
    final beauty = await _processing.applyBeauty(
      filterApplied,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
      mask: mask,
    );
    final normalized = await _processing.normalizeBrightness(beauty);
    final transformed = await _processing.applyTransform(...);
    state = state.copyWith(previewBytes: transformed);
  }

  void setImage(String path) {
    _faceDetector.clearCache();
    // ... 已有逻辑
  }
}
```

### 2.4 数据流（人脸检测的时机）

| 触发 | 检测 | 说明 |
|---|---|---|
| `setImage(path)` | ✅ 立即检测并缓存 | 切照片时一次性 |
| `setSmooth/Whiten` 改变 | ❌ 复用缓存 | 检测只跑一次 |
| 滤镜切换 | ❌ 复用缓存 | 滤镜不影响人脸位置 |
| 裁切 / 旋转 / 缩放 | ⚠️ 待 P2 | 当前不重检测；mask 用在源图上即可（裁切后再 mask 不影响） |

### 2.5 UI 反馈

**未检测到人脸时**：
- 美颜 tab 顶部加一行提示「未检测到人脸」+ ⚠️ 图标
- 滑杆可拖动但实时预览不会变（无 mask = 跳过美颜）
- 拍照后第一次进入编辑页如果没脸，提示立即出现

**检测成功时**：
- 顶部小字「已检测 N 张人脸」绿色 ✓
- 滑杆实时反映

### 2.6 pubspec.yaml 新增依赖

```yaml
dependencies:
  google_mlkit_face_detection: ^0.13.2
  google_mlkit_commons: ^0.11.0
```

### 2.7 错误处理

| 场景 | 行为 |
|---|---|
| ML Kit 抛异常（库缺失 / GMS 不可用） | 降级：跳过美颜（`mask = null`）+ 日志告警（per Q4 默认无美颜回退） |
| detect 返回空（无脸） | `mask = null`，无美颜 + UI 提示 |
| mask 尺寸与原图不匹配 | 抛 `ArgumentError` 立即 fail-fast |
| applyBeauty mask 是 1-channel 但被传了 4-channel | 类型签名约束（`img.Image` numChannels=1） |
| 4K 图检测超时（>2s） | 降级：skip detection（`mask = null`）+ 日志 |

### 2.8 性能预算

| 操作 | 目标 | 实测（开发期） |
|---|---|---|
| ML Kit detect (4K 图) | < 800ms | TBD 真机 |
| buildMask (4K 图) | < 200ms | TBD |
| applyBeauty with mask (4K 图) | < 500ms | TBD |
| 全流程（含 detect） | < 1.5s | TBD |
| 全流程（缓存命中） | < 700ms | TBD |

**降级策略**：detect > 1.5s 时 skip detection，走全图美颜（避免用户感知卡顿）。

---

## 3. Files to Add / Modify

| 文件 | 变更类型 | 责任 |
|---|---|---|
| `pubspec.yaml` | 修改 | + `google_mlkit_face_detection` 0.13.2 + `google_mlkit_commons` 0.11.0 |
| `lib/services/face_detection_service.dart` | 新建 | 包装 ML Kit FaceDetector + 缓存 |
| `lib/services/face_mask_builder.dart` | 新建 | Face[] → img.Image mask |
| `lib/services/image_processing_service.dart` | 修改 | `applyBeauty` / `processImage` 加 mask 参数 |
| `lib/features/filter/filter_view_model.dart` | 修改 | 注入 FaceDetectionService + FaceMaskBuilder + 调度 detect/buildMask |
| `lib/features/filter/widgets/beauty_slider.dart` | 修改 | 顶部加「未检测到人脸」/「已检测 N 张」提示 |
| `lib/features/camera/camera_view_model.dart` | 修改 | 可能需要切换前后摄像头时重置人脸检测缓存（可选） |
| `test/services/face_detection_service_test.dart` | 新建 | cache 行为 + mock ML Kit 调用验证 |
| `test/services/face_mask_builder_test.dart` | 新建 | fillPolygon 正确性 + 眼睛嘴唇 exclusion + 羽化 |
| `test/services/image_processing_service_test.dart` | 修改 | applyBeauty with mask / without mask（回归原全图行为） |
| `test/filter/filter_view_model_preview_test.dart` | 修改 | detect 失败 / 无脸 / 有脸 3 个分支测试 |
| `ios/Podfile` | 可能修改 | ML Kit iOS 配置（包会自动处理大部分，但要 verify） |

> **不动**：`filter_panel.dart` 结构、`crop_ratio_bar.dart`、`interactive_crop_editor.dart`、AppBar 等

---

## 4. Tests

### 4.1 单元测试

1. **`face_detection_service_test.dart`**：
   - 同一 imagePath 多次 detect 只调底层 1 次（缓存命中）
   - 不同 imagePath 各自缓存
   - dispose 后再调 detect 不抛
   - 底层抛异常时上层不抛（降级到空 list）

2. **`face_mask_builder_test.dart`**：
   - 1 张脸的 mask：人脸区域像素值 > 128，背景 = 0
   - 眼睛 / 嘴唇区域被排除（像素值 < 50）
   - 多张脸的 mask：所有脸都覆盖
   - 空 faces → 全 0 mask
   - 羽化半径影响边缘渐变

3. **`image_processing_service_test.dart`** 新增 / 修改：
   - applyBeauty(smooth=50, mask=allZero) → 输出与原图几乎相同
   - applyBeauty(smooth=50, mask=fullWhite) → 输出与无 mask 几乎相同
   - applyBeauty(smooth=50, mask=half) → 边缘像素弱处理
   - **新语义**：applyBeauty(smooth=50, 无 mask) → **返回原图不变**（之前是全图磨皮）
   - **breaking change**：旧测试中 `applyBeauty(smooth=50, 无 mask)` 期望有磨皮效果的，**全部要改为传 `mask=fullWhite`（255 全白）**才能复现原行为

4. **`filter_view_model_preview_test.dart`** 新增：
   - setImage 后 200ms 内 _runProcess 跑完，包含 detect + mask + beauty
   - detect 失败 → mask=null → 无美颜（per Q4 默认）
   - detect 返回空 → mask=null → 无美颜 + state 标记「未检测到人脸」
   - 缓存命中：第二次调整滑杆不重新 detect
   - 旧测试中调用 processImage 后有磨皮效果的，需要在 stub 中让 detect 返回非空 + build mask 成功

### 4.2 Widget 测试

- **`beauty_slider_test.dart`**：检测成功 / 失败状态下提示文字正确

### 4.3 手动验证（真机）

- iOS / Android 各一台，iPhone 14+ 灵动岛 + 中端 Android
- 拍单人 / 多人 / 无人 / 侧脸 / 戴口罩 / 戴眼镜 6 种场景
- 验证：人脸区域有磨皮 + 背景保持清晰
- 验证：眼睛 / 嘴唇不被磨
- 验证：拖动滑杆不卡（200ms debounce 生效）
- 验证：未检测到人脸时滑杆拖动预览不变

---

## 5. Risks & Mitigations

| 风险 | 影响 | 缓解 |
|---|---|---|
| ML Kit 在大陆 Android GMS 缺失机型跑不起来 | 全部 Android 用户无美颜 | 提供静态降级到全图美颜（`mask = null`）+ 错误日志 |
| 4K 图 detect 超过 1.5s | 拖动滑杆卡顿 | 性能降级：超时 skip detection |
| 眼睛/嘴唇 exclusion 算法不准 | 误磨眼睛 / 误保留嘴唇 | 单元测试覆盖 + 真机 6 场景验证 |
| FaceDetector 实例未释放 | 内存泄漏 | ViewModel dispose 时调 `faceDetectionService.dispose()` |
| pub get 失败（ML Kit 包版本冲突） | 整个 pub 解析失败 | 锁版本到已知可用的 0.13.2 / 0.11.0；CI 上验证 |
| iOS 26+ 模拟器 build 问题（已知 ML Kit issue） | dev 流程受阻 | dev 用真机 + Android 模拟器，iOS 26 模拟器暂时 skip |
| `image` 包版本升级破坏 `gaussianBlur` mask 行为 | mask 不生效 | 锁 `image` 版本 + mask 行为单测 |
| 美白作用于 mask 边缘羽化效果不明显 | 人脸边缘有硬接缝 | 羽化半径 8pt → 可调参；用真机大图验证 |
| ViewModel 增加 detect 步骤后 200ms debounce 不够 | 频繁触发 | detect 仅在 setImage 时跑（不在滑杆时跑），debounce 留给其他路径 |

---

## 6. Out of Scope（明确不做）

- 实时视频美颜（仅静态图）
- 瘦脸 / 大眼 / 鼻梁等局部形变（`slim` 参数保留 stub）
- 美颜预设（"轻度" / "重度" 一键）
- 多人脸分别设置不同美颜程度
- 肤色调整（独立维度）
- 关键点贴纸 / 滤镜
- 人脸检测缓存的 LRU 淘汰（10 张以内够用，简单 FIFO）
- 离线 / 在线模型切换（只用 ML Kit 内置模型）
- 自定义训练美颜模型
- 男女 / 年龄 / 表情分类
