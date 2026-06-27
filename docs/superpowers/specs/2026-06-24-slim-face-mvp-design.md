# 瘦脸算法 MVP 设计

> **For agentic workers:** 后续实现走 writing-plans → TDD 流程。
>
> **用户决策已对齐**（2026-06-24）：
> - 验证方法 = CLI 脚本 (A) + UI 滑杆 (B)
> - Landmark = mediapipe_face_mesh 468 点 (B)
> - 算法范围 = 2D 单脸 + 统一推力 (A)
> - 测试图 = `assets/test/photo1.jpg`
> - 路径 = Day 1 CLI → Day 2 UI

**Date:** 2026-06-24
**Status:** Approved（用户授权跳过逐节确认，直接执行）

---

## 1. 背景与目标

### 1.1 现状
- `ImageProcessingService.applyBeauty` 的 `slim` 参数是 stub，UI 滑杆滑动无视觉变化
- 当前 iOS 端人脸检测用 Apple Vision（~64 点 2D），点数不足以做精细瘦脸 warp
- 工业级瘦脸需要 468 点 3D mesh + 三角剖分 + 反向映射 warp，业内主流方案（美图、抖音、Snapchat）

### 1.2 目标（MVP 范围）
**只验证一件事：基于 468 点 mesh 的瘦脸 warp 算法能不能在 Flutter 上跑通。**

- ✅ 集成 `mediapipe_face_mesh` Flutter 包（iOS）
- ✅ 实现「三角剖分 + 仿射变换 + 反向映射」瘦脸算法
- ✅ Day 1：CLI 脚本 `tool/slim_mvp.dart` 读 `assets/test/photo1.jpg` → 输出 `build/slim_mvp_output.jpg`
- ✅ Day 2：接到 `filter_panel` 的瘦脸滑杆，滑动产生视觉变化

### 1.3 非目标（明确不做）
- ❌ 头转向 / 多脸 / 分区独立强度（要等算法验证后再加）
- ❌ Android 端接入（Phase 2）
- ❌ 性能优化到 < 500ms（MVP 慢一点能跑就行）
- ❌ 算法参数调优（默认参数先用起来）
- ❌ UI 美化（保持现有 `BeautySlider` 不动）

### 1.4 成功判据
- CLI 脚本能跑通，`build/slim_mvp_output.jpg` 是清晰可辨认的瘦脸后人像
- UI 滑杆从 0 → 100 能看到下颌区域像素明显向脸中心收
- 至少 1 个算法单元测试通过（warp 数学正确性）

---

## 2. 设计

### 2.1 核心算法（业界标准）

```
468 个 landmark + 900 个三角剖分（MediaPipe 已给出 triangles）
            ↓
   识别「瘦脸区域」三角片（下颌 + 颧骨 + 下巴）
            ↓
   对每个 anchor landmark 计算目标位置（往脸中心推）
            ↓
   对每个目标三角片求 forward 仿射 (src → dst)，再求 inverse
            ↓
   反向映射遍历输出像素 → 双线性采样
            ↓
   强度滑杆控制总位移比例
```

### 2.2 关键参数（MVP 默认值）

| 参数 | 默认值 | 说明 |
|---|---|---|
| 强度映射 | `offset = faceRadius * 0.15 * strength` | strength ∈ [0, 1] |
| 距离衰减 | `scale = (1 - distance/faceRadius).clamp(0.3, 1.0)` | 凸起区域（眼/鼻）保留 |
| 脸中心 | `(landmarks[1] + landmarks[168]) / 2` | 鼻尖 + 鼻中平均 |
| 脸半径 | landmarks[152]（下巴）到 脸中心 距离 | 简化估算 |
| 瘦脸区域 landmark | jawLeft + jawRight + chin + cheekLeft + cheekRight | MediaPipe 标准索引 |

### 2.3 数据流

**CLI 脚本（Day 1）**：
```
photo1.jpg
  → FaceMeshDetector.detect(bytes) → FaceMesh (468 points + triangles)
  → SlimWarpService.applySlim(bytes, strength=0.5, mesh)
  → output.jpg (write to build/)
```

**UI 集成（Day 2）**：
```
用户选图
  → FilterViewModel.setImage(path)
  → FaceDetectionService (新加 mediapipe 分支) → List<FaceMesh>
  → 缓存 (key = imagePath)
  → 滑杆滑动 → ImageProcessingService.processImage(..., slim)
  → SlimWarpService.applySlim(filteredBytes, strength=slim/100, mesh)
  → 实时预览
```

### 2.4 文件结构

