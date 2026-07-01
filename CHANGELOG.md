# Changelog

本项目的所有重要变更都会记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
本项目遵守 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased] — 2026-06-28

### Added
- **Pose 缩略图长按半透明预览**。长按 `PoseThumbStrip` 任意缩略图不放，那张 pose 的 `-res` 彩色原图以 50% 不透明度覆盖在取景框上，长按期间取景框上的 pose 轮廓图（`PoseOverlay`）自动隐藏；松开或移出缩略图外松开后恢复原状，不影响当前选中的 pose。新增 `lib/features/camera/state/pose_long_press_provider.dart`（瞬时长按态 `StateNotifierProvider<PoseLongPressNotifier, PoseModel?>`）+ `lib/features/camera/widgets/pose_long_press_preview.dart`（`Positioned.fill + IgnorePointer + Opacity(0.5) + Image.asset`，与 PoseOverlay 互斥），`PoseOverlay` 开头加 long-press 检查让位，`PoseThumbStrip` 每个缩略图的 GestureDetector 增 `onLongPressStart` / `onLongPressEnd` / `onLongPressCancel` 三个回调（短按切换选区与长按预览并存，由 gesture arena 派发）。10 个新测试（4 个 provider 单测 + 3 个 preview widget + 3 个 strip 长按手势），全量 138 测试通过。

## [Unreleased] — 2026-06-27

### Added
- **相机页布局重构 + 焦段 pill 交互**。新增 `lib/features/camera/widgets/zoom_pill_bar.dart` —— 焦段 pill 浮层组件（半透明深色背景胶囊），浮在 preview 底部边缘；`CameraViewModelState` 新增 `lastSelectedPillZoom` 字段 + `setZoom(zoom, {fromPill})` 参数，`fromPill=true` 记录 pill 值并高亮、`fromPill=false`（默认，如 pinch）清空 pill 选中态；`CameraControls` 移除焦段 pill 行，新增 `showPoseStrip` 参数，内部布局为「PoseStrip（可选）→ 12pt gap → 控制栏」；`CameraScreen` 从单一 Stack with Positioned 改为 `Column + Expanded` 结构：AppBar → `Expanded(Stack[preview, ZoomPillBar(bottom:8), flash])` → 16pt gap → CameraControls；preview 与 PoseStrip 之间 16pt 明确空隙，焦段 pill 距 preview 底部 8pt（重叠约 28pt 几乎完全在 preview 内）。13 个新测试（`CameraViewModel.setZoom(fromPill:)` × 6 + `ZoomPillBar` × 7）+ `camera_controls_test.dart` 整体重写（适配新 API）。全量 128 测试通过。

### Fixed
- **拍照分辨率提到设备最大**。`lib/services/camera_service.dart` 两处（`initialize` / `switchCamera`）`ResolutionPreset.high` → `ResolutionPreset.max`。之前 iOS 上只给 1280×960（~300KB/张），与 iPhone 16 Pro 主摄 12MP binned（4032×3024）应有的画质相差 ~30 倍。改后约 3-5MB/张；保存链路（`ImageProcessingService.processImage` / `applyTransform` / `encodePng`）不降采样，源图多高就存多高，所以修拍照端即可。48MP 全像素需单独开 `imageFormatGroup`（本次未开）。

## [Unreleased] — 2026-06-25

### Added
- **Pose 缩略图：默认显示 -res 原图、选中显示 pose 轮廓图**。`PoseModel` 新增 `referenceAssetPath` getter（本地 pose 在 `assetPath` 扩展名前插 `-res`；远程/无扩展名返回 null）；`PoseThumbStrip` 按 `isSelected` 切换：`!isSelected` → `referenceAssetPath ?? assetPath`（不调色，让用户看清 pose 长啥样），`isSelected` → `assetPath`（保留原来的白色叠加做"轮廓效果"）；`resources/poses/` 补齐 6 张原图（`pose_outdoor_01-res.png` ~ `pose_outdoor_06-res.png`），`_defaultLocalPoses` 列表扩到 6 张。6 个新测试（3 个 PoseModel getter + 3 个 widget 切换逻辑，含远程 pose 回退到 assetPath 的 case）。全量 166 测试通过。

