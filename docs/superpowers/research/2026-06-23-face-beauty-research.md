# 人脸识别 + 区域美颜方案调研

> 调研日期：2026-06-23
> 目标项目：easyBeautyCam
> 触发背景：当前 `lib/services/image_processing_service.dart` 的美颜（`applyBeauty`）对全图统一做高斯模糊 + 提亮，导致背景/服装/头发也被「磨皮」，效果失真。需要升级为「仅人脸区域」美颜。

---

## 1. 调研目标

把 easyBeautyCam 的「美颜」从「全图无差别」升级为「仅作用于人脸区域」：

1. **人脸检测**：在原图上找到人脸（位置 + 形状）。
2. **区域 mask**：把检测结果转成一张与原图同尺寸的灰度蒙版（mask），人脸区域 = 1.0，非人脸 = 0.0，边缘做羽化。
3. **局部美颜**：把 mask 传入美颜算法（高斯模糊 + 美白），只对人脸像素生效。
4. **性能**：单张 4K 图（4032×3024）处理 ≤ 1s；滑块变化时无明显卡顿。

约束：
- iOS + Android 双端可用。
- 不依赖服务端（纯端侧）。
- License 友好（MIT / Apache / BSD）。
- 与现有 `image` package 处理管线衔接。

---

## 2. 人脸检测库对比

下表是当前主流的 Flutter 人脸检测方案，**只针对「静态图片（已拍照 / 已存盘）」** 这一场景评估（live camera 的 `face_camera` 等不适用，但作为参考列出）。

| 库 | 最新版 / 发布日期 | License | 平台 | 静态图 | 输出 | 体积 | 评分 |
|---|---|---|---|---|---|---|---|
| **google_mlkit_face_detection** | 0.13.2 / 2026-02-03 | MIT | iOS+Android | ✅ `InputImage.fromFilePath` / `fromBytes` / `fromBitmap` | `boundingBox` + 10 landmarks + 13 contours（含 face 椭圆） | 模型 ~3.4MB（按需下载） | pub 150/160、85k 下载/月、4 open issues、1.2k stars、pushed 2026-06-18 |
| **google_mlkit_face_mesh_detection** | 0.4.2 / 2026-02-03 | MIT | iOS+Android | ✅ | 468 点 face mesh（点密度远超 ML Kit Face） | 模型 ~5MB | pub 150/160、21 likes |
| **mediapipe_face_mesh** | 1.8.1 / 2026-06-21 | BSD-3 | iOS+Android | ✅ | 468 点 face mesh + 检测框 | 模型 ~10MB | pub 160/160、1.7k 下载/月、BSD-3 |
| **face_camera** | 0.1.4 / 2024-11-01 | MIT | iOS+Android | ❌ 仅 live preview（用 `google_mlkit_face_detection` 底层） | boundingBox | — | pub 130/160 |
| **face_detection_tflite** | 6.4.1 / 2026-06-18 | Apache-2 | iOS+Android+macOS+Windows+Linux+Web | ✅ TFLite 多模型（人脸/landmark/embedding/segmentation） | 完整 segmentation mask + 关键点 | 模型自带（多个 tflite 文件） | pub 暂无、github cornpip |
| **face_detection** (Go-based) | 0.0.6 / 2022-06-28 | 未明示 | iOS+Android | ✅ | boundingBox + 简单 landmark | 小（Go binary） | 4 年未更新，**不推荐** |
| **opencv_dart** / **dartcv4** | 2.2.1+4 / 2026-02-26 | Apache-2 | iOS+Android+桌面 | ✅（OpenCV Haar cascade / DNN） | boundingBox（需自己拼 landmark） | 库 30-80MB | pub 暂无独立 score、github 249 stars、pushed 2026-04-10 |
| **facebetter_flutter** | 1.4.4 / 2026-06-08 | **商业 SDK（PixPark）** | iOS+Android | ✅ 自带完整美颜引擎 | 美颜结果直接出图 | n/a | — |

### 关键发现

1. **`google_mlkit_face_detection`** 0.13.2 是「够用且免费」的最佳选择 —— 有 `FaceContourType.face`（整张脸的椭圆轮廓点集），正好对应方案 C 的人脸 mask；体积最小、文档最全、Flutter 社区最成熟。
2. **`mediapipe_face_mesh`** 是 468 点 mesh 的最强方案，但模型 ~10MB，且对「磨皮」这种粗粒度任务**过剩**（用不到 468 个点）。
3. **`facebetter_flutter`** 是商业闭源 SDK，license 不友好，不适合做「自研可控」的磨皮功能。
4. **`face_camera`** 是 live-preview UI 控件，**不能**直接处理已拍好的照片。
5. **`face_detection_tflite`** 同时提供 face segmentation（皮肤 mask），是更激进的方案，但集成了 TFLite + OpenCV 两套原生库，APK 体积会大很多（>30MB）。
6. **ML Kit 在 iOS 26+ 模拟器上有 build 问题**（issue: "Apple Silicon arm64 Simulator Build Failure (iOS 26+)"），需要真机或等修复。

