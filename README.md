# EasyBeautyCam

> 让不会拍照的人轻松指挥模特摆出好看姿势的相机应用。

EasyBeautyCam 是一个 Flutter 移动应用，主要面向"被拍的人比拍照的人更会摆 pose"的场景。
应用内置一组参考姿势（pose），用户可以在取景时把 pose 轮廓叠加到画面上辅助构图，
拍完之后还能在编辑页加滤镜、裁切比例，然后保存到相册。

> 📷 取景辅助 · 🎯 Pose 库 · 🎨 滤镜裁切 · 📁 本地相册

---

## 核心功能

### 📷 相机页

- **3:4 竖屏取景框**，居中显示，自动适配屏幕尺寸（横屏时整体旋转 90°）
- **设备最大分辨率拍照**（iPhone 16 Pro 主摄 ~12MP binned，4032×3024，~3-5MB/张）
- **焦段 pill 浮层**：浮在 preview 底部边缘，半透明深色背景胶囊，支持 0.5x / 1x / 2x / 3x 硬件范围内的档位
- **双指 pinch 缩放**：1.0x ~ 6.0x（受硬件 min/maxZoom 限制）；pinch 后自动清空 pill 选中态，避免视觉误导
- **点击对焦**：取景框内任意点击，弹出对焦框并触发 `focusAndExposeAt`
- **前后摄切换**：通过 `cameraSwitchButton` 一键切换；前置相机隐藏 PoseStrip
- **拍照闪光动画**：350ms 淡入淡出 + iOS 系统快门声

### 🎯 Pose 库

- **6 个内置姿势**（`resources/poses/pose_outdoor_01..06.png` + `-res` 参考原图）
- 每个 pose 有两份资源：
  - **轮廓图**（`assetPath`）—— 选中态叠加在取景框上做构图辅助
  - **原图**（`referenceAssetPath` = `-res` 变体）—— 缩略图默认展示，让用户看清 pose 长啥样
- **缩略图条** `PoseThumbStrip` 横向 carousel：未选中显示彩色原图，选中显示白底轮廓
- **长按缩略图半透明预览**：长按任意缩略图不放，那张 pose 的 `-res` 原图以 50% 不透明度覆盖在取景框上，长按期间轮廓图自动让位；松开或移出缩略图外松开后恢复原状
- **远程 pose 同步**：`PoseRepository.syncRemotePoses()` 启动时非阻塞拉取远端列表，失败不影响 App 启动

### 🎨 拍后编辑（FilterPanel）

- **滤镜 carousel**：`FilterType` 枚举（原图 + 多个 LUT），实时预览（处理后的字节流直接喂预览组件）
- **亮度归一化**：`normalizeBrightness` 自动调整曝光
- **交互式裁切编辑器** `InteractiveCropEditor`：双指缩放 + 单指拖动 + 200ms debounce 回调
- **比例裁切栏** `CropRatioBar`：1:1 / 4:3 / 3:4 / 16:9 / 自由比例，按目标比例走 `applyTransform(targetRatio: ...)` 不拉伸裁切
- 流水线：`applyFilter → normalizeBrightness`（无美颜步骤）

### 📁 相册

- **应用内相册** `PhotoAlbumScreen`：列出本应用保存的照片
- 通过 `photo_manager` 持久化到系统相册
- 支持单张删除（带确认）

### 🌐 国际化

- `flutter_localizations` + `intl`
- 当前支持中文（默认）+ 英文，arb 文件在 `lib/l10n/app_zh.arb` / `app_en.arb`
- 启动时强制 `Locale('zh')`（可通过修改 `lib/app.dart` 跟随系统）

### 🎨 主题

- Material 3 浅色主题 + 珊瑚色 primary（`#9f4035`，详见 `DESIGN.md`）
- 所有色值/字号/圆距/间距走 `lib/core/theme/`，组件只引用 token 不写死数值

---

## 技术栈

| 层 | 选型 | 备注 |
| --- | --- | --- |
| 框架 | Flutter 3.x + Dart 3.x | SDK `>=3.0.0` |
| 状态管理 | Riverpod 2.4.9 | `StateNotifierProvider` + `Provider` |
| 路由 | go_router 13.2.0 | 两个路由：`/` 相机页、`/album` 相册 |
| 相机 | camera 0.10.5+9 | iOS AVCaptureSession via camera_avfoundation |
| 图像处理 | image 4.1.3 | Dart 端 PNG/JPEG 解码、滤镜、裁切、缩放 |
| 本地相册 | photo_manager 3.0.0 | 系统相册读写 |
| 本地存储 | hive 2.2.3 + hive_flutter | 自定义 pose 列表持久化 |
| 国际化 | flutter_localizations + intl | ARB 文件 + 自动生成 Dart 代码 |
| 网络 | http 1.2.0 | 远端 pose 同步 |
| SVG | flutter_svg 2.0.10 | icons |
| 路径 | path_provider 2.1.2 | 临时目录 / 应用文档目录 |

---

## 项目结构