### Removed
- **整个美颜功能**（2026-06-26 决定）。理由：产品方向调整，"拍原图 + 滤镜 + 裁切"已足够。具体删除：17 个文件（`lib/services/slim_warp_service.dart`、`slim_warp_types.dart`、`affine2d.dart`、`face_mesh_detector.dart`、`face_mask_builder.dart`、`face_detection_service.dart`、`face_detection/` 整个目录、`slim_zone.dart`、`features/filter/widgets/beauty_slider.dart`、`main_slim_mvp.dart`、`main_day2_verify.dart`、`ios/Runner/FaceDetectionPlugin.swift`、5 个相关测试）；3 个 i18n key（`beautySmooth` / `beautyWhiten` / `beautySlim` / `beautyNoFaceDetected` / `beautyFaceDetected` 从 zh+en arb 删除）；`pubspec.yaml` 移除 `mediapipe_face_mesh: ^1.8.1` 依赖；`ImageProcessingService` 移除 `applyBeauty` 方法、`processImage` 简化为 `applyFilter → normalizeBrightness`；`FilterViewModel` 移除 `smooth` / `whiten` / `slim` / `faceCount` / `faceDetectionFailed` 状态字段，删除 `faceDetectionServiceProvider` / `faceMaskBuilderProvider` / `faceMeshDetectorProvider` 三个 provider，构造函数从 6 参瘦身到 3 参（`_processingService` / `_photoAlbumWriter` / `_appPhotoRepository`），`_runProcess` 流水线去掉 detect / buildMask / applyBeauty 链路；`FilterPanel` `TabController.length` 从 3 缩到 2，TabBar/TabBarView 移除「美颜」Tab；6 个测试 stub 文件同步精简（`_NoopFaceDetector` / `_NoopMaskBuilder` / `_NoopFaceMeshDetector` 全删，`FilterViewModel` 构造从 6 参改 3 参，`image_processing_service_test.dart` 整个 `applyBeauty - mask 行为` 测试组删除）。全量 120 测试通过（从 166 缩减到 120，主要差异来自删除的 17 个美颜测试 + 删测试组中的 4 个 applyBeauty 用例 + 一些 stub-only 重复）。

## [Unreleased] — 2026-06-24

### Added
- **瘦脸（编辑页静态图）**：基于 `mediapipe_face_mesh` 1.8.1（cornpip）468 点 3D mesh + 852 三角剖分 + 2D 仿射瘦脸算法。新增 `SlimWarpService`：三角形细分 → 仅变形指定 zone（左右脸颊 + 下颌）内的三角形 → 每三角形 2D affine（保留局部形状，仅沿面中轴线内推）→ 反向映射 + 双线性采样（保证无空洞）。`FaceMeshDetector` 是 mediapipe wrapper，新出 `FaceMeshResult { landmarks, triangles, isValid }` 类型与项目解耦。`ImageProcessingService.applyBeauty` 新增 `mesh` 参数，`slim > 0 && mesh != null && mesh.isValid` 时先 warp 再走原有 smooth/whiten；`slim = 0` 跳过整条 mediapipe 链路（性能优化）。`FilterViewModel` 注入 `FaceMeshDetector`，`_runProcess` 在 `slim > 0` 时按 `imagePath` 缓存取 mesh（命中缓存不重检测），并 try/catch 静默吞 mediapipe 异常避免滑杆拖动崩溃；`setImage` 清两个 detector 缓存（Vision + mediapipe）。编辑页「瘦脸」滑杆走的是现有 slider 通路，0-100 默认 0，**滑杆 UI 已有**（commit `baa4df6` 之前的 BeautySlider 早就接好了），这次是把后端 warp 算法接通。新增 `lib/main_slim_mvp.dart` + `lib/main_day2_verify.dart` 两个 iOS 真机验证入口；21 个新测试（16 个 warp 单元测试 + 5 个滑杆集成测试）。MVP 在 iPhone 16 Pro 真机验证通过（`Documents/build/slim_mvp_warped.jpg` 等文件）。详见 `docs/MEMO.md` 〇十二。

### Architecture
- 瘦脸流水线：`filter → mediapipe mesh (slim>0) → SlimWarpService.applySlim → applyBeauty(smooth, whiten, slim, mask, mesh) → normalizeBrightness`。两条平行人脸检测链路：Vision 64 点 → mask（眼唇排除）；mediapipe 468 点 → warp（完整几何）。两者互不依赖，mediapipe 失败时瘦脸降级为原图但其他美颜参数照常生效。