---

## 3. 美颜算法概览

「磨皮」本质上就是 **保边噪声/瑕疵消除**：把皮肤上的毛孔、细纹、斑点去掉，但保留五官轮廓（鼻梁、眼眶、唇线）的锐度。

### 3.1 经典算法对比

| 算法 | 保边 | 速度 | 适合手机 | Flutter `image` 包支持？ |
|---|---|---|---|---|
| **高斯模糊 + 原图混合** | ❌（边缘一起糊） | 极快 | ✅（最常用 baseline） | ✅ `gaussianBlur(src, radius:)` |
| **双边滤波 (Bilateral Filter)** | ✅ | 慢（O(N·r²)） | 早期美图/天天P图 | ❌（`image` 包没有） |
| **导向滤波 (Guided Filter)** | ✅✅ | 中 | 主流（Faceu/Snapchat 早期） | ❌ |
| **表面模糊 (Surface Blur)** | ✅ | 中 | Meitu、Camera360 | ❌ |
| **频域分离（低频提亮 + 高频衰减）** | ✅ | 中 | 高端机型 | ❌ |
| **磨皮算法（保边 + 提亮）** | ✅ | 中 | 商业 SDK（facebetter） | 部分支持（高斯 + 提亮） |

### 3.2 现状（easyBeautyCam 现有实现）

`image_processing_service.dart` 第 115-146 行用的是**高斯模糊 + blendFactor**：
```dart
final blurred = img.gaussianBlur(result, radius: radius);
final blendFactor = smooth / 500;
// blend 回去
```

这是「全图统一」磨皮 —— 头发、衣服、天空都会被「磨」掉，是廉价相机 app 的通病。

### 3.3 业界做法

- **Faceu / Snapchat / Meitu**：底层用 **导向滤波** 或 **表面模糊** + **频域处理**，配合人脸 mask 限制作用域。
- **轻量替代**：高斯模糊 + **soft mask（羽化边缘）**。在「磨皮」这种中等强度（radius ≤ 4）的场景下，**人眼看不出与双边滤波的差别**，但速度是后者的 5-10x。
- **当前 Flutter 生态最佳实践**：`image` 包的 `gaussianBlur` 自带 `mask` 参数（luminance 0~1），与 mask=1 的区域 100% 混合，与 mask=0 的区域保持原图。这正是我们需要的「区域美颜」。

### 3.4 推荐算法

**先不上双边/导向滤波**，因为：
1. `image` 包没实现，要自己写 C 层 / FFI。
2. 当前磨皮强度（radius ≤ 2、blendFactor ≤ 0.20）属于「轻磨皮」，高斯+软 mask 已经够用。
3. 真要升级时，再加 `opencv_dart`（已是 FFI，3-5ms 一次）。

---

## 4. 区域 mask 方案

拿到人脸检测结果后，怎么转成一张 mask 图？三种策略：

### 方案 A：bounding box mask（最简单）

用人脸矩形框直接生成一个白色矩形 mask。

```
mask[y, x] = 1.0 if x ∈ [x1, x2] and y ∈ [y1, y2] else 0.0
```

- ✅ **实现最简单**：10 行代码。
- ✅ **性能最佳**：一次 fillRect 搞定。
- ❌ **效果差**：眼睛、嘴巴、眉毛、鼻孔会被一起磨掉；脸和脖子/耳朵之间有硬边。
- ❌ **多人脸/侧脸/低头**容易切到非人脸区域。

### 方案 B：landmarks 椭圆 mask（推荐起点）

用 ML Kit 的 10 个 landmarks（左/右耳、左/右眼、鼻子、嘴）构造一个椭圆/凸包。

```
// 用 leftEar + rightEar + bottomMouth 三个点构造椭圆
ellipse.center = midpoint(leftEar, rightEar)
ellipse.width  = distance(leftEar, rightEar) * 1.4
ellipse.height = distance(ear, bottomMouth) * 1.2
```

- ✅ **实现简单**：30 行代码。
- ✅ **边缘自然**：椭圆天然平滑，不需要额外羽化。
- ✅ **覆盖度合理**：包含额头、脸颊、下巴。
- ❌ **仍会磨到眼睛和嘴**（这两个在椭圆内部）。
- ❌ **极端角度**（低头 60°+）时椭圆形状不准。

