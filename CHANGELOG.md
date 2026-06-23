# Changelog

本项目的所有重要变更都会记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
本项目遵守 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased] — 2026-06-23

### Fixed
- **拍后编辑**：图片预览区加 `ConstrainedBox(maxHeight: 屏幕高 × 0.45)` 限高，竖向 portrait 照片不再把 BottomSheet 撑爆（之前会 `RenderFlex overflowed by 144 pixels`）
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

### Known
- 暂无

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
