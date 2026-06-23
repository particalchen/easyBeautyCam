# 相机取景页横屏旋转 设计

> **For agentic workers:** 后续实现请走 writing-plans → subagent-driven-development 流程。

**Date:** 2026-06-23
**Status:** Awaiting user review

---

## 1. 背景与目标

### 1.1 现状
- `CameraScreen` 没有显式的方向处理（依赖 Flutter / 相机 sensor 默认行为）
- 用户在真机横屏握持时：UI 元素会"重新排版"成横屏布局（portrait 布局不保留），效果不自然
- 姿势叠加层（PoseOverlay）跟随 layout 走向，握持方向变化时叠加线也"歪了"
- 焦段 pill / 拍照按钮 / 菜单 / 相册按钮：在横屏下要么挤在屏幕短边、要么位置不合理

### 1.2 目标
- **横屏时保留 portrait 布局**（不重排版）
- **整个取景页 UI（AppBar + 姿势叠加 + 底部控制栏）作为一个整体旋转**，使所有交互元素在用户视角下保持"正立"
- 相机 sensor 输出方向跟随设备方向（保证预览不颠倒）
- 覆盖范围**仅限相机取景页**，编辑页 / 相册页 / 菜单 / 全屏 dialog 不参与

### 1.3 非目标
- 不重排版（保留 portrait Stack 布局）
- 编辑页（FilterPanel）不旋转
- 相册页（PhotoAlbumScreen）不旋转
- 菜单 BottomSheet（AppMenuSheet）不旋转
- 全屏 dialog / route 不旋转
- 不引入新依赖

---

## 2. 设计

### 2.1 核心思路

把整个相机取景页（AppBar 视觉层 + Stack 内的所有子节点）作为一个 widget 整体，用 `MediaQuery.orientation` 驱动 `RotatedBox` 旋转到目标角度。这样：

- portrait 时 `quarterTurns: 0`（无视觉变化）
- landscapeLeft 时 `quarterTurns: 1`（90° 顺时针）
- landscapeRight 时 `quarterTurns: 3`（-90° / 270° 顺时针）
- portraitDown 时 `quarterTurns: 2`（180°）

相机 sensor 通过 `CameraController.lockCaptureOrientation(DeviceOrientation.landscapeLeft/Right/portraitUp/portraitDown)` 跟随设备方向，保证预览不颠倒。

### 2.2 组件改动

#### 2.2.1 `lib/features/camera/camera_screen.dart`

**结构调整**：

1. **AppBar 重构**：Scaffold 的 `appBar` 参数改为 `null`（不再用 Scaffold 自带的 AppBar）；在 body 内顶部用 Stack overlay 自己渲染 AppBar 视觉（菜单按钮 / 标题 / 相册按钮），让 AppBar 跟着 RotatedBox 一起转
2. **`_buildCameraView` 整体包 `RotatedBox`**：
   - 接受一个 `quarterTurns` 参数（默认 0）
   - 内部用 `MediaQuery.of(context).orientation` 计算
   - 旋转后内容居中（`FittedBox` 或 `OverflowBox` + `Center`）
3. **`build` 方法**：去掉 Scaffold 的 appBar；body 内先 RotatedBox 后 Stack
4. **保持 `extendBodyBehindAppBar: true`**（status bar 透明处理保留）

**`quarterTurns` 计算函数**：
```dart
int _orientationToQuarterTurns(Orientation orientation) {
  switch (orientation) {
    case Orientation.portraitUp: return 0;
    case Orientation.landscapeLeft: return 1;
    case Orientation.landscapeRight: return 3;
    case Orientation.portraitDown: return 2;
  }
}
```

**Scaffold body 结构**（自上而下）：
```
Scaffold(
  extendBodyBehindAppBar: true,
  body: SafeArea(
    bottom: false,
    child: RotatedBox(
      quarterTurns: _orientationToQuarterTurns(MediaQuery.of(context).orientation),
      child: LayoutBuilder(  // 给旋转后的子节点一个正方形 / portrait 布局空间
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxHeight,  // swap for rotated
            height: constraints.maxWidth,
            child: _buildCameraView(...),
          );
        },
      ),
    ),
  ),
)
```