### Known
- **瘦脸滑杆 strength=1.0 时脸颊边缘有轻微色缝**（`bilerp` 边界外像素 fallback 不完美），目前靠默认滑杆位置（0）规避；强度 ≤ 0.7 视觉上看不出来
- **mediapipe 在弱光/侧脸/远景场景会返回 null**，瘦脸滑到非零但照片无效果；与 Vision 一致，暂不加 UI 提示（避免双重提示污染）
- **iOS 真机调试**：`flutter run --release -t lib/main_day2_verify.dart` 在 iPhone 16 Pro 上存在「安装成功但调试日志断开」的现象；改用 `flutter build ios --release` + `xcrun devicectl device install app` + 手工从 Documents 提取产物验证；MVP 已用后者跑通

## [Unreleased] — 2026-06-23

### Fixed
- **拍后编辑**：图片预览区加 `ConstrainedBox(maxHeight: 屏幕高 × 0.45)` 限高，竖向 portrait 照片不再把 BottomSheet 撑爆（之前会 `RenderFlex overflowed by 144 pixels`）
- **相机 AppBar**：标题用 `Stack(alignment: center)` 真正居中（原 4 子项 `spaceBetween` 视觉偏左）；相册按钮去掉 1.5pt 圆形描边 + 去掉 Padding/SizedBox 贴右边；`AppCircleIconButton` 加 `bordered` / `iconOpacity` 参数，`CameraSwitchButton` 走 `iconOpacity: 0.75`（次要操作不抢快门按钮的戏）
- **美颜（iOS Vision）**：Vision 插件之前没传 `CGImagePropertyOrientation`，iOS 相机拍出来的 JPEG EXIF = `.right` (6) 时 Vision 处理 raw landscape 像素，landmark 坐标用在了 Dart 端已经烘焙 EXIF 旋转的 portrait 图像上 → mask 画在错位置（用户反馈"美白只在右上角变白"）。修法：读 `image.imageOrientation` → 映射到 `CGImagePropertyOrientation` → 传给 `VNImageRequestHandler(cgImage:orientation:)` → `polygon()` 用 `displaySize` 算出的显示宽高反归一化，跟 Dart 端 `image.width/height` 匹配
- **拍后编辑**：去掉图片预览的黑色兜底背景，竖向照片左右留空区透出 BottomSheet 暖白底
- **滤镜选择**：选中边框只圈住 50×50 颜色按钮，不再撑满整个 carousel 高度
- **相机偏暗**：相机端在 `initialize` / `switchCamera` 后调 `setExposureOffset(+1.0)`，用 try/catch 兜底（部分 Android/模拟器可能不支持）
- **拍后编辑**：`image_processing_service.processImage` 末尾加 `normalizeBrightness` 兜底，Rec.709 mean luma < 75 时按 `(110 - mean) * 0.85` 提升 RGB，亮图原样不动
- **相机偏亮**：回退上一项的 `setExposureOffset(+1.0)`，曝光走相机默认；亮度补偿保留兜底
- **相机 0.5x 焦段无效**：相机端查 `getMinZoomLevel` / `getMaxZoomLevel`，UI 层 `CameraControls` 自动过滤到硬件支持范围，pinch 范围同步
- **相册全屏预览**：关闭按钮从默认 IconButton 升级为 48pt 圆形 + 半透明深色底，固定右上角
- **美颜滑动条**：字号 14→12，track 4→2pt，thumb 半径 14→8，间距 sm→4pt；编辑面板 TabView 高度 200→150、预览区 maxHeight 比例 0.45→0.38
- **filter/裁切编辑器**：切换比例时图片不再被强制拉伸（applyTransform 改为按比例裁切）；切换比例不再触发预览重裁切（setCropRatio 仅改遮罩）；InteractiveCropEditor 允许 <1x 拉远（minScale=0.5）；图片用 BoxFit.cover 铺满 viewport，触摸热区更大；_syncFromProps 镜像 translation 归一化语义修复 round-trip 跳变