```
lib/services/
  face_mesh_detector.dart        # 新增：mediapipe_face_mesh Dart 包装
  slim_warp_service.dart         # 新增：瘦脸算法核心
tool/
  slim_mvp.dart                  # 新增：CLI 脚本（Day 1）
test/
  slim_warp_service_test.dart    # 新增：算法单元测试（数学正确性）
test/widget/
  slim_slider_integration_test.dart  # 新增：UI 滑杆集成测试（Day 2）
assets/test/photo1.jpg           # 已存在（用户自拍）
pubspec.yaml                     # 修改：+ mediapipe_face_mesh: ^1.8.1
ios/Podfile                      # 包自动接入，无需手改
```

### 2.5 组件 API

#### 2.5.1 `lib/services/face_mesh_detector.dart`

```dart
class FaceMeshResult {
  final List<Point> landmarks;   // 468 点，归一化坐标 [0, 1]
  final List<int> triangles;    // 三角剖分（每 3 个 index 为一个三角片）
  final int imageWidth;
  final int imageHeight;

  /// 把归一化 landmark 转换为像素坐标
  List<Point> landmarksInPixels();
}

class Point {
  final double x, y, z;
}

class FaceMeshDetector {
  FaceMeshDetector();  // 生产模式：初始化 mediapipe processor

  /// 静态图检测
  Future<FaceMeshResult?> detect(Uint8List imageBytes);

  void dispose();
}
```

#### 2.5.2 `lib/services/slim_warp_service.dart`

```dart
class SlimWarpService {
  /// 应用瘦脸 warp
  ///
  /// - [strength] ∈ [0, 1]：0 = 原图，1 = 最大瘦脸
  /// - [mesh]：mediapipe 检测结果（null = 返回原图）
  Future<Uint8List> applySlim(
    Uint8List imageBytes, {
    required double strength,
    required FaceMeshResult? mesh,
  });

  void dispose();
}
```

#### 2.5.3 `tool/slim_mvp.dart`

```dart
import 'dart:io';
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';

Future<void> main() async {
  print('=== Slim Face MVP ===');

  // 1. 读图
  final inputBytes = await File('assets/test/photo1.jpg').readAsBytes();
  print('Read photo1.jpg (${inputBytes.length} bytes)');

  // 2. 检测 468 点 mesh
  final detector = FaceMeshDetector();
  final mesh = await detector.detect(inputBytes);
  if (mesh == null) {
    print('ERROR: 未检测到人脸');
    exit(1);
  }
  print('Detected ${mesh.landmarks.length} landmarks, ${mesh.triangles.length ~/ 3} triangles');

  // 3. 应用 warp
  final warp = SlimWarpService();
  final output = await warp.applySlim(inputBytes, strength: 0.5, mesh: mesh);
  print('Warped output (${output.length} bytes)');

  // 4. 写文件
  await Directory('build').create(recursive: true);
  await File('build/slim_mvp_output.jpg').writeAsBytes(output);
  print('Written to build/slim_mvp_output.jpg');
}
```

---

## 3. Files to Add / Modify

| 文件 | 变更类型 | 责任 |
|---|---|---|
| `pubspec.yaml` | 修改 | + `mediapipe_face_mesh: ^1.8.1` |
| `lib/services/face_mesh_detector.dart` | 新建 | mediapipe FFI 包装 |
| `lib/services/slim_warp_service.dart` | 新建 | 三角剖分 + 仿射变换算法 |
| `tool/slim_mvp.dart` | 新建 | CLI 脚本 |
| `test/slim_warp_service_test.dart` | 新建 | 算法单元测试 |
| `test/widget/slim_slider_integration_test.dart` | 新建（Day 2） | UI 集成测试 |
| `lib/services/image_processing_service.dart` | 修改（Day 2） | `applyBeauty` / `processImage` 调 SlimWarpService |
| `lib/services/face_detection_service.dart` | 修改（Day 2） | iOS 分支加 mediapipe_face_mesh 选项 |
| `lib/features/filter/filter_view_model.dart` | 修改（Day 2） | 注入 SlimWarpService，slim 滑杆触发 warp |
| `CHANGELOG.md` | 修改 | 记录瘦脸 MVP |
| `docs/MEMO.md` | 修改 | 〇十二 记录瘦脸算法落地 |

> **不动**：`filter_panel.dart` 结构、`beauty_slider.dart` 结构（外观）、AppBar、相机流程

---

## 4. Tests

### 4.1 单元测试（Day 1）

**`test/slim_warp_service_test.dart`**：

| # | 测试 | 验证 |
|---|---|---|
| 1 | `applySlim(strength=0) → 原图` | 强度 0 完全无变化（字节相等） |
| 2 | `applySlim(mesh=null) → 原图` | 无 mesh 时直接返回 |
| 3 | `applySlim(strength=1, 合成 mesh) → 瘦脸区域像素明显向内移` | 像素坐标对比 |
| 4 | `applySlim 不修改外部输入 imageBytes` | 不可变性 |
| 5 | 双线性采样边界（src 坐标在图外） | 不崩溃、不越界 |
| 6 | `FaceMeshResult.landmarksInPixels()` 正确性 | 归一化坐标 → 像素 |

