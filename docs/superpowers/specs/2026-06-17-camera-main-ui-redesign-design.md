# 相机主屏 UI 重构 — 设计文档

**日期**: 2026-06-17
**范围**: 子项目 A（UI 改骨架）
**状态**: 已批准（用户指示"不再问，直接做"）

## 背景

当前 `CameraScreen` 有 4 个 UI 问题：

1. **AppBar 置灰**：M3 主题在透明背景上把 icon 渲染成 `onSurfaceVariant`，看起来像禁用态。
2. **2x 按钮错绑**：`.5 / 1x / 2 / 3` 按钮当前绑的是 `switchCamera(index)`，导致"点 2x"实际在切前置相机。
3. **焦段按钮位置不对**：和拍照按钮在同一行，导致视觉拥挤、单手操作困难。
4. **缺相机切换按钮**：现在没有专门切前/后置的按钮；用户只能用错误绑定的 2x/3x。

## 目标

把相机主屏改成 iOS 风格的「焦段在上、控制栏在下、拍照居中、切换最右」布局，并修掉 AppBar 置灰。

## 布局（自顶向下）

```
┌─────────────────────────────────────┐
│  AppBar  [☰]  EasyBeautyCam  [🖼]   │  ← 半透黑底 + 白 icon/title
├─────────────────────────────────────┤
│                                     │
│         CameraPreview               │
│         (双指缩放)                  │
│                                     │
├─────────────────────────────────────┤
│   [📷  📷  📷  📷  📷]               │  ← 姿势缩略图条（前置时隐藏）
├─────────────────────────────────────┤
│   [ .5 ]  [ 1x ]  [ 2 ]  [ 3 ]      │  ← 焦段行（前置时只剩 1x）
├─────────────────────────────────────┤
│   [    ]  [   ⬤   ]  [  🔄  ]       │  ← 占位 | 快门 | 相机切换
└─────────────────────────────────────┘
```

## 关键设计决策

### 1. 前置相机的焦段处理：**B 方案（写死）**

- **后置**：`[.5, 1x, 2, 3]` 四档，对应 `setZoom(0.5 / 1.0 / 2.0 / 3.0)`。
- **前置**：只显示 `[1x]`，单档。写死在 `CameraViewModel` 的状态里。
- **A 方案（动态检测 minZoom/maxZoom）**：进"未来工作"段，本次不做。

### 2. 焦段按钮 → 真变焦（不切相机）

`CameraControls` 当前的 1x/2x/3x 调用链：
```
onCameraSwitch(index) → camera_screen → notifier.switchCamera(index)
```

改为：
```
onZoomSelect(zoomValue) → camera_screen → notifier.setZoom(zoomValue)
```

`CameraViewModel.setZoom` 已经存在，只需改接线 + UI 传 `double` 而不是 `int`。

### 3. 相机切换按钮（新增）

- 位置：控制栏最右
- 风格：56-60pt 圆环 + 切镜图标 + 半透黑底白边（和 AppBar 右上角相册按钮**统一风格**）
- 行为：调 `notifier.switchCamera(cameraIndex == 0 ? 1 : 0)`
- 切换时焦段行同步更新（前置 → 只剩 1x）

### 4. AppBar 修复

- **根因**：`AppBar` 的 `foregroundColor` 用了主题的 `onSurfaceVariant`（M3 默认），在黑色背景上显示为接近灰色的褐色。
- **修法**：相机页的 `AppBar` 实例显式设 `foregroundColor: Colors.white` + `backgroundColor: Color(0x40000000)`（半透黑底，让边缘清晰可读）。**不改全局主题**——其他屏幕的 AppBar 该用什么色还是什么色。
- **不**用 Theme 数据驱动，保持修法局部、影响面最小。

### 5. 姿势缩略图条：前置时隐藏

- 后置：保留
- 前置：整行 `Visibility(visible: state.cameraIndex == 0)` 隐藏
- 理由：前置自拍时用户更关心脸部，不需要姿势引导

### 6. 统一按钮风格

相机切换按钮（最右）和 AppBar 右上角相册按钮用**同一套视觉语言**：
- 形状：圆形（前者 56-60pt，后者 IconButton 32pt）
- 边框：1.5pt 白色（`Colors.white`），半透黑底
- 图标：线性 / outline 风（`Icons.cameraswitch` / `Icons.photo_library_outlined`）
- 选中态：暂不需要

提取成可复用小组件 `AppCircleIconButton`（接受 `icon`、`onPressed`、`size`）。

## 数据流

```
User tap
   ↓
CameraControls/CameraScreen  (UI)
   ↓
CameraViewModel.setZoom / .switchCamera
   ↓
CameraService.setZoom / .switchCamera  (platform channel)
   ↓
state 变化 → UI 自动重绘
```

新增的 ViewModel 字段/方法：
- 现有 `setZoom(double)`：保持不变
- 现有 `switchCamera(int)`：保持不变
- 新增 `isFrontCamera`：派生自 `cameraIndex == 1`（不存新字段，避免双源）
- 现有 `currentZoom`：保持不变

## 文件改动清单

| 文件 | 改动 |
|---|---|
| `lib/features/camera/camera_screen.dart` | AppBar 颜色修；接 `setZoom`；加相机切换按钮接线；姿势条按前置隐藏 |
| `lib/features/camera/widgets/camera_controls.dart` | 焦段按钮绑 `onZoomSelect(double)`（不是 `onCameraSwitch(int)`）；新增「相机切换按钮」放在最右；风格统一 |
| `lib/features/camera/widgets/camera_switch_button.dart` | **新增** — 圆环 + 切镜图标的可复用小组件 |
| `lib/features/camera/widgets/app_circle_icon_button.dart` | **新增** — 通用圆环 icon 按钮（相册按钮也用这个） |
| `test/widget/camera_controls_test.dart` | **新增** — 焦段按钮 → setZoom；前置时只渲染 1x；相机切换按钮 → switchCamera |
| `test/widget/camera_switch_button_test.dart` | **新增** — 圆环样式 + 点击回调 |

## 未来工作（A 方案 — 动态检测焦段）

待硬件能力检测用：
- 启动时读每个 `CameraDescription` 的 `minZoomLevel` / `maxZoomLevel`（`camera` plugin `^0.10.0+` 才有，老版本要 fall back）
- 按当前相机的支持范围动态出 pill
- 前置双摄会显示 `.5 / 1x`；单摄只显示 `1x`

本次不实现，但 `CameraViewModel` 应保持可扩展——`setZoom(double)` 接口已足够通用，未来加一个 `availableZooms` 派生属性即可。

## 验收

- [ ] `flutter analyze` 无 error
- [ ] `flutter test` 全过
- [ ] 后置：4 颗焦段 pill（.5 / 1x / 2 / 3），点任意一颗触发 `setZoom`，该 pill 变珊瑚色选中态
- [ ] 后置：最右圆环点一下 → 切前置，焦段行变 1 颗 1x
- [ ] 前置：焦段行只剩 1x（写死），点 1x 仍能调 setZoom
- [ ] 前置：最右圆环点一下 → 切回后置
- [ ] AppBar：菜单 icon、标题、相册 icon 全部白色清晰，半透黑底可见
- [ ] 相机切换按钮和相册按钮视觉一致（同色边框、同图标风格）
- [ ] 姿势缩略图条：前置时整行隐藏，后置时显示