### Added
- **相机取景页横屏旋转**：横屏握持时 layout 不重排版，整个 UI 作为一个整体旋转 90°（AppBar + 姿势叠加 + 底部控制栏 + 姿势缩略图条）。`RotatedBox` + `LayoutBuilder` swap 宽高让 portrait Stack 子节点在 landscape 屏幕下按 portrait 形状布局；AppBar 从 `Scaffold.appBar` 重构为 body 内的 Stack overlay 跟着一起转；`CameraService.setOrientationFromDevice(Orientation)` 调 `lockCaptureOrientation` 让相机 sensor 跟 UI 方向一致；`WidgetsBindingObserver.didChangeMetrics` 监听设备方向变化自动同步 sensor。范围**只**限相机取景页，编辑页 / 相册 / 菜单不参与。
- **人脸识别美颜**：编辑页静态图人脸检测。iOS 端用 **Apple Vision framework**（`VNDetectFaceLandmarksRequest` + `FlutterImplicitEngineDelegate` + MethodChannel `easy_beauty_cam/face_detection`，iOS 13.0+），Android 端用空 stub（返回 `const []` → 触发「未检测到人脸」UI）；`ImageProcessingService.applyBeauty` 新增 `img.Image? mask` 参数，`mask==null` 跳过美颜（原图返回，per spec 默认），有 mask 时只在人脸区域（mask>0）做磨皮和美白，眼唇被排除（mask=0）；`FaceDetectionService` 按 `imagePath` 缓存（`Map<String, List<FaceContours>>`），滑杆拖动不重检测；`FaceMaskBuilder` 把轮廓转 1-channel mask（`fillPolygon` 整脸=255 → `fillPolygon` 眼唇=0 → 高斯羽化 radius=8）；`FilterViewModel._runProcess` 流水线串接 `applyFilter → detect(缓存命中) → buildMask → applyBeauty(with mask) → normalizeBrightness`，`FilterViewModelState` 新增 `faceCount` / `faceDetectionFailed` 字段；`BeautySlider` 顶部新增「未检测到人脸 / 已检测 N 张人脸」提示行（橙色 ⚠️ / 绿色 ✓）；l10n 新增 `beautyNoFaceDetected` / `beautyFaceDetected` 两个 key（zh + en，`AppColors` 新增 `warning` / `success`）。范围**只**限编辑页静态图，**不**做实时视频美颜，**不**做瘦脸。顺带修复 `applyBeauty` 3 个 pre-existing bug（`orig` 从空白 result 读 / `gaussianBlur` 原地污染 / `smooth=0` 分支没复制 orig）。Vision normalizedPoints 是**左下角原点 + Y 向上**，Swift 插件里 `y = (1.0 - ny) * height` 翻 Y；iOS Vision `outerLips` / `innerLips` 映射到 ML Kit 风格 `lipUpper` / `lipLower` 凑合填，FaceMaskBuilder 用 OR 逻辑处理。

### Changed
- **焦段按钮文字**：统一为 "Nx" 格式（`0.5x` / `1x` / `2x` / `3x`），去掉原来的 `.5` / `2` / `3` 不一致写法
- **默认美颜参数**：`defaultBeautySmooth` / `defaultBeautyWhiten` 从 30/20 改为 0/0（用户偏好：拍原图，需要时再手动调）

### Added
- **相机点击对焦曝光**：在 CameraPreview 上点击，调用 `setFocusPoint` + `setExposurePoint`，并显示 0.9s 黄色对焦指示框
- **照片编辑裁切**：FilterPanel 增加「裁切」Tab（第三个），提供 自由 / 16:9 / 4:3 / 1:1 / 3:4 / 9:16 六个比例按钮；`image_processing_service.crop` 用 `img.copyCrop` 做中心裁切；`FilterViewModel.cropRatio` 字段 + `setCropRatio` 方法，选中后 debounce 触发实时裁切预览
- 62 个 widget/unit 测试（含 2 个亮度 + 4 个裁切 + 2 个硬件 zoom 过滤回归）
- **拍后编辑：交互式裁切**：双指缩放（1.0~4.0x）+ 单指拖动；三档比例框可见，自由比例退化为全图；裁切 tab 加「重置」按钮（仅当 transform 非默认时可点）
- `FilterViewModelState` 新增 `scale` / `translation` 字段 + `setTransform` / `resetTransform` 方法（注意：`setCropRatio` 不重置 transform）
- `ImageProcessingService.applyTransform` 公开方法：按 zoom + pan 从源图提取可见区域并 resize

### Changed
- **美颜滑条间距**：4pt → 12pt（`AppSpacing.gutterGrid`）
- **拍后编辑顶部预览**：从静态 `Image.memory` 改为 `InteractiveCropEditor`，三个 tab 共享同一编辑器
- **filter/拍后编辑**：FilterPanel 改为全屏路由 + 编辑期间暂停摄像头；裁切 UI 重构（「原图」替代「自由」+ 默认选中 + 比例矩形图示 + 重置图标按钮最右侧）
- **filter/拍后编辑 UI 微调**（commit `baa4df6`）：顶部 `SafeArea(top: true)` 避让状态栏；比例 chip 图标去外框 + 缩小（26×18，stroke 1.2）；重置按钮移到「裁切比例」标题行最右侧；`selectedFilter` 默认 `FilterType.original` 而非 `coral`