**`test/face_mesh_detector_test.dart`**（基础）：
- mock mediapipe processor（不让真检测跑 CI）
- `detect(valid bytes) → mesh`
- `detect(invalid bytes) → null`

### 4.2 Widget 测试（Day 2）

**`test/widget/slim_slider_integration_test.dart`**：
- 滑杆从 0 → 100，`processImage` 被调用且 `slim` 参数正确传递
- `applyBeauty(slim=0)` 不调 `SlimWarpService.applySlim`
- 旧的「无脸检测」测试仍然通过

### 4.3 手动验证（真机 / 模拟器）

- iOS Simulator（Apple Silicon）跑 `flutter run -d <sim>`
- CLI 跑 `dart run tool/slim_mvp.dart`
- 打开 `build/slim_mvp_output.jpg` 视觉确认：
  - 下颌区域明显向内收
  - 眼睛、鼻子、嘴不动
  - 无明显接缝 / 撕裂

---

## 5. Risks & Mitigations

| 风险 | 影响 | 缓解 |
|---|---|---|
| **`mediapipe_face_mesh` iOS Pod 缺 arm64 sim**（历史坑） | 模拟器跑不起来 | Day 1 第一时间 `pod install` + 跑 simulator；失败立即回退到「用 64 点跑通算法」策略（用户已批准的方案 C） |
| 模型加载慢（face_mesh.tflite 1.24 MB） | 首次 `detect` 卡 500ms+ | 接受；后续可后台预热 |
| 4K 图处理时间 > 3s | 实时预览卡 | MVP 不优化；Phase 2 加 `copyResize` 缩到 1080p |
| 仿射变换矩阵求逆失败（奇异三角） | warp 崩溃 | 检查 determinant < 1e-6 跳过该三角 |
| 双线性采样坐标越界 | 内存错误 | `clamp(0, width-1)` / `clamp(0, height-1)` 兜底 |
| `image` 包不直接支持 RGBA bytes 给 mediapipe | 输入转换坑 | 用 `image.convert(numChannels: 4)` 转 RGBA 再 `getBytes()` |
| `triangles` 字段在 mediapipe 包里的命名 | API 不一致 | 实际实现时读 `mediapipe_face_mesh.dart` 源码确认 |
| 用户没真脸照 / 多脸照 | 测试输入不够 | MVP 只验证单人脸；多脸是 Phase 2 |

---

## 6. Out of Scope（明确不做）

- 头转向支持（yaw / pitch / roll）
- 多脸同时处理
- 分区独立强度（颧骨 / 下颌 / 下巴分三组滑杆）
- 大眼、鼻梁、下巴等其它形变
- 实时预览（仅静态图编辑）
- GPU shader 优化（Metal / OpenGL）
- Android 端集成
- 美学参数调优（推到哪个方向、推多少的美术工作）
- 美颜预设（"轻度" / "重度" 一键）
- 算法单元测试覆盖率 > 80%

---

## 7. Day 1 vs Day 2 范围拆分

### Day 1（CLI 脚本）
- [ ] `pubspec.yaml` 加 `mediapipe_face_mesh: ^1.8.1`
- [ ] `dart pub get` + `cd ios && pod install`
- [ ] `lib/services/face_mesh_detector.dart` —— mediapipe 包装
- [ ] `lib/services/slim_warp_service.dart` —— warp 算法
- [ ] `tool/slim_mvp.dart` —— CLI 脚本
- [ ] `test/slim_warp_service_test.dart` —— 算法单测
- [ ] 跑 `dart run tool/slim_mvp.dart` + 视觉确认

**Day 1 成功判据**：`build/slim_mvp_output.jpg` 是瘦脸后的清晰人像。

### Day 2（UI 集成）
- [ ] `image_processing_service.dart` `applyBeauty` 接 `SlimWarpService`
- [ ] `face_detection_service.dart` 加 mediapipe_face_mesh 选项（替换 Apple Vision 或并存）
- [ ] `filter_view_model.dart` 注入 `SlimWarpService`
- [ ] `test/widget/slim_slider_integration_test.dart`
- [ ] iOS 模拟器 / 真机跑通 `flutter run`
- [ ] CHANGELOG + MEMO 更新

**Day 2 成功判据**：滑杆从 0 → 100 实时看到瘦脸效果。

---

## 8. 后续 Phase（不在 MVP 范围）

**Phase 2（方案 B 完整版，2-3 周）**：
- 头转向权重（per-region push strength）
- 分区独立滑杆（颧骨 / 下颌 / 下巴）
- 美学参数调优
- 性能优化到 < 500ms
- Android 接入
- GPU shader（可选）

**Phase 3（商业级，1-2 月）**：
- 大眼、鼻梁、下巴等多个形变维度
- 多人脸独立参数
- 美学预设（轻度 / 重度 / 网红 / 写真）