### 方案 C：face contour 软 mask（推荐）

用 ML Kit `FaceContourType.face` 的 35-50 个轮廓点构造一个**填充多边形 + 高斯羽化**的 mask。

```
1. 取 face contour 的 points（int） → List<Point>
2. img.fillPolygon(mask, color=ColorRgba8(255,255,255,255), points)
3. 对 mask 做 gaussianBlur(mask, radius: 15)  // 羽化边缘
4. （可选）排除眼睛轮廓：把 face contour.eyes/upperLip/lowerLip/nose 区域 mask 设 0
```

- ✅ **效果最好**：脸型精确，边缘羽化自然。
- ✅ **可加眼睛/嘴唇 exclusion**：让眼睛和唇线保持锐利。
- ❌ **实现稍复杂**：60-100 行代码（要写 fillPolygon 或调 OpenCV）。
- ❌ **多了一层 mask 高斯**：增加 ~50ms（4K 图上）。

### 三方案对比

| 维度 | A (rect) | B (ellipse) | C (contour) |
|---|---|---|---|
| 效果 | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 难度 | ⭐ | ⭐⭐ | ⭐⭐⭐ |
| 速度 | 极快 | 快 | 中 |
| 美颜眼/唇 exclusion | ❌ | ❌ | ✅ |

### 推荐

**方案 C 作为主路径，方案 B 作为兜底**（如果 face contour 检测失败或 confidence 低时回退到椭圆）。方案 A 不用。

---

## 5. 性能优化策略

### 5.1 检测结果缓存

人脸检测是**最贵**的部分（200-500ms on 4K）。但**一张照片只应该检测一次**，然后缓存。

```dart
class FaceDetectionCache {
  final String _imageHash;        // SHA1(imageBytes)
  List<Face>? _faces;
  DateTime? _detectedAt;

  Future<List<Face>> getFaces(Uint8List imageBytes) async {
    final hash = sha1.convert(imageBytes).toString();
    if (hash == _imageHash && _faces != null) return _faces!;
    _imageHash = hash;
    _faces = await _detect(imageBytes);
    return _faces!;
  }
}
```

应用点：
- 用户拖动「磨皮」滑块时，**复用** detection 结果，只重跑美颜。
- 用户切换滤镜/裁切时，**不重检测**（裁切后 mask 跟着裁切框 transform）。
- 用户换图时，**强制重检测**。

### 5.2 降采样检测

ML Kit 不需要 4K 输入来检测人脸 —— 把图先缩到 1024×768 再检测，再把检测到的 boundingBox/contour **按比例放大**到原图坐标。

- 4K 降采样到 1024×768：检测时间从 ~400ms → ~80ms。
- boundingBox.scale(原图.width / 检测图.width) 即可。

注意：ML Kit 的 contour 点集是相对输入图的，**坐标也要做线性变换**。

### 5.3 异步/线程

- ML Kit 的 `processImage` 内部已经异步，不会阻塞主线程。
- `image` 包的 `gaussianBlur` / `fillRect` 是**同步** CPU 密集操作，4K 图上单次 ~150-300ms → 会卡 UI。
- **必须**用 `compute()`（Isolate.run）把整个 `applyBeautyWithMask` 推到后台 isolate。
- 注意：isolate 间不能传 `img.Image` 对象（包含 native pixel buffer），需要传 `Uint8List`（PNG/JPG 字节）。

### 5.4 mask 缩放

mask 不需要和原图同尺寸。可以：
1. 在 1024×768 降采样图上生成 mask。
2. 用 `img.copyResize(mask, width: 原图.width)` 放大到原图尺寸。
3. 喂给原图的高斯模糊。

> ⚠️ `gaussianBlur` 的 mask 必须和 src 同尺寸（`separableConvolution` 按坐标取 mask 像素）。所以要么 mask 用原图尺寸，要么原图降采样处理（不推荐，会损失原画质）。

### 5.5 各步骤预期耗时（4K 图，iPhone 12 / 骁龙 888）

| 步骤 | 耗时 |
|---|---|
| 解码 PNG/JPG | 100-200ms |
| ML Kit 检测（降采样到 1024px） | 60-100ms |
| 生成 mask（fillPolygon + blur） | 30-80ms |
| mask 放大到原图尺寸 | 30-50ms |
| 高斯模糊（带 mask） | 200-400ms |
| 美白（带 mask 限制） | 100-200ms |
| 编码 PNG | 150-300ms |
| **总计** | **~700-1300ms** |