```
lib/
├── main.dart                       # 入口；初始化 Hive + 异步同步远端 pose
├── app.dart                        # MaterialApp.router + GoRouter
├── core/
│   ├── constants/                  # 常量
│   └── theme/                      # AppColors / AppSpacing / AppRadii / AppTypography
├── l10n/
│   ├── app_zh.arb / app_en.arb     # 中英文 ARB
│   └── generated/                  # 自动生成的 AppLocalizations
├── services/
│   ├── camera_service.dart         # CameraController 封装（zoom / focus / orientation）
│   ├── image_processing_service.dart  # applyFilter / normalizeBrightness / applyTransform
│   ├── photo_album_writer.dart     # 写系统相册
│   └── pose_download_service.dart  # 远端 pose 下载缓存
└── features/
    ├── camera/                     # 相机页 + 子 widget
    │   ├── camera_screen.dart      # Column + Expanded 主布局
    │   ├── camera_view_model.dart  # CameraViewModel + State
    │   ├── state/
    │   │   └── pose_long_press_provider.dart  # 长按半透明预览状态
    │   └── widgets/
    │       ├── zoom_pill_bar.dart  # 焦段 pill 浮层
    │       ├── pose_thumb_strip.dart  # 缩略图条（带长按）
    │       ├── pose_overlay.dart   # 轮廓叠加层
    │       ├── pose_long_press_preview.dart  # 长按半透明覆盖层
    │       ├── camera_controls.dart
    │       ├── capture_button.dart
    │       └── camera_switch_button.dart
    ├── filter/                     # 拍后编辑页
    │   ├── filter_panel.dart       # 编辑页主入口
    │   ├── filter_view_model.dart  # 滤镜 + 裁切状态机
    │   └── widgets/                # filter_carousel / interactive_crop_editor / crop_ratio_bar
    ├── photo_album/                # 相册页
    └── pose_library/               # Pose 数据层
        ├── pose_model.dart         # PoseModel + referenceAssetPath getter
        ├── pose_manager.dart       # Riverpod state + 默认 6 张内置 pose
        └── pose_repository.dart    # 加载本地 / 同步远端
```

资源：`resources/poses/`（pose 轮廓图 + -res 原图）、`assets/icons/`、`assets/poses/`

---

## 跑起来

### 前置条件

- Flutter SDK `>=3.0.0`（推荐 stable 最新）
- iOS：Xcode 15+，iPhone（**真机调试**才能用相机；模拟器没相机硬件）
- Android：理论上支持，但当前主要在 iOS 调试；如需 Android 自行补 manifest 权限

### 常用命令

```bash
# 装依赖
flutter pub get

# 重新生成 l10n Dart 代码（ARB 改了之后）
flutter gen-l10n

# 分析
flutter analyze

# 跑测试（全量）
flutter test

# iOS 真机调试
flutter run -d <iPhone>

# 构建 iOS debug（不签名）
flutter build ios --debug --no-codesign
```

启动流程：

1. `main.dart`：`Hive.initFlutter()` → 异步触发 `PoseRepository.syncRemotePoses()`（失败不影响启动）→ `runApp(ProviderScope(child: EasyBeautyCamApp()))`
2. `app.dart`：`MaterialApp.router` + `GoRouter`，启动到 `CameraScreen`
3. `CameraScreen.initState`：`ref.read(cameraViewModelProvider.notifier).initialize()` 触发相机初始化

---

## 测试

- 测试入口：`test/`
- 全量 **138 个测试通过**（`flutter test`，约 12 秒）
- 覆盖范围：
  - `test/features/camera/` —— `CameraViewModel.setZoom(fromPill:)` × 6 + `PoseLongPressNotifier` × 4
  - `test/widget/` —— `ZoomPillBar` × 7、`PoseThumbStrip` × 6（含 3 个长按手势）、`PoseLongPressPreview` × 3、`CameraControls` / `CameraScreen` / `CameraSwitchButton` / `FilterCarousel` / `CropRatioBar` / `InteractiveCropEditor` 等
  - `test/services/` —— `CameraService` / `ImageProcessingService`（含 `applyTransform` 按比例裁切不拉伸的多个 case）
  - `test/filter/` —— `FilterViewModel` 实时预览 / 保存管线
  - `test/features/pose_library/` —— `PoseModel.referenceAssetPath` getter

---

## 文档

| 文件 | 内容 |
| --- | --- |
| [`DESIGN.md`](./DESIGN.md) | Material 3 主题色板 + 组件设计 token（colors / spacing / radii / typography） |
| [`docs/MEMO.md`](./docs/MEMO.md) | 项目备忘 / 迭代日志（〇一到〇十六，每条含背景 + 变更 + 影响文件 + 验证） |
| [`CHANGELOG.md`](./CHANGELOG.md) | 严格 Keep a Changelog 格式，按日期 [Unreleased] 段落记录 |
| `docs/superpowers/specs/*.md` | 部分历史 plan / spec（仅内部参考） |

---

## 已知限制 / 未做

- **不做美颜**：〇十二 已彻底删除瘦脸 / 磨皮 / 美白 等美颜链路（Vision framework + mediapipe_face_mesh 依赖全清），产品方向定在「拍原图 + 滤镜 + 裁切」
- **48MP 全像素拍照未开**：`ResolutionPreset.max` 走 12MP binned（4032×3024）；48MP 需开 `imageFormatGroup: ImageFormatGroup.bayer8888`（iOS）另行验证
- **未做长按 haptic feedback**：长按缩略图没有 `HapticFeedback.mediumImpact()` 反馈，iOS 端按中无物理反馈
- **远程 pose 长按预览**：远程 pose 无 `-res` 文件，长按预览会回退到 `assetPath`（= 轮廓图本身），效果等于「轮廓半透明叠在自己上面」

---

## License

未指定。