### Architecture
- 处理流水线：`filter → beauty → normalizeBrightness → applyTransform`（applyTransform 内部按目标比例 resize，不再单独调 crop）
- **人脸检测**：`FaceDetectionService` 平台路由。iOS → `IOSFaceDetector` → Apple Vision（`VNDetectFaceLandmarksRequest`，5 类 landmark：face contour / leftEye / rightEye / outerLips / innerLips）；Android → 空 stub（`return const []`）。Swift 插件用 `FlutterImplicitEngineDelegate.didInitializeImplicitFlutterEngine` 注册（`engineBridge.pluginRegistry.registrar(forPlugin: "FaceDetectionPlugin")` 取 registrar 传给 `register(with:)`）

### Removed
- **`google_mlkit_face_detection: ^0.13.2` + `google_mlkit_commons: ^0.11.0`**：Google ML Kit 的预编译 framework 不发 arm64 simulator 切片，导致 iOS 26+ Apple Silicon 模拟器跑不起来。删除后 iOS 模拟器编译零警告；Android 端人脸检测改为空 stub（详见 Known）。`ios/Podfile` deployment target 从为 ML Kit 升的 15.5 回退到 13.0（Vision 框架最低要求）

### Known
- **Android 端人脸检测降级**：目前 Android 走空 stub，编辑页 BeautySlider 会一直显示「未检测到人脸」橙色提示，美颜不生效。后续实现建议：直接走平台通道调 Android 原生 `FaceDetector` API（API 14+），或找一个纯 Android 库（不发 iOS pod）

## [Unreleased] — 2026-06-19

### Fixed
- **相机**：0.5x 焦段点击/双指 pinch 都能正确响应；pinch 下限 clamp 从 1.0 调整为 0.5，并锁定 baseZoom 避免连续手势累计漂移
- **相机**：按下快门时增加全屏闪白动画（350ms 渐显渐隐）+ 系统拍照声效
- **相册**：相册页面改为只展示本 app 拍过的照片（不再读取设备整个相册）；长按照片可进入多选模式并删除
- **拍后编辑**：照片预览改用 `BoxFit.contain`，竖向照片完整显示不再被裁切
- **拍后编辑**：滤镜与美颜拆分为「滤镜 / 美颜」两个 Tab，互不挤占空间
- **拍后编辑**：滤镜选择与美颜滑杆**实时**反映在预览图上（200ms 防抖），所见即所得
- **美颜**：磨皮算法调小（高斯半径 ≤2、混合系数 ≤0.20），不再"糊脸"

### Added
- `AppPhotoRepository`：新增 app 内照片仓库抽象（本地文件 + JSON manifest），与原 `PhotoAlbumRepository`（photo_manager 读设备相册）解耦
- 51 个 widget/unit 测试（含 7 个新增回归测试）

## [0.1.0] — 2026-06-17

### Added
- **A 相机主屏 UI 重构**：iOS 风格布局 —— 焦段 pill 行 / 拍照按钮 / 相机切换 / AppBar；前置相机自动隐藏姿势缩略图条 + 焦段行只显示 1x
- **B 拍后编辑页**：FilterPanel BottomSheet 浮层 + `saveProcessedImage` 真写真册（`PhotoManager.editor.saveImage`）
- **C 调色**：FilterCarousel 横向 5 个滤镜（珊瑚/港风/日系/胶片/原图）+ 选中态
- **D 美颜**：BeautySlider 三档滑杆（磨皮/美白/瘦脸）
- **E 菜单**：AppMenuSheet BottomSheet（姿势库 / 设置 / 关于）—— 三个落地页待 P1
- **F App 内相册**：PhotoAlbumScreen
- 完整 token 体系：`AppColors` / `AppSpacing` / `AppRadii` / `AppTypography`
- 中英 i18n（`flutter gen-l10n`）
- 43 个 widget/unit 测试

### Fixed
- iOS `Info.plist` 添加相机和相册权限描述

[Unreleased]: https://github.com/particalchen/easyBeautyCam/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/particalchen/easyBeautyCam/releases/tag/v0.1.0