> **关键点**：RotatedBox 旋转后，**子节点的 layout 坐标系仍是旋转前的**，但视觉输出已转。所以子节点按 portrait 布局画完后整体旋转。LayoutBuilder + swap 宽高是确保子节点拿到 portrait 形状的布局约束（不至于在 landscape 屏幕下被横向拉长）。

#### 2.2.2 `lib/services/camera_service.dart`

**新增方法 `setOrientationFromDevice(Orientation orientation)`**：
- 监听 `MediaQuery.of(context).orientation`（在 `_CameraScreenState` 中调）
- 调 `CameraController.lockCaptureOrientation(...)` 把 sensor 锁到对应方向
- `Orientation` → `DeviceOrientation` 映射：
  - `portraitUp` → `DeviceOrientation.portraitUp`
  - `landscapeLeft` → `DeviceOrientation.landscapeLeft`
  - `landscapeRight` → `DeviceOrientation.landscapeRight`
  - `portraitDown` → `DeviceOrientation.portraitDown`

**调用时机**：
- `CameraScreen.initState` 完成后调一次（用 `WidgetsBinding.instance.addPostFrameCallback`）
- 后续通过 `WidgetsBindingObserver.didChangeMetrics` 或直接监听 `MediaQuery` 变化来调
- `dispose` 时调 `unlockCaptureOrientation` 还原

#### 2.2.3 内部不受影响的逻辑

- `onTapUp` 坐标转换：仍然走 `RenderBox.globalToLocal` → `Offset(localX/size.width, localY/size.height)` 的归一化坐标。RotatedBox 旋转后 `localX/localY` 是旋转**后**的坐标，但 `size.width/size.height` 也是旋转后的尺寸（同一坐标系下做归一化），所以传给相机的 normalized point 仍然正确，相机会自己处理 sensor 方向
- 闪白动画（`_flashController`）：是 Stack 最上层 child，跟着 RotatedBox 一起转
- PoseOverlay：是 Stack child，跟着转
- 对焦指示器（`_buildFocusIndicator`）：是 Positioned widget，跟转；它的 `left/top` 用归一化坐标 × size 算出的最终坐标，会跟转
- `_capture` 拍照流程：不变（`Navigator.push` 全屏 FilterPanel，FilterPanel 自身不旋转）

### 2.3 数据流

```
[设备 orientation 变化]
   ↓
MediaQuery.of(context).orientation
   ↓
1. _CameraScreenState.build → _orientationToQuarterTurns() → RotatedBox.quarterTurns
   ↓
2. ref.read(cameraServiceProvider).setOrientationFromDevice(orientation)
   ↓
3. CameraController.lockCaptureOrientation(对应 DeviceOrientation)
   ↓
4. 相机 sensor 输出新方向 → 预览刷新
```

### 2.4 错误处理

- **相机未初始化时**：`setOrientationFromDevice` 直接 return（不调 lockCaptureOrientation）
- **lockCaptureOrientation 抛异常**（老相机 API / 模拟器）：try/catch 静默吞，UI 旋转照常工作（只是预览可能不正）
- **MediaQuery 不可用**：保持上一次的 quarterTurns 不变

### 2.5 系统 chrome 设置

- 当前 `main.dart` **没有**调用 `SystemChrome.setPreferredOrientations`（已 grep 确认）
- 也就是说 orientation 已经跟随系统设置（默认 4 个方向都允许）
- 本次**不需要**改 main.dart

---

## 3. Files to Modify

