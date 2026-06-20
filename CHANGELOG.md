# Changelog

本项目的所有重要变更都会记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
本项目遵守 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased] — 2026-06-20

### Fixed
- **拍后编辑**：图片预览区加 `ConstrainedBox(maxHeight: 屏幕高 × 0.45)` 限高，竖向 portrait 照片不再把 BottomSheet 撑爆（之前会 `RenderFlex overflowed by 144 pixels`）
- **拍后编辑**：去掉图片预览的黑色兜底背景，竖向照片左右留空区透出 BottomSheet 暖白底
- **滤镜选择**：选中边框只圈住 50×50 颜色按钮，不再撑满整个 carousel 高度
- **相机偏暗**：相机端在 `initialize` / `switchCamera` 后调 `setExposureOffset(+1.0)`，用 try/catch 兜底（部分 Android/模拟器可能不支持）
- **拍后编辑**：`image_processing_service.processImage` 末尾加 `normalizeBrightness` 兜底，Rec.709 mean luma < 75 时按 `(110 - mean) * 0.85` 提升 RGB，亮图原样不动
- 55 个 widget/unit 测试（含 2 个新增亮度回归测试）

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
