# 自由裁切编辑器 + 美颜滑条间距 — 设计文档

**日期**: 2026-06-20
**范围**: 拍后编辑（FilterPanel）裁切交互 + 美颜滑条间距
**状态**: 设计阶段

## 背景

### 问题 1：裁切只能固定中心裁切

当前 `ImageProcessingService.crop()` 是按比例从图像中心硬裁（`img.copyCrop`，x/y 取中心），用户无法：

- 移动裁切区域（决定保留画面的哪一部分）
- 缩放后再裁切（先 zoom in 主体，再选比例）

需求（用户原话）：「裁切功能需要能够自由编辑，照片上需要有控制器能够缩放或者移动照片位置放在裁切框中」。

### 问题 2：美颜滑条间距太密

`BeautySlider` 当前三个滑条之间是 `const SizedBox(height: 4)`，肉眼看上去几乎贴在一起，操作时容易误触相邻滑条。上一次（8-item batch）从 8pt 砍到 4pt 砍过头了。

## 目标

1. 裁切改为「照片 + 裁切框 + 双指缩放 + 单指拖动」的所见即所得交互。
2. 美颜三档滑条之间的间距从 4pt 提到 12pt（= `AppSpacing.gutterGrid`）。

## 关键设计决策

### 1. 交互编辑器位置：**覆盖所有 tab**

`FilterPanel` 顶部「图片预览」区域从静态 `Image.memory` 改为新的 `InteractiveCropEditor` widget，**滤镜 / 美颜 / 裁切三个 tab 共享同一个编辑器**。这样：

- 所见即所得：用户调滤镜时看到的就是带裁切框的最终画幅
- 不需要切换 tab 才能裁切
- 切换 tab 时 transform 不重置（用户调好的位置保留）

### 2. 切换比例时**不重置 transform**

用户调好缩放和位置后，从「16:9」切到「1:1」时，缩放和平移保持不变；裁切框按新比例重新绘制。

代价：切比例后框的位置可能不再"贴边"（比如原 16:9 框很宽，切 1:1 后框变窄，原平移量可能让框偏左/右）。这是可接受的——用户可以再拖一下。

> 之前设计的"切比例时重置 transform"被否定。用户明确表示不要重置。

### 3. 处理流水线：**transform 先于 crop**

保留现有顺序：`processImage(filter, beauty) → applyTransform(scale, translation) → crop(ratio)`。原因：

- 滤镜/美颜算法对全图操作更简单（不需要处理"裁切框外"的像素）
- transform 阶段只对"框内可见区域"做几何变换
- crop 阶段是"把 transform 后的内容按目标比例裁成最终尺寸"

## 架构

### 新增组件

#### `lib/features/filter/widgets/interactive_crop_editor.dart`

`ConsumerStatefulWidget`，负责：

1. 用 `InteractiveViewer` 包裹照片（pinch + pan + scale）
2. 顶部叠一层 `裁切框遮罩`（CustomPaint 或 Stack + Positioned）
3. 监听 `FilterViewModelState.cropRatio` 变化，重绘遮罩
4. 手势结束时通知 view model 更新 transform（debounce 200ms）

布局：

```
Stack (alignment: center)
├── InteractiveViewer
│   └── Image.memory(previewBytes, fit: BoxFit.contain)
├── 裁切框遮罩 (CustomPaint)
│   - 框外区域：半透明黑 alpha=0.55
│   - 框线：1.5pt AppColors.primary
└── (frame 内) 透明
```

#### `lib/features/filter/widgets/crop_ratio_bar.dart`（改）

现有结构不动，新增「重置」按钮：

```
[重置]   自由  16:9  4:3  1:1  3:4  9:16
```

### 数据流

`FilterViewModelState` 新增：

```dart
final double scale;        // 当前缩放，默认 1.0
final Offset translation;  // 当前平移（图像坐标），默认 Offset.zero
```

新增方法：

```dart
void setTransform({double? scale, Offset? translation})
void resetTransform()
void setCropRatio(CropRatio ratio)  // 不重置 transform
```

### 图像处理

`ImageProcessingService` 新增：

```dart
/// 把"框内可见区域"按 transform 提取出来（无比例约束）
/// scale=1, translation=Offset.zero → 等价于 noop
Future<Uint8List> applyTransform(
  Uint8List imageBytes,
  double scale,
  Offset translation,
);
```

