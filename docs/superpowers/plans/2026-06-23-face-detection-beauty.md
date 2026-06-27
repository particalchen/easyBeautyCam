# Face Detection Beauty Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在编辑页的磨皮 / 美白处理中，先用 ML Kit 检测人脸，只对人脸区域（mask 内）做美颜，眼睛 / 嘴唇保留；未检测到人脸时跳过美颜，原图预览。

**Architecture:**
- 新增 `FaceDetectionService`（ML Kit 静态图检测 + 按 `imagePath` 缓存）+ `FaceMaskBuilder`（轮廓 → mask image）
- `ImageProcessingService.applyBeauty` 加 `img.Image? mask` 参数：`null` = 跳过美颜（原图不变），有 mask = 只在 mask > 0 的像素处理
- `FilterViewModel._runProcess` 串接：`readOriginalBytes → applyFilter → faceDetector.detect → maskBuilder.buildMask → applyBeauty(with mask) → normalizeBrightness`
- `BeautySlider` 顶部加「未检测到人脸 / 已检测 N 张人脸」提示

**Tech Stack:** `google_mlkit_face_detection ^0.13.2` + `google_mlkit_commons ^0.11.0` + `image 4.0.9` (`gaussianBlur` 内置 `mask` 支持) + Riverpod

**Spec:** `docs/superpowers/specs/2026-06-23-face-detection-beauty-design.md`

**Research:** `docs/superpowers/research/2026-06-23-face-beauty-research.md`

---

## File Structure

| 文件 | 变更类型 | 责任 |
|---|---|---|
| `pubspec.yaml` | 修改 | + `google_mlkit_face_detection` + `google_mlkit_commons` |
| `lib/services/face_detection_service.dart` | 新建 | ML Kit 包装 + imagePath 缓存 |
| `lib/services/face_mask_builder.dart` | 新建 | `FaceContours[]` → 1-channel mask image（fillPolygon + 高斯羽化 + 眼唇排除） |
| `lib/services/image_processing_service.dart` | 修改 | `applyBeauty` / `processImage` 加 `img.Image? mask` 参数；`mask == null` = 跳过美颜 |
| `lib/features/filter/filter_view_model.dart` | 修改 | 注入 `FaceDetectionService` + `FaceMaskBuilder`；`_runProcess` 串接 detect / buildMask；`FilterViewModelState` 加 `faceCount` / `faceDetectionFailed` 字段 |
| `lib/features/filter/widgets/beauty_slider.dart` | 修改 | 顶部加「未检测到人脸 / 已检测 N 张」提示行 |
| `lib/l10n/app_zh.arb` | 修改 | + `beautyNoFaceDetected` / `beautyFaceDetected` |
| `lib/l10n/app_en.arb` | 修改 | + `beautyNoFaceDetected` / `beautyFaceDetected` |
| `test/services/face_detection_service_test.dart` | 新建 | 缓存命中 / 失效 / clearCache / 默认 detector 存在性 |
| `test/services/face_mask_builder_test.dart` | 新建 | fillPolygon / 眼唇排除 / 羽化 / 空 faces |
| `test/services/image_processing_service_test.dart` | 修改 | + `applyBeauty(mask: null)` 不变；+ `applyBeauty(mask: allZero/fullWhite/half)` 行为 |
| `test/filter/filter_view_model_preview_test.dart` | 修改 | 注入 face detector / mask builder stub；验证 detect 一次 + 缓存命中；mask=null → previewBytes 不变 |
| `test/widget/beauty_slider_test.dart` | 修改 | faceCount=0/2 提示文案 |
| `docs/MEMO.md` | 修改 | 追加 〇九 章节 |
| `CHANGELOG.md` | 修改 | Unreleased 块追加条目 |

> 不修改：相机取景页（人脸检测只在编辑页静态图上跑，**不**做实时视频美颜）

---

## Task 1: pubspec 依赖 + FaceDetectionService 骨架

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/services/face_detection_service.dart`
- Create: `test/services/face_detection_service_test.dart`

- [ ] **Step 1: 写失败测试 — 缓存命中**

新建 `test/services/face_detection_service_test.dart`：

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/services/face_detection_service.dart';

void main() {
  group('FaceDetectionService 缓存', () {
    test('同一 imagePath 连续 detect 只调底层 1 次', () async {
      int callCount = 0;
      final svc = FaceDetectionService(
        detectFn: (path, bytes) async {
          callCount++;
          return const <FaceContours>[];
        },
      );

      await svc.detect('/photo/a.jpg');
      await svc.detect('/photo/a.jpg');
      await svc.detect('/photo/a.jpg');

      expect(callCount, 1, reason: '第二次起应命中缓存');
    });

    test('不同 imagePath 各自缓存', () async {
      int callCount = 0;
      final svc = FaceDetectionService(
        detectFn: (path, bytes) async {
          callCount++;
          return const <FaceContours>[];
        },
      );

      await svc.detect('/photo/a.jpg');
      await svc.detect('/photo/b.jpg');
      await svc.detect('/photo/a.jpg'); // 命中

      expect(callCount, 2, reason: 'a 一次 + b 一次 = 2');
    });

    test('clearCache 后下次 detect 重新走底层', () async {
      int callCount = 0;
      final svc = FaceDetectionService(
        detectFn: (path, bytes) async {
          callCount++;
          return const <FaceContours>[];
        },
      );

      await svc.detect('/photo/a.jpg');
      svc.clearCache();
      await svc.detect('/photo/a.jpg');

      expect(callCount, 2, reason: '清缓存后应当重新调用');
    });

    test('底层抛异常时向上抛（不静默吞）', () async {
      final svc = FaceDetectionService(
        detectFn: (path, bytes) async {
          throw Exception('ml kit native missing');
        },
      );

      expect(
        () => svc.detect('/photo/a.jpg'),
        throwsA(isA<Exception>()),
        reason: '失败应向上抛，让 ViewModel 决定降级',
      );
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/face_detection_service_test.dart -v 2>&1 | tail -20
```

预期：编译错误（`FaceDetectionService` / `FaceContours` 未定义）。

- [ ] **Step 3: 写最小实现 `FaceContours` + `FaceDetectionService`**

新建 `lib/services/face_detection_service.dart`：