| 文件 | 变更类型 | 责任 |
|---|---|---|
| `lib/features/camera/camera_screen.dart` | 修改 | AppBar 改 Stack overlay；`_buildCameraView` 整体包 RotatedBox + LayoutBuilder；监听 orientation 调 `setOrientationFromDevice` |
| `lib/services/camera_service.dart` | 修改 | 新增 `setOrientationFromDevice(Orientation)` + 内部 lockCaptureOrientation |
| `test/widget/camera_screen_test.dart` | 新建/修改 | 4 个 orientation 的 widget 测试 + sensor orientation 验证 |
| `test/services/camera_service_test.dart` | 修改 | `setOrientationFromDevice` 在未初始化时静默；`lockCaptureOrientation` 被调用的 mock 验证 |

> 不修改：`lib/features/filter/filter_panel.dart`（编辑页不旋转）、`lib/features/photo_album/photo_album_screen.dart`（相册不旋转）、`lib/features/camera/widgets/app_menu_sheet.dart`（菜单 BottomSheet 不旋转）

---

## 4. Tests

### 4.1 单元测试

1. **`camera_service_test.dart`**：
   - `setOrientationFromDevice` 在 controller 未初始化时 return 不抛
   - 调 `setOrientationFromDevice(Orientation.landscapeLeft)` 后 `controller.lockCaptureOrientation` 被以 `DeviceOrientation.landscapeLeft` 调一次

2. **`_orientationToQuarterTurns` 测试**（可放 `camera_screen_test.dart`）：
   - `portraitUp` → 0
   - `landscapeLeft` → 1
   - `landscapeRight` → 3
   - `portraitDown` → 2

### 4.2 Widget 测试

1. **`camera_screen_test.dart`**：
   - 用 `MediaQuery` override 模拟 4 种 orientation，验证 `_buildCameraView` 外面包的 `RotatedBox.quarterTurns` 对应
   - 验证 `cameraService.setOrientationFromDevice` 被以正确参数调用

2. **回归**：
   - 现有 `camera_controls_test.dart` 仍通过
   - 现有 `pose_thumb_strip_test.dart` / `pose_overlay_test.dart` 仍通过（如果存在）

### 4.3 手动验证（真机）

- iOS / Android 真机各一台
- 拍一张照片确认预览方向正确
- 拍后进入编辑页确认编辑页**不旋转**（保留 portrait）
- 锁屏 / 切后台 / 回到前台：orientation 状态正确恢复

---

## 5. Risks & Mitigations

| 风险 | 影响 | 缓解 |
|---|---|---|
| iOS / Android 相机 sensor 方向 API 行为不同 | 横屏预览可能不正 | 已知用 `lockCaptureOrientation` + try/catch 兜底；真机两边都验 |
| AppBar 重构成 Stack overlay 后 status bar 行为变化 | 刘海 / 灵动岛避让失效 | `SafeArea` 显式保留；测 iPhone 14+ 灵动岛 |
| `setPreferredOrientations` 放开后系统手势冲突（iOS 左上角返回） | 横屏时返回手势撞 AppBar 按钮 | iOS 横屏时 AppBar 自动避让 safe area；按钮 hitTest 区域不重叠 |
| `LayoutBuilder` swap 宽高在 iPad 等大屏表现奇怪 | 内容尺寸不对 | iPad 不是核心目标，先按 iPhone 写；后续 iPad 单独优化 |
| 旋转动画卡顿 | 用户感知到卡顿 | Flutter 的 RotatedBox 自身有 200ms 左右过渡；如卡顿显著，加 `AnimatedRotation` |
| 旋转后 `RenderBox.globalToLocal` 行为变化 | 对焦点错位 | 单元测试覆盖；归一化坐标 `[0,1]` 在旋转前后等价 |

---

## 6. Out of Scope（明确不做）

- 编辑页（FilterPanel）横屏适配
- 相册页（PhotoAlbumScreen）横屏适配
- 菜单 BottomSheet（AppMenuSheet）横屏适配
- iPad 专属布局
- 旋转动画过渡（先用 RotatedBox 硬切，后续如有卡顿再优化）
- 缩略图条 / PoseOverlay 的独立旋转控制（它们跟着整体一起转即可）
- 引入新依赖
