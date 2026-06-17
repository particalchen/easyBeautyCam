# EasyBeautyCam 项目备忘

> 创建时间：2026-06-05
> 最后更新：2026-06-17

---

## 〇、最新进度（2026-06-17）

### A 相机主屏 UI 重构 ✅ 完成（9 commits, f1aca83..b4a8d9c）
- iOS 风格布局：焦段行 / 拍照按钮 / 相机切换按钮 / AppBar
- 相机切换按钮与相册按钮视觉统一（AppCircleIconButton）
- 前置相机自动隐藏姿势缩略图条 + 焦段行只显示 1x
- 21 个 widget test 全过

### B-F 子项目 ✅ 全部完成（7 commits, f42e33e..7deb6b2）
- **B 拍后编辑页**：FilterPanel 浮层 + `saveProcessedImage` 真写真册（`PhotoManager.editor.saveImage`），抽 `PhotoAlbumWriter` 抽象
- **C 调色**：FilterCarousel 5 个滤镜（珊瑚/港风/日系/胶片/原图）+ 选中态
- **D 美颜**：BeautySlider 三档滑杆（磨皮/美白/瘦脸）
- **E 菜单**：AppMenuSheet BottomSheet（姿势库/设置/关于）—— 落地页待 P1
- **F App内相册**：PhotoAlbumScreen 抽 `PhotoAlbumRepository` 抽象

### 基础设施
- 完整 token 体系：AppColors / AppSpacing / AppRadii / AppTypography
- 中英 i18n：flutter gen-l10n，MaterialApp.router 接入
- 测试覆盖：43 个测试（21 A + 22 B-F）全过
- 8 个 flutter analyze issues（全部预存在的 withOpacity deprecation，无新增）

### 下一步
- P1：E 菜单 3 个入口的落地页（姿势库管理 / 设置 / 关于）
- P1：用户自定义姿势导入
- 修剩余 8 个 withOpacity deprecation（Flutter 3.27+ 推荐 .withValues）

---

## 一、项目概述

**项目名称**：EasyBeautyCam
**一句话描述**：让不会拍照的男友/摄影师，轻松指挥模特摆出好看姿势的跨平台（iOS / Android / 鸿蒙）相机应用。
**技术栈**：Flutter / Riverpod / camera / image / Hive / go_router / photo_manager
**代码仓库**：https://github.com/particalchen/easyBeautyCam

---

## 二、需求回顾

### 2.1 核心功能

1. **姿势轮廓叠加**：白色半透明马克笔风格线条（rgba(255,255,255,0.55)），覆盖在相机画面上，包含脸朝向、手部动作、上半身姿态
2. **姿势选择**：底部横向滑动缩略图条，点击切换
3. **相机变焦**：1x/2x/3x 镜头切换按钮 + 双指 pinch 缩放（姿势轮廓不跟随缩放）
4. **即时拍照**：单手拇指操作
5. **滤镜处理**：拍完弹出滤镜选择，默认推荐一个，左右滑动切换
6. **美颜调整**：磨皮/美白/瘦脸，拍后处理，不开实时美颜
7. **照片保存**：处理后保存到相册
8. **内置姿势库**：内置 4 个姿势 + 启动时远程下载更多

### 2.2 分期功能

**P0（基础）**：上述核心功能
**P1（用户自定义）**：自定义姿势导入、姿势管理
**P2（社交+智能）**：姿势分享、场景识别推荐、被拍者监看

---

## 三、技术设计

### 3.1 设计规范

**色彩**：
- 主色：`#FF8A7A`（珊瑚粉）
- 渐变：`#FFB4A2 → #FF8A7A`
- 背景：`#FFFAF8`（暖白）
- 姿势线条：`rgba(255,255,255,0.55)`（白色半透明）

**字体**：SF Pro Display / SF Pro Text，iOS 系统字体

### 3.2 目录结构

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── theme/app_theme.dart
│   └── constants/app_constants.dart
├── features/
│   ├── camera/
│   │   ├── camera_screen.dart
│   │   ├── camera_view_model.dart
│   │   └── widgets/
│   │       ├── pose_overlay.dart
│   │       ├── pose_thumb_strip.dart
│   │       ├── camera_controls.dart
│   │       └── capture_button.dart
│   ├── filter/
│   │   ├── filter_panel.dart
│   │   ├── filter_view_model.dart
│   │   └── widgets/
│   │       ├── filter_carousel.dart
│   │       └── beauty_slider.dart
│   ├── pose_library/
│   │   ├── pose_model.dart
│   │   ├── pose_repository.dart
│   │   └── pose_manager.dart
│   └── photo_album/
│       └── photo_album_screen.dart
└── services/
    ├── camera_service.dart
    ├── image_processing_service.dart
    └── pose_download_service.dart