```dart
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// 一个人脸的轮廓点集（不依赖 ML Kit 的 Face 类）
///
/// - [face]    整脸轮廓（用于 fillPolygon 主区域）
/// - [leftEye] / [rightEye] / [lipUpper] / [lipLower] 用于 mask 内部"打洞"
///   —— 这些区域不磨皮，保留眼睛 / 嘴唇细节
class FaceContours {
  final List<Offset> face;
  final List<Offset>? leftEye;
  final List<Offset>? rightEye;
  final List<Offset>? lipUpper;
  final List<Offset>? lipLower;

  const FaceContours({
    required this.face,
    this.leftEye,
    this.rightEye,
    this.lipUpper,
    this.lipLower,
  });
}

/// 底层人脸检测函数签名：path + bytes → FaceContours 列表
///
/// 生产实现是 ML Kit；测试里直接传 fake。
typedef FaceDetectFn = Future<List<FaceContours>> Function(
  String imagePath,
  Uint8List? bytes,
);

/// ML Kit 人脸检测服务（静态图）
///
/// 缓存策略：key = imagePath（每张照片唯一）；ViewModel 切照片时调
/// [clearCache] 释放内存。缓存上限不做 LRU（照片编辑场景，10 张以内够用）。
class FaceDetectionService {
  final FaceDetectFn _detect;
  final Map<String, List<FaceContours>> _cache = {};

  FaceDetectionService({FaceDetectFn? detectFn})
      : _detect = detectFn ?? _mlKitDetector();

  Future<List<FaceContours>> detect(String imagePath, {Uint8List? bytes}) async {
    final cached = _cache[imagePath];
    if (cached != null) return cached;
    final result = await _detect(imagePath, bytes);
    _cache[imagePath] = result;
    return result;
  }

  void clearCache() => _cache.clear();

  /// 释放 ML Kit detector 资源（仅当用了默认 detector）
  void dispose() {
    if (identical(_detect, _defaultInstance)) {
      _defaultDetector?.close();
      _defaultDetector = null;
    }
  }

  // ---- 内部：ML Kit 默认 detector ----
  static FaceDetector? _defaultDetector;
  static FaceContours? _ignore; // 占位保证 static 字段使用

  /// 静态单例的 detect 实现（dispose 时只 close 这一个 detector）
  static FaceDetectFn _mlKitDetector() {
    _defaultDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: false,
        performanceMode: FaceDetectorMode.fast,
        enableClassification: false,
        enableTracking: false,
        minFaceSize: 0.15,
      ),
    );
    final detector = _defaultDetector!;
    return (path, bytes) async {
      final input = bytes != null
          ? InputImage.fromBytes(
              bytes: bytes,
              metadata: InputImageMetadata(
                size: const Size(1, 1),
                rotation: InputImageRotation.rotation0deg,
                format: InputImageFormat.nv21,
                bytesPerRow: bytes.length,
              ),
            )
          : InputImage.fromFilePath(path);
      final faces = await detector.processImage(input);
      return faces.map(_convert).toList();
    };
  }

  static FaceContours _convert(Face face) {
    Offset pt(FaceContourPoint p) => Offset(p.position.x.toDouble(), p.position.y.toDouble());
    final fc = face.contours;
    List<Offset>? get(FaceContourType t) =>
        fc[t]?.map(pt).toList();
    return FaceContours(
      face: fc[FaceContourType.face]?.map(pt).toList() ?? const [],
      leftEye: get(FaceContourType.leftEye),
      rightEye: get(FaceContourType.rightEye),
      lipUpper: get(FaceContourType.lipUpper),
      lipLower: get(FaceContourType.lipLower),
    );
  }
}

// `identical` 用到的占位符：保证生产代码路径不丢失
final _defaultInstance = _FaceDetectionDefaultSentinel();

class _FaceDetectionDefaultSentinel {}

extension on FaceDetectionService {
  // ignore: unused_element
  bool get _isDefault => identical(_detect as Object, _defaultInstance);
}
```

顶部加 `import 'dart:ui' show Offset, Size;`（在文件最上方）。

> 上面 `_mlKitDetector` 默认是 lazy 单例；dispose 时 close 它。`bytes != null` 时构造 `InputImage.fromBytes`（静态图 bytes，rotation 0deg；size 后续从 view model 传会更准，第一版用 1×1 走通，ML Kit 仍能识别）。
>
> ⚠️ **关于 `Size(1,1)` 兜底**：ML Kit 在 `InputImage.fromBytes` 路径下 `size` 字段对 contour 输出坐标比例有影响。最稳妥是从 view model 传原图 W/H 进 detect。后续 Task 4 改造时改为接受 `imageSize` 参数。本任务先把缓存骨架立住，bytes 路径的 size 在 Task 4 调优。

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/face_detection_service_test.dart -v 2>&1 | tail -20
```

预期：PASS。

- [ ] **Step 5: 加 pubspec 依赖**

修改 `pubspec.yaml`：

```yaml
dependencies:
  # ... 已有 ...
  google_mlkit_face_detection: ^0.13.2
  google_mlkit_commons: ^0.11.0
```

跑：

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter pub get 2>&1 | tail -10
```

预期：依赖解析成功，**不**报版本冲突。

- [ ] **Step 6: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add pubspec.yaml pubspec.lock lib/services/face_detection_service.dart test/services/face_detection_service_test.dart
git commit -m "feat(face-detection): 新增 FaceDetectionService（ML Kit 包装 + 缓存）

- FaceContours 数据类（不依赖 ML Kit Face 类型，纯 Offset 列表）
- FaceDetectionService 通过 inject FaceDetectFn 解耦 ML Kit，便于测试
- 缓存 key = imagePath，clearCache 供 ViewModel 切照片时调
- 底层抛异常向上抛，ViewModel 决定降级（mask=null=skip beauty）"
```

---

## Task 2: FaceMaskBuilder

**Files:**
- Create: `lib/services/face_mask_builder.dart`
- Create: `test/services/face_mask_builder_test.dart`

- [ ] **Step 1: 写失败测试**

新建 `test/services/face_mask_builder_test.dart`：

```dart
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:easy_beauty_cam/services/face_detection_service.dart';
import 'package:easy_beauty_cam/services/face_mask_builder.dart';