✅ 在「< 1.5s」的可接受范围；超 1s 时**先出降采样预览图**，再后台出全分辨率。

---

## 6. 推荐方案

### 6.1 选型

- **人脸检测库**：`google_mlkit_face_detection` 0.13.2
  - 理由：MIT 许可、Flutter 生态最成熟、体积小、有 face contour 完整椭圆、pub score 150/160。
- **Mask 策略**：方案 C（face contour 软 mask），方案 B（landmarks 椭圆）兜底
  - 理由：效果最好，代码量可控。
- **美颜算法**：维持现有 `gaussianBlur + blendFactor`（高斯+软 mask）
  - 理由：性能好、效果在「轻磨皮」场景下够用；后续可升级到 `opencv_dart` 的导向滤波。
- **并行策略**：
  - 整条管线在 `compute()` 跑（isolate）。
  - 检测结果按 imageHash 缓存。
  - 检测时图先降采样到 1024px。

### 6.2 依赖清单

```yaml
# pubspec.yaml 新增
dependencies:
  google_mlkit_face_detection: ^0.13.2
  google_mlkit_commons: ^0.11.1
  # （可选，未来用）
  opencv_dart: ^2.2.1+4
```

### 6.3 集成代码结构

```
lib/
├── services/
│   ├── image_processing_service.dart       # 现有，扩展 applyBeauty()
│   ├── face_detection_service.dart         # 新增：包装 ML Kit + 缓存
│   └── face_mask_builder.dart              # 新增：contour → 软 mask
```

---

## 7. 集成方案（高层）

### 数据流

```
[相机拍的原图 bytes]
       │
       ▼
[ImageProcessingService.processImage]
       │
       ├── 1. applyFilter (color matrix, 全图，无变化)
       │
       ├── 2. detectFaces (降采样到 1024px → ML Kit → boundingBox + contour)
       │       │
       │       ▼
       │   [FaceDetectionCache] (按 hash 缓存)
       │
       ├── 3. buildMask (用 contour points → fillPolygon → gaussianBlur 羽化)
       │       │
       │       ▼
       │   mask: Image (原图同尺寸，灰度)
       │
       ├── 4. applyBeautyWithMask
       │       - gaussianBlur(src, radius, mask: mask)
       │       - whiten(blended, brightness, mask: mask)
       │
       ├── 5. normalizeBrightness (全图兜底)
       │
       ▼
[处理后 bytes]
```

### 关键接口

```dart
// 1) 人脸检测
class FaceDetectionService {
  Future<List<Face>> detectFaces(Uint8List imageBytes);
}

// 2) mask 生成
class FaceMaskBuilder {
  Image buildMask(
    int imgW, int imgH,
    List<Face> faces, {
    int featherRadius = 15,
    bool excludeEyesLips = true,
  });
}

// 3) 升级后的美颜
class ImageProcessingService {
  Future<Uint8List> applyBeauty(
    Uint8List imageBytes, {
    double smooth = 30,
    double whiten = 20,
    List<Face>? faces,  // 允许外部注入，省去重检测
  });
}
```

### 调用方变化

`processImage` 增加可选 `faces` 参数：UI 层在「用户进编辑页」时一次性调 `FaceDetectionService.detectFaces(originalBytes)`，存到 provider；之后所有滑块变化都用缓存的 faces，不再重检测。

### 失败兜底

- `detectFaces` 抛异常 / 返回空 → `buildMask` 返回全黑 mask → `applyBeautyWithMask` 等价于「全图不磨」 → 行为退化为「无美颜」而非崩溃。
- ML Kit 初始化失败 → 走原 `applyBeauty`（全图）逻辑。

### 平台配置

- **iOS**：在 `Info.plist` 加 `NSCameraUsageDescription`（已有）；ML Kit on-device 模型首次使用自动下载。
- **Android**：在 `build.gradle` 加 `minSdkVersion 21+`（ML Kit 要求），开启 `mlkit:face-detection`（无 metadata 版本，自动下载）。

---

## 8. 风险与未知