算法：

1. 解码图像得 `img`
2. 由编辑器当前的"框在图像坐标系下的矩形 R"反推 transform 后的"源图提取矩形 R_src"
3. `img.copyCrop(image, x: R_src.left, y: R_src.top, w: R_src.width, h: R_src.height)`
4. PNG encode 返回

> "框在图像坐标系下的矩形 R" = 编辑器里"被裁切框框住"的那个矩形在原图（处理后未裁切）中的位置 + 大小。transform 应用后这个矩形里的内容就是要保存的内容。

## UX 细节

### 缩放与平移

- **缩放范围**：`scale ∈ [1.0, 4.0]`（最小是 1.0，保证框内始终有图；最大 4x，避免过度放大）
- **平移 clamp**：保证照片始终覆盖整个裁切框（照片不能被拖出框外露出黑色）
- **手势**：双指 pinch 缩放、单指拖动平移；点击不响应（保留给以后扩展）
- **debounce**：手势结束后 200ms 才更新 view model 并触发处理（与现有 slider 一致）

### 裁切框视觉

- **框线**：1.5pt `AppColors.primary`（珊瑚色）
- **框外遮罩**：`Color.fromRGBO(0, 0, 0, 0.55)`，仅在「非自由」比例时显示
- **自由比例**：框退化为编辑器的全边界（即整张照片，无遮罩）；用户仍可缩放/平移但"裁切"是无效操作（保存时直接用全图）
- **比例切换动画**：300ms 缓动（用 `AnimatedContainer` 或 `TweenAnimationBuilder`）

### 重置按钮

- 位置：比例 chip 行**左端**
- 文案："重置"
- 行为：调用 `notifier.resetTransform()` → scale=1.0, translation=Offset.zero
- 样式：与未选中的比例 chip 一致（`surfaceContainerHigh` 背景）；按下时高亮为珊瑚色（与选中态一致）
- 防误触：仅在当前 transform ≠ 默认时高亮"可重置"（否则灰显）

### 美颜滑条间距

`beauty_slider.dart` 第 38、45 行的 `const SizedBox(height: 4)` 改为 `const SizedBox(height: AppSpacing.gutterGrid)`（= 12pt）。

不动 `vertical: 4` 的容器 padding，不动滑条本身的 height。

## 测试策略

### ViewModel 单元测试

- `setTransform({scale, translation})` 状态正确更新，触发 `_scheduleProcess`
- `resetTransform()` 把 scale 和 translation 拉回默认
- `setCropRatio(...)` **不**重置 scale 和 translation
- 多次 setCropRatio 切换保留 transform

### ImageProcessingService 单元测试

`applyTransform` 几何正确性：

- scale=1, translation=zero → 输出尺寸 == 输入尺寸
- scale=2, translation=zero → 输出尺寸 == 输入的一半（中心）
- scale=1, translation=(W*0.1, 0) → 输出尺寸 == 输入，向右偏移 10%
- 极端：translation 越界 → 自动 clamp 到图像边界

### Widget 测试

`InteractiveCropEditor`：

- 渲染：照片 + 裁切框 + 比例对应遮罩
- pinch 手势：模拟 `tester.createGesture()` 双指 scale=2.0，验证 view model 收到 `scale=2.0`
- pan 手势：模拟单指拖动 50pt，验证 view model 收到 translation
- 自由比例：遮罩消失
- 重置按钮：调用后 view model transform 重置

### 回归

- `crop` 单测保留（保证算法核心不被改坏）
- `ImageProcessingService.processImage` 端到端：照片 + filter + beauty + transform + crop → PNG 字节合法

## 边界情况

- 用户切比例后 transform 没重置，框位置可能偏 → 用户可手动再调（可接受）
- 用户缩放到比框还小 → clamp 到"框刚好被覆盖"的最小 scale
- 用户拖动时松手再立刻切比例 → 用最新 transform 状态重绘遮罩，不报错
- 保存时 transform 还没触发完 debounce → `_runProcess` 读最新 state，总是对的
- 自由比例下用户调了 transform 但保存的是全图 → 在重置按钮文案旁加 tooltip「自由比例下变换不影响保存」

## 未来工作（本次不做）

- 旋转（rotate）：用 `img.copyRotate` 加 transform
- 镜像（flip）：水平翻转
- 多选框（裁切多个区域）
- 历史撤销栈