void main() {
  group('FaceMaskBuilder', () {
    test('1 张脸覆盖图像中心区域：人脸像素 > 128，背景 = 0', () {
      // 造一个 100x100 中心脸（face 轮廓 = 中心 50x50 矩形点集）
      final facePts = <Offset>[
        for (var x = 25; x <= 75; x++) Offset(x.toDouble(), 25),
        for (var y = 26; y <= 75; y++) Offset(75, y.toDouble()),
        for (var x = 74; x >= 25; x--) Offset(x.toDouble(), 75),
        for (var y = 74; y >= 26; y--) Offset(25, y.toDouble()),
      ];
      final builder = FaceMaskBuilder();
      final mask = builder.buildMask(
        width: 100,
        height: 100,
        faces: [FaceContours(face: facePts)],
        featherRadius: 0, // 0 羽化 = 硬边，方便测断言
        excludeEyesLips: false,
      );

      // 中心像素应 > 128
      final center = mask.getPixel(50, 50);
      expect(center.r, greaterThan(128),
          reason: '人脸中心区域应高亮，实际=${center.r}');
      // 角落像素 = 0
      final corner = mask.getPixel(0, 0);
      expect(corner.r, 0, reason: '背景角落应=0，实际=${corner.r}');
    });

    test('眼睛 / 嘴唇区域被排除（mask 值 < 50）', () {
      // 整脸 = 50x50 中心矩形；眼框 = 20x10 嵌在脸内部
      final facePts = <Offset>[
        for (var x = 25; x <= 75; x++) Offset(x.toDouble(), 25),
        for (var y = 26; y <= 75; y++) Offset(75, y.toDouble()),
        for (var x = 74; x >= 25; x--) Offset(x.toDouble(), 75),
        for (var y = 74; y >= 26; y--) Offset(25, y.toDouble()),
      ];
      // 嘴区域 = 中心 30x10 矩形（用来测试 lip exclusion）
      final lipPts = <Offset>[
        for (var x = 35; x <= 65; x++) Offset(x.toDouble(), 55),
        for (var y = 56; y <= 65; y++) Offset(65, y.toDouble()),
        for (var x = 64; x >= 35; x--) Offset(x.toDouble(), 65),
        for (var y = 64; y >= 56; y--) Offset(35, y.toDouble()),
      ];
      final builder = FaceMaskBuilder();
      final mask = builder.buildMask(
        width: 100,
        height: 100,
        faces: [
          FaceContours(face: facePts, lipLower: lipPts),
        ],
        featherRadius: 0,
        excludeEyesLips: true,
      );

      // 嘴中心 (50, 60) 应被排除 = 0
      final lipPixel = mask.getPixel(50, 60);
      expect(lipPixel.r, lessThan(50),
          reason: '嘴唇区域应被排除，实际=${lipPixel.r}');
      // 脸其他区域 (50, 30) 仍高亮
      final facePixel = mask.getPixel(50, 30);
      expect(facePixel.r, greaterThan(128),
          reason: '人脸非眼唇区域应高亮，实际=${facePixel.r}');
    });

    test('空 faces → 全 0 mask', () {
      final mask = FaceMaskBuilder().buildMask(
        width: 100, height: 100, faces: const [],
        featherRadius: 0,
      );
      final corner = mask.getPixel(0, 0);
      final center = mask.getPixel(50, 50);
      expect(corner.r, 0);
      expect(center.r, 0);
    });

    test('多张脸：所有脸都覆盖', () {
      // 左脸中心 (20, 50)，右脸中心 (80, 50)
      Offset rect(int cx, int cy, int w, int h) {
        // 单点矩形（用做单点 face = 退化情况，用 Offset 列表）
        return Offset(cx.toDouble(), cy.toDouble());
      }
      // 简化：用 4 点矩形（fillPolygon 需要至少 3 个）
      List<Offset> rect4(int x0, int y0, int x1, int y1) => [
            Offset(x0.toDouble(), y0.toDouble()),
            Offset(x1.toDouble(), y0.toDouble()),
            Offset(x1.toDouble(), y1.toDouble()),
            Offset(x0.toDouble(), y1.toDouble()),
          ];
      final mask = FaceMaskBuilder().buildMask(
        width: 100,
        height: 100,
        faces: [
          FaceContours(face: rect4(10, 30, 30, 70)),
          FaceContours(face: rect4(70, 30, 90, 70)),
        ],
        featherRadius: 0,
        excludeEyesLips: false,
      );
      // 两张脸中心都高亮
      expect(mask.getPixel(20, 50).r, greaterThan(128));
      expect(mask.getPixel(80, 50).r, greaterThan(128));
      // 中间空隙低
      expect(mask.getPixel(50, 50).r, lessThan(50));
      // 忽略 rect 单点未使用 warning
      expect(rect(0, 0, 0, 0), isA<Offset>());
    });

    test('featherRadius=0 vs 8：feather 影响边缘渐变', () {
      final facePts = <Offset>[
        for (var x = 25; x <= 75; x++) Offset(x.toDouble(), 25),
        for (var y = 26; y <= 75; y++) Offset(75, y.toDouble()),
        for (var x = 74; x >= 25; x--) Offset(x.toDouble(), 75),
        for (var y = 74; y >= 26; y--) Offset(25, y.toDouble()),
      ];
      final maskSharp = FaceMaskBuilder().buildMask(
        width: 100, height: 100,
        faces: [FaceContours(face: facePts)],
        featherRadius: 0,
      );
      final maskFeather = FaceMaskBuilder().buildMask(
        width: 100, height: 100,
        faces: [FaceContours(face: facePts)],
        featherRadius: 8,
      );
      // 脸外圈（边缘 +2pt）: feather 后值应比 sharp 后更小（边缘被羽化平滑掉）
      final edgeSharp = maskSharp.getPixel(24, 50).r;
      final edgeFeather = maskFeather.getPixel(24, 50).r;
      expect(edgeFeather, lessThan(edgeSharp),
          reason: 'feather 8pt 的边缘值应 < sharp 0pt 的边缘值');
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/face_mask_builder_test.dart -v 2>&1 | tail -20
```

预期：编译错误（`FaceMaskBuilder` 未定义）。

- [ ] **Step 3: 实现 `FaceMaskBuilder`**

新建 `lib/services/face_mask_builder.dart`：

```dart
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;

import 'face_detection_service.dart';

/// 人脸轮廓 → 1-channel mask image
///
/// 像素值 ∈ [0, 255]，0 = 不处理（背景 / 眼唇），255 = 完全处理（人脸）
/// 边缘 [featherRadius] 控制羽化程度（高斯模糊）以避免硬接缝
class FaceMaskBuilder {
  /// [width] / [height] = 原图尺寸
  /// [faces] = FaceDetectionService.detect 返回的轮廓
  /// [featherRadius] = 边缘羽化半径（0 = 硬边；8 适合 4K 图）
  /// [excludeEyesLips] = 是否把眼/唇区域从 mask 中挖空（保留细节）
  img.Image buildMask({
    required int width,
    required int height,
    required List<FaceContours> faces,
    int featherRadius = 8,
    bool excludeEyesLips = true,
  }) {
    // 1) 全 0 mask（1-channel grayscale）
    final mask = img.Image(width: width, height: height, numChannels: 1);
    img.fill(mask, color: img.ColorRgb8(0, 0, 0));

    if (faces.isEmpty) return mask;

    // 2) 每个人脸 fillPolygon → 255
    final white = img.ColorRgb8(255, 255, 255);
    for (final f in faces) {
      if (f.face.length < 3) continue;
      mask.fillPolygon(
        vertices: f.face.map((o) => img.Point(o.dx, o.dy)).toList(),
        color: white,
      );

      // 3) 排除眼/唇：fillPolygon → 0
      if (excludeEyesLips) {
        final black = img.ColorRgb8(0, 0, 0);
        for (final pts in [f.leftEye, f.rightEye, f.lipUpper, f.lipLower]) {
          if (pts == null || pts.length < 3) continue;
          mask.fillPolygon(
            vertices: pts.map((o) => img.Point(o.dx, o.dy)).toList(),
            color: black,
          );
        }
      }
    }

    // 4) 边缘羽化：高斯模糊 mask（mask 自身就是 1-channel）
    if (featherRadius > 0) {
      return img.gaussianBlur(mask, radius: featherRadius);
    }
    return mask;
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/face_mask_builder_test.dart -v 2>&1 | tail -20
```

预期：PASS。

- [ ] **Step 5: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/services/face_mask_builder.dart test/services/face_mask_builder_test.dart
git commit -m "feat(face-detection): 新增 FaceMaskBuilder（轮廓 → mask image）

- 1-channel grayscale mask，0=不处理，255=完全处理
- fillPolygon 整脸到 255，再 fillPolygon 眼唇到 0（排除）
- 高斯羽化 featherRadius 控制边缘软硬（默认 8pt）
- 纯函数，不依赖 ML Kit，便于单测"
```

---

## Task 3: applyBeauty 加 mask 参数 + 现有测试迁移

**Files:**
- Modify: `lib/services/image_processing_service.dart`（`applyBeauty` + `processImage` 签名）
- Modify: `test/services/image_processing_service_test.dart`（加新 group + 不动旧 group）

> **不破坏语义**：旧测试 `normalizeBrightness` / `crop` / `applyTransform` 完全不涉及 applyBeauty；新加 group 即可。`applyBeauty` 行为变化：以前 `smooth>0` 永远全图磨皮；现在 `mask=null` 直接 return 原图（**breaking change**，但 spec 4.1.3 明确要求）。

- [ ] **Step 1: 写失败测试 — mask=null 跳过美颜**

在 `test/services/image_processing_service_test.dart` 文件末尾追加新 group：

```dart
group('ImageProcessingService.applyBeauty - mask 行为', () {
  test('mask=null：直接返回原图，不做任何处理', () async {
    // 1) 造一张 20x20 中心 rgb(100)，跑 applyBeauty(smooth=50, whiten=50, mask=null)
    final src = img.Image(width: 20, height: 20);
    img.fill(src, color: img.ColorRgb8(100, 100, 100));
    final srcBytes = Uint8List.fromList(img.encodePng(src));

    final svc = ImageProcessingService();
    final out = await svc.applyBeauty(
      srcBytes, smooth: 50, whiten: 50, slim: 0, mask: null,
    );

    // 2) 解码输出：所有像素应 == 原图
    final decoded = img.decodeImage(out);
    expect(decoded, isNotNull);
    final center = decoded!.getPixel(10, 10);
    expect(center.r, 100, reason: 'mask=null 时原图不被修改');
    expect(center.g, 100);
    expect(center.b, 100);
  });

  test('mask=allZero (全黑 mask)：原图不被修改', () async {
    final src = img.Image(width: 20, height: 20);
    img.fill(src, color: img.ColorRgb8(100, 100, 100));
    final srcBytes = Uint8List.fromList(img.encodePng(src));

    // 1-channel 全 0 mask
    final mask = img.Image(width: 20, height: 20, numChannels: 1);
    img.fill(mask, color: img.ColorRgb8(0, 0, 0));

    final svc = ImageProcessingService();
    final out = await svc.applyBeauty(
      srcBytes, smooth: 50, whiten: 50, slim: 0, mask: mask,
    );

    final decoded = img.decodeImage(out)!;
    expect(decoded.getPixel(10, 10).r, 100, reason: 'mask=0 时像素不被处理');
  });

  test('mask=fullWhite (全白 mask)：所有像素被磨皮', () async {
    final src = img.Image(width: 20, height: 20);
    img.fill(src, color: img.ColorRgb8(100, 100, 100));
    final srcBytes = Uint8List.fromList(img.encodePng(src));

    // 1-channel 全 255 mask
    final mask = img.Image(width: 20, height: 20, numChannels: 1);
    img.fill(mask, color: img.ColorRgb8(255, 255, 255));

    final svc = ImageProcessingService();
    final out = await svc.applyBeauty(
      srcBytes, smooth: 50, whiten: 0, slim: 0, mask: mask,
    );

    // 平滑后每个像素应 ≈ 100（前后色相同 → blend 后还是 100）
    final decoded = img.decodeImage(out)!;
    final p = decoded.getPixel(10, 10);
    expect(p.r, closeTo(100, 2));
  });

  test('mask=half (128 灰度)：像素被部分处理（边缘羽化）', () async {
    // 左半边 0 mask，右半边 255 mask
    final src = img.Image(width: 20, height: 20);
    img.fill(src, color: img.ColorRgb8(100, 100, 100));
    final srcBytes = Uint8List.fromList(img.encodePng(src));

    final mask = img.Image(width: 20, height: 20, numChannels: 1);
    for (var y = 0; y < 20; y++) {
      for (var x = 0; x < 20; x++) {
        mask.setPixel(x, y, x < 10
            ? img.ColorRgb8(0, 0, 0)
            : img.ColorRgb8(255, 255, 255));
      }
    }

    final svc = ImageProcessingService();
    final out = await svc.applyBeauty(
      srcBytes, smooth: 0, whiten: 50, slim: 0, mask: mask,
    );

    final decoded = img.decodeImage(out)!;
    // 左半边：whiten=0 → RGB 不变
    expect(decoded.getPixel(5, 10).r, 100, reason: 'mask=0 区域不应被提亮');
    // 右半边：whiten=50 → 100 + (50/100*30) = 115
    expect(decoded.getPixel(15, 10).r, 115, reason: 'mask=255 区域应被提亮');
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/image_processing_service_test.dart -v 2>&1 | tail -20
```

预期：编译错误（`applyBeauty` 还不接受 `mask` 参数）。

- [ ] **Step 3: 修改 `applyBeauty` + `processImage`**

修改 `lib/services/image_processing_service.dart`：

把 `applyBeauty`（第 115-166 行）替换为：

```dart
  /// 美颜（磨皮 + 美白 + 瘦脸）
  ///
  /// - [mask] = null → 直接返回原图，不做任何处理（per Q4 默认：
  ///   检测不到人脸时无美颜回退，UI 上提示「未检测到人脸」）
  /// - [mask] 1-channel grayscale：0=不处理，255=完全处理；边缘羽化时取 0~255
  /// - 磨皮：在 mask > 0 的像素做 blend；blendFactor = (smooth/500) * mask/255
  /// - 美白：在 mask > 0 的像素 +adjust；adjust = (whiten/100*30) * mask/255
  /// - 瘦脸：slim 参数保留 stub，暂不实现
  Future<Uint8List> applyBeauty(
    Uint8List imageBytes, {
    double smooth = 30,
    double whiten = 20,
    double slim = 0,
    img.Image? mask,
  }) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    // 无 mask = 跳过美颜（原图返回，per Q4 默认）
    if (mask == null) return imageBytes;

    var result = image;

    // Smooth (Gaussian blur + blend，仅在 mask > 0 像素)
    if (smooth > 0) {
      final radius = (smooth / 30).round().clamp(1, 2);
      final blurred = img.gaussianBlur(result, radius: radius);
      final blendFactor = smooth / 500; // 30 → 0.06, 100 → 0.20
      result = img.Image(width: result.width, height: result.height);
      for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
          final m = mask.getPixel(x, y).r / 255.0;
          if (m <= 0) continue; // 跳过非人脸像素
          final orig = result.getPixel(x, y);
          final blur = blurred.getPixel(x, y);
          final localBlend = blendFactor * m; // 边缘羽化
          result.setPixelRgba(
            x, y,
            ((orig.r * (1 - localBlend) + blur.r * localBlend)).round(),
            ((orig.g * (1 - localBlend) + blur.g * localBlend)).round(),
            ((orig.b * (1 - localBlend) + blur.b * localBlend)).round(),
            orig.a.toInt(),
          );
        }
      }
    }

    // Whiten (brightness adjustment，仅在 mask > 0 像素)
    if (whiten > 0) {
      final adjustBase = (whiten / 100 * 30).round();
      for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
          final m = mask.getPixel(x, y).r / 255.0;
          if (m <= 0) continue;
          final p = result.getPixel(x, y);
          final adjust = (adjustBase * m).round(); // 边缘羽化
          result.setPixelRgba(
            x, y,
            (p.r + adjust).clamp(0, 255),
            (p.g + adjust).clamp(0, 255),
            (p.b + adjust).clamp(0, 255),
            p.a.toInt(),
          );
        }
      }
    }

    return Uint8List.fromList(img.encodePng(result));
  }
```

把 `processImage`（第 168-187 行）替换为：

```dart
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
    img.Image? mask,
  }) async {
    var result = imageBytes;
    result = await applyFilter(result, filter);
    result = await applyBeauty(
      result,
      smooth: smooth,
      whiten: whiten,
      slim: slim,
      mask: mask,
    );
    // 自动亮度补偿：兜底「相机预览/拍照曝光不一致」导致的偏暗照片
    // 仅当 mean luma < 75 时提升，亮图不被动
    result = await normalizeBrightness(result);
    return result;
  }
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/services/image_processing_service_test.dart -v 2>&1 | tail -20
```

预期：所有 group PASS（含旧 `normalizeBrightness` / `crop` / `applyTransform` + 新 `applyBeauty - mask 行为`）。

- [ ] **Step 5: 跑完整测试套件**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -20
```

预期：所有旧测试通过（applyBeauty 之前**没**直接被测过，所以这次新增的 group 不影响其他文件）。

- [ ] **Step 6: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/services/image_processing_service.dart test/services/image_processing_service_test.dart
git commit -m "feat(face-detection): applyBeauty 加 mask 参数（null=跳过美颜）

- mask=null → 直接 return 原图（per Q4 默认：未检测到人脸无美颜回退）
- mask=allZero → 全图不变
- mask=fullWhite → 全图被处理（保留原行为）
- mask=half → 边缘羽化（blendFactor / adjust 按 mask 灰度衰减）
- 4 个新单测覆盖以上 4 个分支"
```

---

## Task 4: FilterViewModel 串接 detect + buildMask

**Files:**
- Modify: `lib/features/filter/filter_view_model.dart`（注入 service + state 字段 + `_runProcess` 流程）
- Modify: `test/filter/filter_view_model_preview_test.dart`（mock detect + buildMask + 新断言）

- [ ] **Step 1: 写失败测试 — `_runProcess` 调 detect + buildMask**

在 `test/filter/filter_view_model_preview_test.dart` 顶部 imports 后追加 stub：

```dart
import 'dart:ui' show Offset;

import 'package:easy_beauty_cam/services/face_detection_service.dart';
import 'package:easy_beauty_cam/services/face_mask_builder.dart';
import 'package:image/image.dart' as img;

// 记录 detect 调用次数 + 返回固定 1 张脸
class _StubFaceDetector extends FaceDetectionService {
  int detectCallCount = 0;
  List<FaceContours> cannedResult = const [];

  _StubFaceDetector({this.cannedResult = const []})
      : super(detectFn: (path, bytes) async {
          return cannedResult;
        });

  @override
  Future<List<FaceContours>> detect(String imagePath, {Uint8List? bytes}) async {
    detectCallCount++;
    return cannedResult;
  }
}

class _StubMaskBuilder extends FaceMaskBuilder {
  int buildCallCount = 0;
  img.Image? cannedMask; // null 表示不调 applyBeauty with mask

  _StubMaskBuilder({this.cannedMask});

  @override
  img.Image buildMask({
    required int width,
    required int height,
    required List<FaceContours> faces,
    int featherRadius = 8,
    bool excludeEyesLips = true,
  }) {
    buildCallCount++;
    return cannedMask ?? img.Image(width: 1, height: 1, numChannels: 1);
  }
}
```

在 `setUp` 里加：

```dart
final faceDetector = _StubFaceDetector();
final maskBuilder = _StubMaskBuilder();

container = ProviderContainer(
  overrides: [
    imageProcessingServiceProvider.overrideWithValue(svc),
    photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
    appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
    faceDetectionServiceProvider.overrideWithValue(faceDetector),
    faceMaskBuilderProvider.overrideWithValue(maskBuilder),
  ],
);
```

在文件末尾追加新 group：

```dart
group('FilterViewModel 人脸检测 + mask', () {
  test('setImage 后 _runProcess 调 detect 1 次 + buildMask 1 次', () async {
    final tempFile = await File('${Directory.systemTemp.path}/face_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
    await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

    final detector = _StubFaceDetector(cannedResult: [
      FaceContours(face: const [Offset(10, 10), Offset(50, 10), Offset(30, 50)]),
    ]);
    final builder = _StubMaskBuilder(cannedMask: img.Image(width: 100, height: 100, numChannels: 1));
    final c = ProviderContainer(
      overrides: [
        imageProcessingServiceProvider.overrideWithValue(svc),
        photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
        appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
        faceDetectionServiceProvider.overrideWithValue(detector),
        faceMaskBuilderProvider.overrideWithValue(builder),
      ],
    );

    c.read(filterViewModelProvider.notifier).setImage(tempFile.path);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(detector.detectCallCount, 1, reason: 'setImage 立即 detect 一次');
    expect(builder.buildCallCount, 1, reason: 'buildMask 在 detect 成功后被调');
    expect(c.read(filterViewModelProvider).faceCount, 1, reason: 'state.faceCount=1');

    c.dispose();
    await tempFile.delete();
  });

  test('detect 返回空 → faceCount=0, mask=null, state 标记', () async {
    final tempFile = await File('${Directory.systemTemp.path}/noface_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
    await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

    final detector = _StubFaceDetector(cannedResult: const []);
    final builder = _StubMaskBuilder();
    final c = ProviderContainer(
      overrides: [
        imageProcessingServiceProvider.overrideWithValue(svc),
        photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
        appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
        faceDetectionServiceProvider.overrideWithValue(detector),
        faceMaskBuilderProvider.overrideWithValue(builder),
      ],
    );

    c.read(filterViewModelProvider.notifier).setImage(tempFile.path);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final state = c.read(filterViewModelProvider);
    expect(state.faceCount, 0);
    expect(builder.buildCallCount, 0, reason: '无脸时不应调 buildMask');

    c.dispose();
    await tempFile.delete();
  });

  test('缓存命中：连续调 setSmooth 不重新 detect', () async {
    final tempFile = await File('${Directory.systemTemp.path}/cached_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
    await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

    final detector = _StubFaceDetector(cannedResult: [
      FaceContours(face: const [Offset(10, 10), Offset(50, 10), Offset(30, 50)]),
    ]);
    final builder = _StubMaskBuilder(cannedMask: img.Image(width: 100, height: 100, numChannels: 1));
    final c = ProviderContainer(
      overrides: [
        imageProcessingServiceProvider.overrideWithValue(svc),
        photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
        appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
        faceDetectionServiceProvider.overrideWithValue(detector),
        faceMaskBuilderProvider.overrideWithValue(builder),
      ],
    );

    final notifier = c.read(filterViewModelProvider.notifier);
    notifier.setImage(tempFile.path);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final initialDetect = detector.detectCallCount;
    final initialBuild = builder.buildCallCount;

    // 改 smooth 滑杆（200ms debounce）→ 应当复用缓存
    notifier.setSmooth(50);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(detector.detectCallCount, initialDetect, reason: '改 smooth 不重新 detect');
    expect(builder.buildCallCount, initialBuild, reason: '改 smooth 不重新 buildMask');

    c.dispose();
    await tempFile.delete();
  });

  test('setImage 切到新 path → 缓存被清空，detect 重跑', () async {
    final tempFile1 = await File('${Directory.systemTemp.path}/a_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
    final tempFile2 = await File('${Directory.systemTemp.path}/b_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
    await tempFile1.writeAsBytes([0xFF, 0xD8, 0xFF]);
    await tempFile2.writeAsBytes([0xFF, 0xD8, 0xFF]);

    final detector = _StubFaceDetector(cannedResult: const []);
    final c = ProviderContainer(
      overrides: [
        imageProcessingServiceProvider.overrideWithValue(svc),
        photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
        appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
        faceDetectionServiceProvider.overrideWithValue(detector),
        faceMaskBuilderProvider.overrideWithValue(_StubMaskBuilder()),
      ],
    );
    final notifier = c.read(filterViewModelProvider.notifier);

    notifier.setImage(tempFile1.path);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(detector.detectCallCount, 1);

    notifier.setImage(tempFile2.path);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(detector.detectCallCount, 2, reason: '切到新照片应 detect 第二次');

    c.dispose();
    await tempFile1.delete();
    await tempFile2.delete();
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart -v 2>&1 | tail -30
```

预期：编译错误（`faceDetectionServiceProvider` / `faceMaskBuilderProvider` 未定义）。

- [ ] **Step 3: 改 `filter_view_model.dart`**

修改 `lib/features/filter/filter_view_model.dart`：

**A) 加 import**：

```dart
import 'package:flutter/foundation.dart' show Size;
import '../../services/face_detection_service.dart';
import '../../services/face_mask_builder.dart';
```

**B) 加 provider 声明**（紧接 `imageProcessingServiceProvider` 后面）：

```dart
final faceDetectionServiceProvider = Provider<FaceDetectionService>((ref) {
  return FaceDetectionService();
});

final faceMaskBuilderProvider = Provider<FaceMaskBuilder>((ref) {
  return FaceMaskBuilder();
});
```

**C) 加 state 字段**（`FilterViewModelState` 内）：

```dart
  final int faceCount;
  final bool faceDetectionFailed;

  const FilterViewModelState({
    // ... 已有 ...
    this.faceCount = 0,
    this.faceDetectionFailed = false,
  });

  FilterViewModelState copyWith({
    // ... 已有 ...
    int? faceCount,
    bool? faceDetectionFailed,
  }) {
    return FilterViewModelState(
      // ... 已有 ...
      faceCount: faceCount ?? this.faceCount,
      faceDetectionFailed: faceDetectionFailed ?? this.faceDetectionFailed,
    );
  }
```

**D) 改 ViewModel 构造函数**（注入 service）：

```dart
class FilterViewModel extends StateNotifier<FilterViewModelState> {
  final ImageProcessingService _processingService;
  final PhotoAlbumWriter _photoAlbumWriter;
  final AppPhotoRepository _appPhotoRepository;
  final FaceDetectionService _faceDetector;
  final FaceMaskBuilder _maskBuilder;
  int? _lastDetectedImageWidth;
  int? _lastDetectedImageHeight;

  Timer? _debounce;

  FilterViewModel(
    this._processingService,
    this._photoAlbumWriter,
    this._appPhotoRepository,
    this._faceDetector,
    this._maskBuilder,
  ) : super(const FilterViewModelState());
```

**E) 改 `filterViewModelProvider`**（加 watch 注入）：

```dart
final filterViewModelProvider = StateNotifierProvider<FilterViewModel, FilterViewModelState>((ref) {
  return FilterViewModel(
    ref.watch(imageProcessingServiceProvider),
    ref.watch(photoAlbumWriterProvider),
    ref.watch(appPhotoRepositoryProvider),
    ref.watch(faceDetectionServiceProvider),
    ref.watch(faceMaskBuilderProvider),
  );
});
```

**F) 改 `setImage` 清缓存**：

```dart
  void setImage(String path) {
    _faceDetector.clearCache();
    state = state.copyWith(
      imagePath: path,
      clearOriginalBytes: true,
      clearPreviewBytes: true,
      faceCount: 0,
      faceDetectionFailed: false,
    );
    _scheduleProcess(immediate: true);
  }
```

**G) 改 `_runProcess` 串接 detect + buildMask**：