resources/poses/ # 内置姿势 PNG（手工提供）
assets/poses/       # 远程下载的姿势
```

### 3.3 滤镜方案

5 种预设滤镜（Color Matrix 实现，本地处理）：
- 原图 / 珊瑚 / 港风 / 日系 / 胶片

### 3.4 美颜方案

- 磨皮：高斯模糊 + 叠加
- 美白：亮度调整
- 瘦脸：（预留，算法未完整实现）

---

## 四、Git提交历史

| Commit | 描述 |
|--------|------|
| `c498e8a` | init: empty commit to start history |
| `be2ffb0` | feat: 初始化 Flutter 项目，配置主题和常量 |
| `7c8091e` | feat: 姿势数据模型、仓储和远程下载服务 |
| `f1d8013` | feat: 相机服务和取景框主页面 |
| `385ed13` | feat: 姿势轮廓叠加 Widget |
| `269dca0` | feat: 姿势缩略图横向滑动条 |
| `5169ca2` | feat: 相机控制栏和拍照按钮 |
| `82107e9` | feat: 图片处理服务（滤镜+美颜） |
| `0c3e257` | feat: 滤镜浮层 UI 和美颜滑杆 |
| `a5b9c29` | feat: 相册浏览页面 |
| `1a31ffd` | feat: 双指缩放 + 拍照触发滤镜浮层 |
| `c49f2f2` | feat: 启动时同步远程姿势 |
| `12d7a0e` | fix: 修复编译错误 - 添加photo_manager依赖、修正import路径、修复setZoomLevel和滤镜ColorMatrix实现 |
| `7b2cec0` | fix: photo_manager v3 API修复 - requestPermission参数和IosAccessLevel |
| `6398c48` | fix: PhotoManager.requestPermission → requestPermissionExtend for photo_manager v3 |
| `ed0dc14` | fix: 修复白屏问题 - HTTP添加5秒超时+异常处理+内置默认姿势 |
| `9d3d0cd` | fix: pose_manager const表达式错误 |
| `a60e3e3` | fix: iOS Info.plist添加相机和相册权限描述 |

---

## 五、遇到的问题及修复记录

### 5.1 编译错误

| 问题 | 原因 | 修复 |
|------|------|------|
| `photo_manager` 包缺失 | pubspec.yaml 未声明 | 添加 `photo_manager: ^3.0.0` |
| filter_carousel/beauty_slider import 路径错误 | `../../filter_view_model.dart` 多了一级 |改为 `../filter_view_model.dart` |
| `CameraController.setZoomFactor` 不存在 | camera 包版本 API 不同 | 改为 `setZoomLevel` |
| `img.ColorFilter.mat` 不存在 | image 包无此方法 | 手动逐像素应用 Color Matrix |
| `PhotoManager.requestPermission` 不存在 | photo_manager v3 API变更 | 改为 `requestPermissionExtend` |

### 5.2 iOS 运行时崩溃

| 问题 | 原因 | 修复 |
|------|------|------|
| App 启动 crash（abort_with_payload） | iOS 相机权限未在 Info.plist 声明 | 添加 NSCameraUsageDescription 等3 个 key |
| 白屏 |1. 远程请求无超时一直挂起 2. 无内置姿势列表 3. 网络错误无异常处理 | 加5 秒超时+异常捕获+内置默认姿势 |

### 5.3 其他

| 问题 | 修复 |
|------|------|
| pose_manager const 表达式错误 | `_defaultLocalPoses` 改为 `const List`，`PoseManagerState` 去掉 `const` |
| main.dart 远程同步阻塞 UI | 改为异步不阻塞，fire-and-forget 模式 |

### 5.4 错误处理教训总结

**教训 1：依赖包版本变更要第一时间查文档**
- 问题：`photo_manager` 从 v2 升级到 v3 后，`requestPermission` 被删除，改用 `requestPermissionExtend`；`camera` 包的 `setZoomFactor` 改名 `setZoomLevel`
- 教训：Flutter 包升级时不要只看 pub.dev 的版本号，要直接读 pub-cache 里的源码确认实际 API。API 文档可能过时，源码不会说谎。
- 预防：遇到编译错误先怀疑包版本 API 变更，优先查源码而不是搜索引擎

**教训 2：网络请求永远要设超时**
- 问题：启动时从 `https://example.com/poses` 下载姿势列表，没有任何超时设置，网络一慢就永久挂起，UI 线程卡死，白屏
- 教训：所有 HTTP 请求必须加 `.timeout(const Duration(seconds: N))`，N 根据场景决定（5s/10s/30s）
- 预防：Fire-and-forget 的异步请求也要加超时，防止极端情况下拖累主线程