| 风险 | 影响 | 缓解 |
|---|---|---|
| **iOS 26 模拟器 build 失败**（已确认的 ML Kit issue） | 开发者无法在 simulator 上调试 | 真机调试；或用旧版 Xcode；关注 PR 修复 |
| **ML Kit 模型首启下载** | 首次启动慢 2-5s | 接受；或在 on-boarding 时预热（`FaceDetector(options: ...)` 提前 new 出来） |
| **侧脸/低头/戴口罩** | face contour 不准 | contour confidence 低时回退到 landmarks 椭圆 |
| **多人脸/超多人脸** | mask 覆盖区域不连续 | mask 用 `img.fillPolygon` 把每张脸独立画，叠加（`Math.max` 像素） |
| **`image` 包的 PNG 编码很慢** | 4K PNG ~300ms | 改用 `encodeJpg(quality: 92)` 降到 ~80ms |
| **现有 `applyBeauty` 性能已吃紧** | 加 mask 后再涨 30% | 已用 `compute()` 隔离 |
| **`img.Image` 不可跨 isolate** | 错误时崩 | 跨 isolate 只传 `Uint8List`，内部重建 `img.Image` |
| **ML Kit 商业 license** | 走 Google Play 服务，要 GMS | 大陆 Android 设备可能没 GMS（华为/部分小米）→ 用 `face_detection_tflite` 兜底 |
| **Euler angle 修正** | 拍横屏照片时 contour 坐标被旋转 | 检测前按 `headEulerAngleZ` 旋转原图（复杂）→ 简化方案：不做修正，假定用户竖屏拍照 |
| **mask 羽化强度** | 太硬/太软都难看 | 默认 `featherRadius = 15`，留 P0 给 UI 调 |

---

## 9. 参考链接

### pub.dev 包（按调研时 latest version 列出）
- google_mlkit_face_detection: https://pub.dev/packages/google_mlkit_face_detection
- google_mlkit_face_mesh_detection: https://pub.dev/packages/google_mlkit_face_mesh_detection
- google_mlkit_commons: https://pub.dev/packages/google_mlkit_commons
- mediapipe_face_mesh: https://pub.dev/packages/mediapipe_face_mesh
- face_camera: https://pub.dev/packages/face_camera
- face_detection_tflite: https://pub.dev/packages/face_detection_tflite
- face_detection: https://pub.dev/packages/face_detection
- facebetter_flutter: https://pub.dev/packages/facebetter_flutter
- opencv_dart: https://pub.dev/packages/opencv_dart
- dartcv4: https://pub.dev/packages/dartcv4
- image: https://pub.dev/packages/image

### GitHub 仓库（活跃度核实）
- flutter-ml/google_ml_kit_flutter: https://github.com/flutter-ml/google_ml_kit_flutter （1.2k stars、pushed 2026-06-18）
- cornpip/mediapipe_face_mesh: https://github.com/cornpip/mediapipe_face_mesh （BSD-3、pushed 2026-06-21）
- rainyl/opencv_dart: https://github.com/rainyl/opencv_dart （249 stars、Apache-2、pushed 2026-04-10）
- cornpip/face_detection_tflite: https://github.com/cornpip/face_detection_tflite
- Linzaer/Ultra-Light-Fast-Generic-Face-Detector-1MB: https://github.com/Linzaer/Ultra-Light-Fast-Generic-Face-Detector-1MB （7.5k stars、MIT、可作为未来 TFLite fallback 的模型来源）
- google-ai-edge/mediapipe-samples: https://github.com/google-ai-edge/mediapipe-samples （2.7k stars）

### 算法参考
- 双向滤波 (Bilateral Filter) — Wikipedia: https://en.wikipedia.org/wiki/Bilateral_filter
- 导向滤波 (Guided Filter) — Kaiming He 2010 论文（业界磨皮算法鼻祖）
- 表面模糊 (Surface Blur) — Microsoft Research 2006

### 现有代码
- `lib/services/image_processing_service.dart`：当前美颜实现（`applyBeauty`、`processImage`）
- `pubspec.yaml`：当前依赖（`image: ^4.1.3`、`camera: ^0.10.5+9`）

---

## 10. 行动建议（给用户的下一步）

1. **P0 决策**：是否接受 ML Kit（Google 闭源、需 GMS）？如果不接受，改用 `face_detection_tflite`（纯 TFLite、跨平台、无 GMS 依赖），但代价是 APK 大 20MB+。
2. **P0 决策**：是否需要眼睛/嘴唇 exclusion（mask 排除五官）？这会决定走方案 B 还是 C。
3. **P1 决策**：要不要把美白（whiten）也限制在人脸内？还是只磨皮限制？
4. **P1 决策**：失败兜底行为 —— 检测不到人脸时，是「退化为无美颜」还是「全图美颜」？建议前者（更安全）。
5. **P2 体验**：检测结果缓存多久？建议按 imageHash 缓存，用户退出编辑页时清掉。
6. **下一步**：等用户决策后，再写具体的 `face_detection_service.dart` 和 `face_mask_builder.dart` 实施计划。