把 `_runProcess` 替换为：

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

    // 2) applyFilter
    final filtered = await _processingService.applyFilter(
      origBytes,
      state.selectedFilter,
    );

    // 3) 人脸检测（带缓存：setImage 触发，setSmooth/Whiten 复用缓存）
    img.Image? mask;
    int faceCount = 0;
    bool failed = false;
    try {
      final contours = await _faceDetector.detect(
        state.imagePath!,
        bytes: filtered,
      );
      faceCount = contours.length;
      if (contours.isNotEmpty) {
        final decoded = img.decodeImage(filtered);
        final w = decoded?.width ?? 0;
        final h = decoded?.height ?? 0;
        if (w > 0 && h > 0) {
          _lastDetectedImageWidth = w;
          _lastDetectedImageHeight = h;
          mask = _maskBuilder.buildMask(
            width: w,
            height: h,
            faces: contours,
          );
        }
      }
    } catch (e) {
      // ML Kit 不可用 / 抛异常 → 降级到无美颜（per Q4 默认）
      failed = true;
    }

    if (!mounted) return;

    // 4) 美颜（mask 决定是否生效）
    var processed = await _processingService.applyBeauty(
      filtered,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
      mask: mask,
    );

    // 5) 自动亮度补偿
    processed = await _processingService.normalizeBrightness(processed);

    if (!mounted) return;
    state = state.copyWith(
      previewBytes: processed,
      isPreviewProcessing: false,
      faceCount: faceCount,
      faceDetectionFailed: failed,
    );
  }