**教训 3：UI 启动路径上不能有任何同步阻塞**
- 问题：`main.dart` 里 `poseRepo.syncRemotePoses()` 是同步等待的，导致 App 启动停在白屏
- 教训：启动时需要做的事情分成两类：必须成功的（初始化 Hive 等）用 `await`；可失败的（远程同步等）用 `try/catch` 包住并 fire-and-forget
- 预防：任何网络请求、文件 I/O 在 main() 里都必须是异步非阻塞的

**教训 4：硬编码 fallback 是防御性编程的核心**
- 问题：没有任何内置姿势数据时，如果远程请求失败，App 完全空白
- 教训：关键数据（默认姿势、默认配置）要有硬编码的 fallback，不能100%依赖网络或磁盘
- 预防：每层数据获取都要有降级方案：远程失败用本地，本地失败用硬编码

**教训 5：iOS 权限必须在 Info.plist 声明，不能靠运行时提示**
- 问题：相机权限未在 Info.plist 声明，导致 App 一启动就被 iOS 杀掉（abort_with_payload）
- 教训：Flutter iOS 的权限声明只能通过 Info.plist，代码里的 `requestPermission` 调用是第二步，第一步是 plist 里的 Description Key
- 预防：相机、相册、定位等权限，在写第一行相机相关代码之前就要加上 Info.plist 条目

**教训 6：import 路径数清楚层级关系**
- 问题：`lib/features/filter/widgets/filter_carousel.dart` 里写 `../../filter_view_model.dart`，多跳了一级
- 教训：相对路径 import 时，从当前文件位置出发，数清楚到目标文件需要多少个 `..`。`../` 是一级，`../../` 是两级。宁可写完整的 package 路径（`package:easyBeautyCam/features/filter/filter_view_model.dart`）也不要因小失大
- 预防：写完 import 后立刻检查是否有红色报错，不要等编译

**教训 7：Flutter 的 Color Matrix 没有内置工厂，要手写实现**
- 问题：以为 `image` 包有 `ColorFilter.mat` 或者类似的滤镜矩阵工厂，实际上不存在
- 教训：Flutter 图像处理三件套（`image`、`camera`、`photo_manager`）的 API 细节要和文档反复核对，第三方包的实现往往比想象中简陋
- 预防：涉及图像像素操作前，先写一个最小原型验证可行性，不要假设某个 API 存在

**教训 8：const 表达式里的变量不能是 final**
- 问题：`const PoseManagerState(poses: _defaultLocalPoses)` 报错，因为 `_defaultLocalPoses` 是 `final List` 不是 `const List`
- 教训：const 上下文中使用的任何变量或表达式本身都必须是 const（包括 List literal、Map literal、对象构造）
- 预防：已知会在 const 上下文中使用的 List/Map，优先声明为 `const List<T> [...]` 而非 `final List<T> = [...]`

---

## 六、iOS 配置备注

**Bundle Identifier**：需在 Xcode 中配置
**签名**：需登录 Apple ID 并选择 Team
**Info.plist 权限 Key**：
- `NSCameraUsageDescription` - 相机
- `NSPhotoLibraryUsageDescription` - 相册读取
- `NSPhotoLibraryAddUsageDescription` - 相册保存

---

## 七、待办事项

### 7.1 P0 未完成项

- [ ] `resources/poses/` 下还需要 3 张内置姿势图（目前只有 1 张 `pose_outdoor_01.png`）
- [ ] `poseRemoteBaseUrl` 目前是 `https://example.com/poses`，需替换为实际服务器地址
- [x] 滤镜保存到相册的完整流程 ✅ `df74ceb` —— 抽 `PhotoAlbumWriter` 抽象 + `PhotoManager.editor.saveImage`
- [ ] 双指缩放 `onScaleUpdate` 逻辑需要正确累计缩放值（当前实现有 bug，scale 是增量不是绝对值；代码 line 100 留有 TODO 注释）

### 7.2 P1/P2

- [ ] E 菜单 3 个落地页：姿势库管理（`/pose-library`）/ 设置（`/settings`）/ 关于（`/about`）
- [ ] 用户自定义姿势导入（相册选择图片）
- [ ] 姿势分享/导入（需要服务器端 API）
- [ ] 场景识别推荐（需要相机画面分析和 API）

### 7.3 配置

- [ ] GitHub remote 已设置（https://github.com/particalchen/easyBeautyCam.git），推送认证待解决
- [ ] photo_manager 的 iOS Podfile 配置（`platform :ios, '12.0'`）

---

## 八、相关人员

- 项目所有者：partical

---

## 九、参考文档

- 设计规格书：`docs/superpowers/specs/2026-06-04-easyBeautyCam-design.md`
- 实现计划：`docs/superpowers/plans/2026-06-04-easyBeautyCam-plan.md`
- A 任务设计稿：`docs/superpowers/specs/2026-06-17-camera-main-ui-redesign-design.md`
- A 任务实现计划：`docs/superpowers/plans/2026-06-17-camera-main-ui-redesign.md`