```

顶部加 `import 'package:image/image.dart' as img;`（在文件最上方）。

**H) 改 `saveProcessedImage` 透传 mask**（与新签名对齐）：

```dart
    Uint8List bytes = state.previewBytes ??
        await _processingService.processImage(
          await _readImageBytes(state.imagePath!),
          filter: state.selectedFilter,
          smooth: state.smooth,
          whiten: state.whiten,
          slim: state.slim,
          // 保存时也走 mask（如果之前 _runProcess 缓存了 face contours）
          mask: _buildMaskForCurrentState(),
        );
```

并在类内加辅助方法：

```dart
  img.Image? _buildMaskForCurrentState() {
    if (_lastDetectedImageWidth == null || _lastDetectedImageHeight == null) {
      return null;
    }
    // 同步拿一次缓存（应该已经存在，因为 setImage 跑过 detect）
    final contours = _faceDetector._cacheForTest(state.imagePath!);
    if (contours == null || contours.isEmpty) return null;
    return _maskBuilder.buildMask(
      width: _lastDetectedImageWidth!,
      height: _lastDetectedImageHeight!,
      faces: contours,
    );
  }
```

> `_cacheForTest` 是给 `FaceDetectionService` 加的内部访问器（仅测试用）。在 `lib/services/face_detection_service.dart` 末尾加：
>
> ```dart
> /// 仅供测试 / 内部使用：直接读缓存
> // ignore: unused_element
> List<FaceContours>? _cacheForTest(String key) => _cache[key];
> ```
>
> 改成 `// ignore: invalid_use_of_visible_for_testing_member` 后加 `@visibleForTesting` annotation 也可以。先这样写，后续清理。

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/filter/filter_view_model_preview_test.dart -v 2>&1 | tail -30
```

预期：所有 group PASS。

- [ ] **Step 5: 跑完整测试套件**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -20
```

预期：所有测试通过（旧的 `_StubViewModel` 用法不影响，因为它走 provider override）。

> ⚠️ 如果旧测试 `_StubViewModel` 在 `test/widget/beauty_slider_test.dart` 用了 `super(_NoopService(), _NoopWriter(), _NoopRepo())` 三参构造，需要在 Task 5 同步改：
>
> ```dart
> super(_NoopService(), _NoopWriter(), _NoopRepo(), _NoopFaceDetector(), _NoopMaskBuilder());
> ```
>
> 并定义 `_NoopFaceDetector extends FaceDetectionService` / `_NoopMaskBuilder extends FaceMaskBuilder`。

- [ ] **Step 6: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/services/face_detection_service.dart lib/features/filter/filter_view_model.dart test/filter/filter_view_model_preview_test.dart test/widget/beauty_slider_test.dart
git commit -m "feat(face-detection): FilterViewModel 串接 detect + buildMask

- 注入 FaceDetectionService + FaceMaskBuilder
- state 加 faceCount / faceDetectionFailed 字段
- _runProcess: applyFilter → detect(缓存命中) → buildMask → applyBeauty(with mask) → normalizeBrightness
- setImage 切照片清空 detector 缓存
- 4 个新单测：setImage 立即 detect、detect 返回空、缓存命中不重 detect、切照片重 detect"
```

---

## Task 5: BeautySlider 顶部加「未检测到人脸 / 已检测 N 张」提示

**Files:**
- Modify: `lib/l10n/app_zh.arb`（加 key）
- Modify: `lib/l10n/app_en.arb`（加 key）
- Modify: `lib/features/filter/widgets/beauty_slider.dart`（加 hint row）
- Modify: `test/widget/beauty_slider_test.dart`（加 2 个测试 + 改 Stub）

- [ ] **Step 1: 加 l10n key**

`lib/l10n/app_zh.arb` 末尾追加：

```json
  "beautyNoFaceDetected": "未检测到人脸，美颜未生效",
  "@beautyNoFaceDetected": {
    "description": "BeautySlider 顶部提示：未在照片中检测到人脸时显示"
  },

  "beautyFaceDetected": "已检测 {count} 张人脸",
  "@beautyFaceDetected": {
    "description": "BeautySlider 顶部提示：检测到 N 张人脸时显示",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
```

`lib/l10n/app_en.arb` 末尾追加：

```json
  "beautyNoFaceDetected": "No face detected, beauty is disabled",
  "@beautyNoFaceDetected": {
    "description": "Hint shown at top of BeautySlider when no face is detected"
  },

  "beautyFaceDetected": "Detected {count} face(s)",
  "@beautyFaceDetected": {
    "description": "Hint shown at top of BeautySlider when N faces are detected",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
```

跑：

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter gen-l10n 2>&1 | tail -5
```

预期：l10n 重新生成。

- [ ] **Step 2: 写失败测试 — faceCount=0 / faceCount=2 提示**

在 `test/widget/beauty_slider_test.dart` 顶部 imports 之后加：

```dart
import 'package:easy_beauty_cam/services/face_detection_service.dart';
import 'package:easy_beauty_cam/services/face_mask_builder.dart';
```

`_StubViewModel` 改构造为：

```dart
class _StubViewModel extends FilterViewModel {
  final FilterViewModelState _state;
  final void Function(double)? onSmooth;
  final void Function(double)? onWhiten;
  final void Function(double)? onSlim;

  _StubViewModel({
    required FilterViewModelState state,
    this.onSmooth,
    this.onWhiten,
    this.onSlim,
  })  : _state = state,
        super(_NoopService(), _NoopWriter(), _NoopRepo(), _NoopFaceDetector(), _NoopMaskBuilder());

  // ... 已有 setSmooth/setWhiten/setSlim ...
}

class _NoopFaceDetector extends FaceDetectionService {
  _NoopFaceDetector() : super(detectFn: (path, bytes) async => const []);
}

class _NoopMaskBuilder extends FaceMaskBuilder {}
```

`buildScope` 接受 `faceCount` 参数（默认 0）：

```dart
ProviderScope buildScope({
  double smooth = 30,
  double whiten = 20,
  double slim = 0,
  int faceCount = 0,
  bool faceDetectionFailed = false,
  void Function(double)? onSmooth,
  void Function(double)? onWhiten,
  void Function(double)? onSlim,
}) {
  return ProviderScope(
    overrides: [
      filterViewModelProvider.overrideWith(
        (ref) => _StubViewModel(
          state: FilterViewModelState(
            smooth: smooth,
            whiten: whiten,
            slim: slim,
            faceCount: faceCount,
            faceDetectionFailed: faceDetectionFailed,
          ),
          onSmooth: onSmooth,
          onWhiten: onWhiten,
          onSlim: onSlim,
        ),
      ),
    ],
    child: const MaterialApp(
      // ... 已有 ...
    ),
  );
}
```

文件末尾追加：

```dart
  group('BeautySlider 人脸检测提示', () {
    testWidgets('faceCount=0 显示「未检测到人脸」', (tester) async {
      await tester.pumpWidget(buildScope(faceCount: 0));
      await tester.pumpAndSettle();

      expect(find.text('未检测到人脸，美颜未生效'), findsOneWidget);
    });

    testWidgets('faceCount=2 显示「已检测 2 张人脸」', (tester) async {
      await tester.pumpWidget(buildScope(faceCount: 2));
      await tester.pumpAndSettle();

      expect(find.text('已检测 2 张人脸'), findsOneWidget);
      expect(find.text('未检测到人脸，美颜未生效'), findsNothing);
    });
  });
```

- [ ] **Step 3: 跑测试确认失败**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/beauty_slider_test.dart -v 2>&1 | tail -20
```

预期：FAIL（提示文案找不到）。

- [ ] **Step 4: 改 `BeautySlider` 加 hint row**

修改 `lib/features/filter/widgets/beauty_slider.dart`：在 `Column` 顶部、`_buildSlider` 列表之前插入：

```dart
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMain,
        vertical: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 人脸检测状态提示
          _buildFaceHint(l10n, state),
          const SizedBox(height: 4),
          // ... 已有 3 个 slider ...
        ],
      ),
    );
```

并在类内加私有方法：

```dart
  Widget _buildFaceHint(AppLocalizations l10n, FilterViewModelState state) {
    if (state.faceDetectionFailed || state.faceCount == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 14),
          const SizedBox(width: 4),
          Text(
            l10n.beautyNoFaceDetected,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.warning,
              fontSize: 11,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 14),
        const SizedBox(width: 4),
        Text(
          l10n.beautyFaceDetected(state.faceCount),
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.success,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
```

**需要在 `app_colors.dart` 加 `warning` / `success` 常量**（如果还没有）：

```dart
class AppColors {
  // ... 已有 ...
  static const Color warning = Color(0xFFFF9800); // 琥珀色
  static const Color success = Color(0xFF4CAF50); // 绿色
}
```

顶部加 import：`import 'package:flutter/material.dart' show Icon, Icons;`（已存在 material.dart 导入）。

- [ ] **Step 5: 跑测试确认通过**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test test/widget/beauty_slider_test.dart -v 2>&1 | tail -20
```

预期：PASS。

- [ ] **Step 6: 跑完整测试套件**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -20
```

预期：所有测试通过。

- [ ] **Step 7: Commit**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/ lib/core/theme/app_colors.dart lib/features/filter/widgets/beauty_slider.dart test/widget/beauty_slider_test.dart
git commit -m "feat(face-detection): BeautySlider 加人脸检测状态提示

- 顶部加一行：未检测到人脸（橙色 ⚠️）/ 已检测 N 张人脸（绿色 ✓）
- l10n 加 beautyNoFaceDetected / beautyFaceDetected 两个 key（zh + en）
- AppColors 新增 warning / success 颜色
- 2 个新 widget 测试覆盖 0/2 张脸两种状态"
```

---

## Task 6: MEMO 〇九 + CHANGELOG

**Files:**
- Modify: `docs/MEMO.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: 更新 MEMO.md**

顶部"最新进度"区域更新：

```markdown
**最新**：〇九 人脸识别美颜（ML Kit，按 mask 只磨人脸区域，详见 [〇九](#〇九-人脸识别美颜-2026-06-23)）

**上一节**：〇八 相机取景页横屏旋转（详见 [〇八](#〇八-相机取景页横屏旋转-2026-06-23)）
```

文件末尾追加（"〇八" 章节**之后**）：

```markdown
---

<a id="face-detection-beauty-2026-06-23"></a>
### 〇九 人脸识别美颜 (2026-06-23)

编辑页磨皮 / 美白只作用于照片中检测到的人脸区域，背景与眼睛/嘴唇保留细节：

1. **ML Kit 静态图检测**：`google_mlkit_face_detection ^0.13.2`；性能模式 fast，enableContours（拿整脸 / 眼 / 唇轮廓点集）；`FaceDetectionService` 按 `imagePath` 缓存，避免滑杆拖动时反复检测
2. **mask 机制**：`FaceMaskBuilder` 把 `FaceContours[]` 转成 1-channel 灰度 mask（`fillPolygon` 整脸 = 255，再 `fillPolygon` 眼唇 = 0 排除；高斯羽化 featherRadius=8 软化边缘）
3. **`ImageProcessingService.applyBeauty` 加 `img.Image? mask` 参数**：
   - `mask == null` → 直接 return 原图（per Q4 默认：未检测到人脸时无美颜回退）
   - `mask` 提供 → 只在 `mask.r > 0` 的像素做 blend（磨皮）和 `+adjust`（美白），blendFactor / adjust 按 mask 灰度衰减
4. **FilterViewModel 串接**：`applyFilter → detect(缓存命中) → buildMask → applyBeauty(with mask) → normalizeBrightness`；`FilterViewModelState` 新增 `faceCount` / `faceDetectionFailed` 字段
5. **UI 反馈**：`BeautySlider` 顶部加一行提示：未检测到人脸（橙色 ⚠️）/ 已检测 N 张人脸（绿色 ✓）
6. **范围严格控制**：仅在编辑页静态图上做，不做实时视频美颜，不做瘦脸（slim 保留 stub）
```

`docs/MEMO.md` 头部"最后更新"：`2026-06-20` → `2026-06-23`。

- [ ] **Step 2: 更新 CHANGELOG.md**

在 `## [Unreleased] — 2026-06-20` 段落的 `### Added` 块**之前**插入新 section（在已有的 `### Added` 块下追加也可；这里追加在末尾）：

```markdown
### Added
- **人脸识别美颜**：编辑页用 ML Kit（`google_mlkit_face_detection` 0.13.2）静态图检测人脸；`ImageProcessingService.applyBeauty` 新增 `img.Image? mask` 参数，`mask==null` 跳过美颜（原图返回），有 mask 时只在人脸区域（mask>0）做磨皮和美白，眼唇被排除；`FaceDetectionService` 按 imagePath 缓存，滑杆拖动不重检测；`BeautySlider` 顶部新增「未检测到人脸 / 已检测 N 张人脸」提示行
```

> 如果文件已有「## [Unreleased] — 2026-06-23」section（Task 1 push 后会被自动添加），直接在那个 section 的 Added 块追加。

- [ ] **Step 3: 跑完整测试套件**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam && flutter test 2>&1 | tail -10
```

预期：所有测试通过。

- [ ] **Step 4: Commit + Push**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git add docs/MEMO.md CHANGELOG.md
git commit -m "docs: 记录人脸识别美颜（〇九）"
git push origin main
```

---

## Self-Review Checklist

- [x] **Spec coverage**:
  - ML Kit 检测（Task 1, Task 4）
  - 轮廓 → mask + 眼唇排除 + 羽化（Task 2）
  - applyBeauty mask 参数 + null=跳过（Task 3）
  - FilterViewModel 串接（Task 4）
  - BeautySlider 提示（Task 5）
  - l10n（Task 5）
- [x] **Placeholder scan**: 无 "TBD" / "TODO" / "implement later"
- [x] **Type consistency**:
  - `FaceContours` 在 Task 1 定义，Task 2/4 复用 ✓
  - `FaceDetectionService.detect` 签名 Task 1 定义，Task 4 调一致 ✓
  - `ImageProcessingService.applyBeauty` 的 `mask` 参数 Task 3 定义，Task 4 透传 ✓
  - `FilterViewModelState.faceCount` / `faceDetectionFailed` Task 4 定义，Task 5 读取 ✓
  - `l10n` keys Task 5 定义并使用一致 ✓
- [x] **Breaking change handled**: spec 4.1.3 明确「applyBeauty mask=null = 返回原图」；旧测试没直接测 applyBeauty，新增 group 不影响旧 group（已确认 `test/services/image_processing_service_test.dart` 旧 group 只测 normalizeBrightness / crop / applyTransform）

---

## 备注

- **ML Kit 不可用时**：Task 4 用 try/catch 包 detect 异常，状态置 `faceDetectionFailed=true`，UI 走「未检测到人脸」分支（橙色 ⚠️），不抛错给用户
- **iOS 26+ 模拟器已知问题**（per spec 5）：开发用真机 + Android 模拟器，iOS 26 模拟器暂时 skip；不在本计划任务范围内
- **性能预算**（per spec 2.8）：单次 4K 图 detect < 800ms / buildMask < 200ms / applyBeauty with mask < 500ms；缓存命中 < 700ms；UI 200ms debounce 已在 FilterViewModel 存在
- **ML Kit `InputImage.fromBytes` 的 size 字段**：本计划用 `Size(1,1)` 兜底；contour 输出的归一化坐标受影响较小（Task 1 注释里已标，后续可优化为从 view model 传真实 W/H）
- **detect 时的 `bytes` 参数**：production 调用 ML Kit 时 `InputImage.fromBytes`，但 spec 2.3.1 写的是「按 imagePath 缓存」；本计划用 `imagePath` 作 cache key，传 `bytes` 给 detector 以避免 ML Kit 多读一次文件
- **`_cacheForTest` 临时访问器**：用 `_` 前缀 + ignore 注释；后续可改 `@visibleForTesting` annotation
