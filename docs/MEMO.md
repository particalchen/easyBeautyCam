# EasyBeautyCam 项目备忘

> 创建时间：2026-06-05
> 最后更新：2026-06-20

---

## 〇、最新进度（2026-06-20）

### 自由裁切 + 美颜滑条间距 ✅ 完成（commit `b2d47b8`，9 commits）
1. **裁切改为交互式**：顶部预览 = `InteractiveCropEditor`（双指缩放 + 单指拖动 + 裁切框遮罩），三个 tab 共享；切换比例时 transform 不重置（用户拍板）；裁切 tab 加重置按钮
2. **美颜滑条间距 4pt → 12pt**：之前 8pt 砍到 4pt 砍过头，操作容易误触
- 流水线：filter → beauty → normalizeBrightness → applyTransform（之前是单独 crop，现在 applyTransform 内部按目标比例 resize）
- 14 个新测试（applyTransform × 4 + transform state/methods × 3 + InteractiveCropEditor × 3 + 重置按钮 × 2 + others × 2），共 76/76 通过

### 相机 / 编辑 / 相册 三端 UX 批量调整 ✅ 完成（8/8，commit `ee5aa3b`）
1. **相册全屏关闭按钮**：默认 IconButton 太小、位置偏左 → 48pt 圆形 + 半透明深色底 + 固定右上角
2. **焦段按钮文字统一**：`0.5x` / `1x` / `2x` / `3x`（去掉之前 `.5` / `2` / `3` 不一致写法）
3. **实时相机偏亮**：回退上一节 `setExposureOffset(+1.0)`，走相机默认曝光；处理端亮度补偿保留
4. **0.5x 焦段无效**：相机端查 `getMinZoomLevel` / `getMaxZoomLevel`，UI 层 pill 自动过滤到硬件支持范围，pinch 范围同步
5. **默认美颜参数**：`defaultBeautySmooth` / `defaultBeautyWhiten` 从 30/20 改为 0/0（拍原图，需要时再手动调）
6. **照片编辑加裁切**：「裁切」Tab（第三个）提供 自由 / 16:9 / 4:3 / 1:1 / 3:4 / 9:16 六个比例；`img.copyCrop` 中心裁切 + `FilterViewModel.cropRatio` debounce
7. **点击相机画面自动对焦曝光**：`onTapUp` + `setFocusPoint` + `setExposurePoint`，0.9s 珊瑚色对焦指示框
8. **美颜滑动条变小 + 编辑区缩小**：字号 14→12、track 4→2pt、thumb 14→8；TabView 200→150、预览 0.45→0.38 屏幕

### 历史真机回归 bug 修复（2026-06-19，commit `3a1a4ad`）
1. **0.5x 焦段无反应**：pinch 手势 `clamp(1.0, 5.0)` 下限错误 → 改为 `clamp(0.5, 5.0)` + 记录 baseZoom 避免累计漂移（#4 已用硬件 query 替代这个软修法）
2. **拍照无反馈**：加 350ms 全屏闪白动画（`AnimationController`）+ `SystemSound.play(SystemSoundType.click)` 声效
3. **相册不是 app 内 grid**：新增 `AppPhotoRepository`（本地文件 + JSON manifest），与 `PhotoAlbumRepository`（photo_manager 读本机相册）解耦；PhotoAlbumScreen 改读 AppPhotoRepository
4. **照片处理 UX 缺陷**：
   - 照片预览改 `BoxFit.contain` + 黑色底，不裁切竖向照片（后续「〇二」中改为暖白底，去掉黑色）
   - FilterPanel 加 TabBar（滤镜 / 美颜），替代原来垂直堆叠
   - FilterViewModel 加 `previewBytes` 实时反映：selectFilter / setSmooth / setWhiten / setSlim 触发 200ms debounce 异步重处理 + `Image.memory` 显示
5. **保存照片被模糊**：`applyBeauty` 磨皮参数调小 —— radius `smooth/30`（30→1）、blendFactor `smooth/500`（30→0.06），不再糊脸

### B-F 子项目 ✅ 全部完成（7 commits, f42e33e..7deb6b2）
- **B 拍后编辑页**：FilterPanel 浮层 + `saveProcessedImage` 真写真册（`PhotoManager.editor.saveImage`），抽 `PhotoAlbumWriter` 抽象
- **C 调色**：FilterCarousel 5 个滤镜（珊瑚/港风/日系/胶片/原图）+ 选中态
- **D 美颜**：BeautySlider 三档滑杆（磨皮/美白/瘦脸）
- **E 菜单**：AppMenuSheet BottomSheet（姿势库/设置/关于）—— 落地页待 P1
- **F App内相册**：PhotoAlbumScreen 抽 `AppPhotoRepository` 抽象（取代 photo_manager）+ 长按多选删除

### 基础设施
- 完整 token 体系：AppColors / AppSpacing / AppRadii / AppTypography
- 中英 i18n：flutter gen-l10n，MaterialApp.router 接入
- 测试覆盖：62 个测试（21 A + 22 B-F + 8 真机回归 + 2 亮度 + 4 裁切 + 2 硬件 zoom + 1 裁切 UI + 2 变焦格式）全过
- 8 个 flutter analyze issues（全部预存在的 withOpacity deprecation，无新增）

### 下一步
- P1：E 菜单 3 个入口的落地页（姿势库管理 / 设置 / 关于）
- P1：用户自定义姿势导入
- 修剩余 8 个 withOpacity deprecation（Flutter 3.27+ 推荐 .withValues）
- AppPhotoRepository 持久化层可改用 hive（当前 JSON 够轻量）
- 裁切功能后续：当前是固定中心裁切，P2 可加可拖动选区 + 旋转

---

## 〇一、真机回归 bug 详细记录（2026-06-19）

> 概述：2026-06-18 第一次在真机跑通 P0 + B-F 全套流程，发现 5 个明显 UX/功能 bug。一并修复于 commit `3a1a4ad`，51/51 测试通过。

### Bug #1：0.5x 焦段无反应
- **现象**：后置相机点击 `.5` pill 偶尔无反应；双指 pinch 缩到最小时停在 1x
- **根因**：`lib/features/camera/camera_screen.dart` 的 pinch 手势把缩放下限 clamp 到了 1.0：
  ```dart
  final zoom = (state.currentZoom * details.scale).clamp(1.0, 5.0);
  ```
  用户从 1x 开始双指缩小时（`details.scale < 1.0`），计算结果 < 1.0，但被强行拉回 1.0。pill 路径走的是 `onZoomSelect(0.5)`，能传 0.5 进去但 pinch 路径到不了
- **修法**：
  - clamp 下限 1.0 → **0.5**（与 `_backZooms` 列表最小值对齐）
  - 加 `_gestureBaseZoom` 在 `onScaleStart` 时锁定基线，避免连续 pinch 时 `currentZoom * scale` 累计漂移
  ```dart
  onScaleStart: (_) => _gestureBaseZoom = state.currentZoom,
  onScaleUpdate: (d) {
    final zoom = (_gestureBaseZoom * d.scale).clamp(0.5, 5.0);
    notifier.setZoom(zoom);
  },
  ```

### Bug #2：拍照无反馈
- **现象**：按下快门后感觉"没反应"，等 1~2 秒才弹编辑面板，以为没点上
- **根因**：`onCapture` 之前是 `await takePicture()` → 直接弹编辑面板，**没有**任何"按下了"的视觉/听觉信号
- **修法**：在 `CameraScreen` 引入 `SingleTickerProviderStateMixin` + `AnimationController`，加 350ms 的 `TweenSequence` 闪白动画（150ms 渐白到 100% + 200ms 渐回 0），并把 `SystemSound.click` 一起触发：
  ```dart
  Future<void> _capture(CameraViewModel notifier) async {
    _flashController.forward(from: 0);                          // 闪白
    unawaited(SystemSound.play(SystemSoundType.click));         // 声效
    final path = await notifier.takePicture();
    if (path != null && mounted) { /* 弹编辑面板 */ }
  }
  ```
  闪白层用 `IgnorePointer` 包裹盖在 Stack 最上，pointer 事件不穿透

### Bug #3：相册是本机相册，不是 app 内 grid
- **现象**：点击相册按钮进的是设备整个相册（用户的其他照片混在里面），不是 app 拍过的
- **根因**：`lib/features/photo_album/photo_album_repository.dart` 用 `photo_manager` 读的是整个设备相册：
  ```dart
  PhotoManager.getAssetPathList(type: RequestType.image) // 设备全部
  recent.getAssetListRange(start: 0, end: 100)          // 最近 100 张
  ```
- **修法**：新建一个**完全独立**的 `AppPhotoRepository`（`lib/features/photo_album/app_photo_repository.dart`）：
  - **存储**：照片文件写到 `<documents>/app_photos/easy_beauty_<timestamp>.jpg`，路径索引写到 `manifest.json`（JSON，最新在前）
  - **抽象接口**：`listAll()` / `add(bytes)` / `delete(paths)`
  - **真实实现**：`AppPhotoRepositoryImpl`（落盘 + `path_provider` 拿 documents 目录）
  - **测试实现**：`InMemoryAppPhotoRepository`（纯 list，不走 IO）
  - `Provider` 默认绑定真实实现，测试里 override
  - `FilterViewModel.saveProcessedImage` 改成两步：`PhotoAlbumWriter.saveImage` 写真册（兼容旧）+ `AppPhotoRepository.add(processed)` 注册到 app grid
  - `PhotoAlbumScreen` 改读 `appPhotoRepositoryProvider`
  - **新增长按多选删除**：默认 tap 打开全屏预览；长按进入多选模式（AppBar 显示「已选 N」+ 删除按钮）；多选模式里 tap toggle；系统返回 / 取消按钮退出多选
  - 空态加 "还没有拍过照片" 提示

### Bug #4：照片处理页 UX 缺陷（三合一）

#### 子问题 4a：照片没显示全
- **现象**：竖向手机拍的照片在 300pt 高的预览容器里被上下裁切（cover 模式）
- **根因**：`FilterPanel` 的预览是 `Container(height: 300, fit: BoxFit.cover)`
- **修法**：
  - `BoxFit.contain` 完整显示
  - 黑色底兜底（照片两侧或上下留白时不会突兀）
  - `ClipRRect` + `AppRadii.xlAll` 圆角

#### 子问题 4b：滤镜/美颜没分 tab
- **现象**：3 个美颜滑杆和 5 个滤镜挤在同一个 BottomSheet 里很容易误触
- **修法**：用 `TabController` + `TabBar` + `TabBarView`：
  - Tab 0：滤镜（FilterCarousel）
  - Tab 1：美颜（BeautySlider）
  - 高度固定 200，TabBar 38pt

#### 子问题 4c：滤镜/美颜不实时反映
- **现象**：点滤镜 / 拉滑杆，预览图完全不变，要保存才能看到效果
- **根因**：`FilterPanel` 的预览图直接 `Image.file(File(state.imagePath))`——只显示原图
- **修法**：在 `FilterViewModelState` 加两个字段：
  - `Uint8List? originalBytes`（原图缓存，避免每次重读盘）
  - `Uint8List? previewBytes`（处理后的预览）
  引入 `Timer` + 200ms debounce：`selectFilter` / `setSmooth` / `setWhiten` / `setSlim` 变化时调度 `_runProcess`：
  1. 读原图（缓存到 `originalBytes`）
  2. `processImage` 出处理后 bytes
  3. 写入 `previewBytes` 触发 UI 重建
  `setImage` 是 `immediate: true`（新照片不 debounce），其余改动走 200ms debounce（滑动 slider 时不会连发几十次重处理）
  预览 widget：
  ```dart
  if (state.previewBytes != null)
    Image.memory(state.previewBytes!, fit: BoxFit.contain, ...)
  else if (state.imagePath != null)
    Image.file(File(state.imagePath!), fit: BoxFit.contain, ...)
  ```
  右上角小 `CircularProgressIndicator` 表示正在处理中（不遮挡图）
  `saveProcessedImage` 优先复用 `previewBytes`，省一次 process

### Bug #5：保存照片被模糊
- **现象**：磨皮滑杆拉到默认 30 就能看出照片明显糊掉
- **根因**：`lib/services/image_processing_service.dart` 的 `applyBeauty` 磨皮参数太重：
  ```dart
  final radius = (smooth / 10).round();      // smooth=30 → radius=3
  final blendFactor = smooth / 100;          // smooth=30 → 0.30
  ```
  高斯半径 3 已经能糊掉很多细节，混合 30% 像素直接变成"满脸磨皮感"，不是用户预期的"轻微磨皮"
- **修法**：两个参数都缩小：
  - `radius = (smooth / 30).round().clamp(1, 2)` —— smooth=30 → **1**，smooth=60 → **2**
  - `blendFactor = smooth / 500` —— smooth=30 → **0.06**（6%），smooth=100 → **0.20**（20%）
  效果：30 的磨皮 = 半径 1 的高斯 + 6% 混合，**只在皮肤纹理上做极轻微的平滑**，不再糊脸；100 的磨皮对应半径 2 + 20% 混合，仍然是"美颜"而不是"油画"
  美白参数没动（`whiten / 100 * 30` 加 0~30 的亮度），合理

### 修复总结表

| Bug | 根因 | 修法 | 影响文件 |
|---|---|---|---|
| #1 0.5x 焦段 | pinch clamp 下限错 | clamp(0.5, 5.0) + baseZoom | `camera_screen.dart` |
| #2 拍照无反馈 | 无闪白无声效 | AnimationController + SystemSound | `camera_screen.dart` |
| #3 相册错 | 读 device album | 新 `AppPhotoRepository` + 长按删除 | `app_photo_repository.dart` (新) + `photo_album_screen.dart` + `filter_view_model.dart` |
| #4a 裁切 | BoxFit.cover | BoxFit.contain + 黑色底 | `filter_panel.dart` |
| #4b 没分 tab | 垂直堆叠 | TabBar + TabBarView | `filter_panel.dart` |
| #4c 不实时 | Image.file 原图 | previewBytes + debounce | `filter_view_model.dart` + `filter_panel.dart` |
| #5 模糊 | radius 太大 | radius /30、blend /500 | `image_processing_service.dart` |

### 验证
- 51/51 测试通过（新增 7 个回归测试：`AppPhotoRepository` 4 个 + `FilterViewModel` 实时预览 3 个）
- `flutter analyze` 无新增 issue
- commit `3a1a4ad` 一并提交

---

## 〇二、FilterPanel 图片预览溢出（2026-06-20）

### 现象
- 真机拍完照进入编辑页时，flutter framework 报：`A RenderFlex overflowed by 144 pixels on the bottom.`
- 视觉表现：底部 144pt 内容（TabBar + TabBarView）被截掉，看不到 Tab 切换按钮

### 根因
- `FilterPanel._PhotoPreview` 用 `Image.memory(bytes, fit: BoxFit.contain, width: double.infinity)`
- Image 在 `width=double.infinity` 但无高度约束时，按图片**原始 aspect ratio** 决定高度
- 竖向 portrait 照片（9:16、3:4）原始 height 很大（3000~4000px），等比缩放到屏幕宽后仍很高
- bottomSheet 默认高度 ≈ 屏幕 9/16 ≈ 405pt；图片预览区按 aspect 算出来的高度 > 405pt → Column mainAxisSize.min 撑爆

### 修法
- 在 `_PhotoPreview` 外层包 `ConstrainedBox(maxHeight: 屏幕高 × 0.45)`
- 给最大高度 ≈ 360pt（800pt 屏幕），确保留出空间给顶部栏 + TabBar + TabBarView（~250pt）
- `BoxFit.contain` + 黑底 + `SizedBox.expand` 居中 → 竖向照片按比例缩到 maxHeight 内完整显示

```dart
final maxPreviewHeight = MediaQuery.of(context).size.height * 0.45;
return Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMain),
  child: ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxPreviewHeight),
    child: ClipRRect(
      borderRadius: AppRadii.xlAll,
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: Image.memory(bytes, fit: BoxFit.contain, ...),
        ),
      ),
    ),
  ),
);
```

### Regression 测试
- `test/widget/filter_panel_test.dart › 9:16 竖向 previewBytes 不溢出（800 屏幕 + tall png）`
- 模拟 360×800 屏幕（典型小屏手机） + 9:16 PNG bytes（用 Python 拼的最小透明 PNG）
- 断言：`tester.takeException()` 返回 null（没有 RenderFlex overflow 被吞）
- 验证过：临时把 `ConstrainedBox` 移除后这个测试**会失败**，确认能 catch bug

### 验证
- 52/52 测试通过
- `flutter analyze` 无新增 issue
- 仍然全 7 个 pre-existing info-level withOpacity lint

---

## 〇三、编辑页 UX 二轮修复（2026-06-20）

真机截图发现的 3 个新问题，全 3 个已修。

### 已修 #1：图片预览黑色背景
- **现象**：`_PhotoPreview` 用 `ColoredBox(color: Colors.black)` 兜底，导致竖向照片左右两侧出现黑色条
- **用户反馈**：不想要黑色背景（编辑页面是暖白底色，黑条很突兀）
- **修法**：去掉 `ColoredBox`，让图片在 `SizedBox.expand` 里直接 contain；左右留空区域透出 BottomSheet 的 `AppColors.overlayBg` 暖白底
- 顺手把处理中指示器从白色改成珊瑚色（原白色在浅底不可见）

### 已修 #2：滤镜选中边框撑满高度
- **现象**：选中「珊瑚」时，珊瑚色边框不是围住 50×50 颜色块，而是圈住整个 ListView 高度（~100pt）
- **根因**：`AnimatedContainer(width: 70)` 放在 `SizedBox(height: 100) > ListView` 里，被父级约束撑到 100pt 高；`Border.all` 加在这个外层 `AnimatedContainer` 上 → 边框跟着撑满
- **修法**：把 `Border.all` 移到内层 50×50 按钮上；外层只用 `Container(width: 70)` 给水平间距
- **Regression 测试**：「选中边框只包住 50×50 按钮，不撑满高度」—— 反向验证：临时把 border 改回外层后测试会失败

### 已修 #3：照片特别暗（用户确认是 bug，环境光充足）
- **用户反馈**：「照片暗不是拍照本身的问题，因为在拍摄的时候光照是足够的」—— 排除「环境本身暗」
- **最终根因**：
  1. **相机端**：iOS 上 Flutter `camera` 包预览流和 `takePicture` 出来的照片曝光参数可能不一致（已知问题）；相机没有调用 `setExposureOffset`，完全用系统默认曝光
  2. **处理端**：`image_processing_service.processImage` 只做滤镜 + 美颜，没有任何兜底亮度补偿
- **修法（双保险）**：
  - **相机端**（`lib/services/camera_service.dart`）：`initialize` / `switchCamera` 后调 `setExposureOffset(1.0)`（+1.0 档为经验值，在 iOS 上能明显补偿偏暗），用 try/catch 兜底（模拟器/部分 Android 抛 CameraException）
  - **处理端**（`lib/services/image_processing_service.dart`）：新增 `normalizeBrightness`，在 `processImage` 末尾自动调；算法 = Rec.709 mean luma < 75 时，把 RGB 各通道 + (110-mean)*0.85，clamp 255 防过曝；亮图（mean ≥ 75）原样不动
- **Regression 测试**：`test/services/image_processing_service_test.dart` 两组断言：
  - 偏暗图（rgb(30) 全填充，mean=30）经 processImage 后 mean luma ≥ 90（实际 ≈98）
  - 亮图（rgb(200) 全填充，mean=200）不被过度提亮，落在 [180, 220]
  - TDD 验证：先写测试确认 RED，再写实现确认 GREEN

### 验证
- 55/55 测试通过（+2 个亮度回归）
- `flutter analyze` 无新增 issue
- 7 个 pre-existing withOpacity lint 无变化

---

## 〇四、相机 / 编辑 / 相册 三端 UX 批量调整（2026-06-20）

真机使用中发现一批细节 UX 问题，一次性 8 项修于 commit `ee5aa3b`，62/62 测试通过。

### #1 相册全屏预览：关闭按钮放大 + 右上角
- **现象**：默认 `IconButton` 太小、位置在顶部 left（被刘海/灵动岛挡住），浅色照片上几乎看不见
- **修法**（`lib/features/photo_album/photo_album_screen.dart`）：
  - 尺寸从默认 ~40pt 升到 **48pt**（含半透明深色圆底）
  - `Positioned(top: 0, right: 0)` 固定右上角，加 `SafeArea` 避灵动岛
  - 圆底：`Colors.black.withValues(alpha: 0.4)` + 28pt 白色 close icon
  - 用 `Material + InkWell + CircleBorder` 保留涟漪反馈

### #2 焦段按钮文字统一为 "Nx"
- **现象**：之前 `.5` / `1x` / `2` / `3` 格式不一致（0.5 用 ".5" 是 iOS 风格，但 2/3 又是裸数字）
- **修法**（`lib/features/camera/widgets/camera_controls.dart` `_zoomLabel`）：
  ```dart
  String _zoomLabel(double z) {
    if (z == z.truncateToDouble()) return '${z.toInt()}x';  // 1 → "1x"
    return '${z.toString()}x';                              // 0.5 → "0.5x"
  }
  ```
- **Regression 测试**：4 个原断言（`.5` / `1x` / `2` / `3`）全部更新为 `0.5x` / `1x` / `2x` / `3x`

### #3 实时相机偏亮：回退曝光补偿
- **背景**：上一节为修「照片偏暗」加了 `setExposureOffset(+1.0)`，结果在某些机型上实时预览偏亮
- **修法**（`lib/services/camera_service.dart`）：
  - 删除 `initialize` / `switchCamera` 里的 `_applyExposureOffset(1.0)` 调用
  - 走相机默认曝光参数
  - 处理端 `normalizeBrightness` 兜底保留（双保险中的「处理端」那半边）
- **影响**：实时预览恢复正常亮度；保存的暗照片仍会被自动提亮

### #4 0.5x 焦段无效：跟随硬件实际支持范围
- **根因**：
  - 大部分 iOS 后置相机 `getMinZoomLevel() == 1.0`（不支持 0.5x）
  - 之前 `clamp(0.5, 5.0)` 是软下限，硬件 reject 0.5 后被 silently clamp 到 1.0，pill 也对不上
  - pinch 路径同样问题
- **修法**：
  - `CameraService._queryZoomRange()` 在 `initialize` / `switchCamera` 后查 `getMinZoomLevel` / `getMaxZoomLevel`，try/catch 兜底老 API
  - 暴露 `minZoomLevel` / `maxZoomLevel` getter
  - `CameraControls` 接收 `minZoom` / `maxZoom` 参数，pill 列表用 `.where((z) => z ∈ [minZoom, maxZoom])` 自动过滤
  - `camera_screen` pinch handler 用同一范围 clamp
  - `setZoom` 在 service 层也 clamp，UI 调用永远安全
- **效果**：硬件只支持 1.0~5.0 的设备，0.5x pill 自动不显示；双指 pinch 也会卡在 1.0；2x/3x 仍可点
- **Regression 测试**（`test/widget/camera_controls_test.dart`）：
  - `minZoom=1.0` 时 0.5x pill 被过滤（`findsNothing`）
  - `maxZoom=2.0` 时 3x pill 被过滤

### #5 默认美颜参数全部归 0
- **现象**：`AppConstants.defaultBeautySmooth = 30` / `defaultBeautyWhiten = 20` 是开发者默认值，但用户偏好"拍原图，需要时再手动调"
- **修法**（`lib/core/constants/app_constants.dart`）：三个美颜常量全改 0
  ```dart
  static const double defaultBeautySmooth = 0.0;
  static const double defaultBeautyWhiten = 0.0;
  static const double defaultBeautySlim   = 0.0;  // 本来就是 0
  ```
- **影响**：新照片进编辑页时滑杆全在 0 位置，预览 = 原图

### #6 照片编辑：新增「裁切」Tab
- **需求**：6 个比例（自由 / 16:9 / 4:3 / 1:1 / 3:4 / 9:16）
- **修法**：
  - **`lib/services/image_processing_service.dart`**：
    - 新增 `enum CropRatio { free, ratio_16_9, ratio_4_3, ratio_1_1, ratio_3_4, ratio_9_16 }` + `extension CropRatioX` 提供 `ratio`（double?）和 `label`（String）
    - 新增 `crop(Uint8List, CropRatio)`：用 `img.copyCrop` 做中心裁切，算法 = 比较 `imageW/H` 与目标比，裁宽/裁高
  - **`lib/features/filter/filter_view_model.dart`**：
    - `FilterViewModelState` 加 `cropRatio` 字段（默认 `CropRatio.free`）
    - 新增 `setCropRatio(CropRatio)` 方法，走 200ms debounce
    - `_runProcess` 在 `processImage` 之后、`normalizeBrightness` 之后按需调 `crop`
  - **`lib/features/filter/filter_panel.dart`**：`TabController(length: 2)` → 3；TabBar 加第 3 个「裁切」Tab
  - **`lib/features/filter/widgets/crop_ratio_bar.dart`**（新文件）：横向滚动 6 个比例 chip，珊瑚色填充选中态
- **Regression 测试**（`test/services/image_processing_service_test.dart`）：
  - 1:1 裁 400×200 → 200×200 ✓
  - 16:9 裁 200×400 → 200×113（`round(200×9/16) = 113`）✓
  - 9:16 裁 400×200 → 113×200 ✓
  - free 不裁切，输出尺寸与原图一致 ✓
  - `test/widget/filter_panel_test.dart` 新增「切到裁切 tab 显示 6 个比例按钮 + 切比例触发 setCropRatio」

### #7 点击相机画面自动对焦 + 曝光
- **背景**：iOS 系统相机点哪对焦哪，Flutter camera 包支持 `setFocusPoint` / `setExposurePoint` 但需要手动调
- **修法**：
  - **`lib/services/camera_service.dart`**：新增 `focusAndExposeAt(Offset point)`，`point ∈ [0,1]²` 是预览区域的归一化坐标；try/catch 兜底模拟器/不支持设备
  - **`lib/features/camera/camera_view_model.dart`**：薄包装 `focusAndExposeAt`
  - **`lib/features/camera/camera_screen.dart`**：
    - `GestureDetector` 加 `onTapUp`：把 `globalPosition` 转为相对当前 widget 的 [0,1] 坐标
    - 调 `notifier.focusAndExposeAt(point)` + `_showFocusIndicator(point, size)`
    - `_focusPoint` / `_focusSize` / `_focusTimer`：0.9s 后用 `setState(() => _focusPoint = null)` 自动消失
    - 指示器：`Container(80×80)` + 珊瑚色 1.5pt 边框 + 4pt 圆角，用 `Positioned` 算 `left/top = point * size - 40`
- **注意**：`onTapUp` 跟 `onScaleStart` / `onScaleUpdate` 在同一个 GestureDetector 上是 OK 的（GestureDetector 会区分 tap 和 scale）

### #8 美颜滑动条变小 + 编辑区再缩小
- **修法**：
  - **`lib/features/filter/widgets/beauty_slider.dart`**：
    - 标签列宽 40→36pt、字号 14→12pt
    - `SliderTheme`：`trackHeight=2`、`thumbShape=RoundSliderThumbShape(enabledThumbRadius: 8)`、`overlayShape=RoundSliderOverlayShape(overlayRadius: 14)`
    - 数值列宽 32→28pt、字号 14→11pt
    - 滑杆间 `SizedBox` 8→4pt
    - `_buildSlider` 现在接 `BuildContext context` 参数（之前是 closure，SliderTheme 找不到 context）
  - **`lib/features/filter/filter_panel.dart`**：
    - TabView 高度 200→150
    - `_PhotoPreview` maxHeight 屏幕比例 0.45→0.38（≈304pt @ 800pt 屏）

### 验证
- 62/62 测试通过（+2 亮度 + 4 裁切 + 2 硬件 zoom 过滤 + 1 裁切 UI）
- `flutter analyze` 无新增 issue
- 8 个 pre-existing withOpacity lint 无变化

### 一并修改的 8 项 vs 之前修法的关系
- #3 实时相机偏亮：撤销了 `〇三节 #3` 中「相机端加 setExposureOffset(+1.0)」那半边；处理端 `normalizeBrightness` 保留
- #4 0.5x 焦段：用硬件 query 替代了 `〇一节 #1` 里的「clamp 下限 0.5」软修法

---

## 〇五、自由裁切 + 美颜滑条间距（2026-06-20）

第二轮 UX 微调，2 项改动，76/76 测试通过。

### #1 裁切改为交互式（双指缩放 + 单指拖动）

**背景**：〇四节 #6 加的「裁切」Tab 是固定中心裁切（`img.copyCrop` 直接从源图中心裁出目标比例），用户无法：
- 调整裁切框位置（主体偏离中心时无法对准）
- 缩放后再裁切（先 zoom in 主体，再选比例）

**修法**：

**1) 新 widget `lib/features/filter/widgets/interactive_crop_editor.dart`**：
- `StatefulWidget` + `InteractiveViewer` + `TransformationController`
- 双指 pinch 缩放（`minScale: 1.0, maxScale: 4.0`），单指拖动平移
- 手势结束 200ms debounce 回调 `onTransformChanged(scale, translation)`
- 顶部叠一层 `CustomPaint` 裁切框遮罩：
  - 框外画半透明黑色（alpha 0.55）
  - 框边画 1.5pt `AppColors.primary`（珊瑚色）
- 自由比例下不画遮罩（框退化为全图边界）
- `previewBytes` 优先（实时预览）；无则用 `imagePath` 走 `Image.file`

**2) `FilterViewModelState` 加 transform 字段**：
```dart
final double scale;       // 默认 1.0
final Offset translation; // 默认 Offset.zero
```
- 新增 `setTransform({scale, translation})` 和 `resetTransform()` 方法
- **重要决策**：`setCropRatio` **不重置 transform** —— 用户拍板"切换比例时保留缩放/平移状态"
- copyWith 走 `?? this.x` 模式（与现有 smooth/whiten 一致）

**3) `ImageProcessingService.applyTransform` 新公开方法**：
- 算法：按 scale 算源图可见窗口大小 (`srcW/s, srcH/s`) + 按 translation 平移中心 + clamp 防止越界 + `img.copyCrop` + `img.copyResize` 到 target 尺寸
- 当 `scale ≤ 1.0 && translation == Offset.zero` 时走 short-circuit：只 resize 不裁
- Translation ∈ [-1, 1]，scale ∈ [1.0, 4.0]，clamp 兜底

**4) 处理流水线接入**：
```
原：processImage → crop
新：processImage → applyTransform(scale, translation, targetW, targetH)
```
- `_runProcess` 和 `saveProcessedImage` 都接入
- `applyTransform` 内部已经按目标比例 resize（计算 `targetW = targetH * ratio`），所以**不再单独调 crop**

**5) `FilterPanel` 接入**：
- 顶部 `_PhotoPreview` 类**删除**，替换为 `InteractiveCropEditor`（保留 `ConstrainedBox(maxHeight: 38%)` 防溢出）
- 三个 tab（滤镜 / 美颜 / 裁切）共享同一个编辑器 —— "所见即所得"
- 编辑器回调 → `notifier.setTransform(scale, translation)` 走 200ms debounce 重处理

**6) `CropRatioBar` 加「重置」按钮**：
- 位置：比例 chip 行**左端**
- 行为：`notifier.resetTransform()` → scale=1.0, translation=Offset.zero
- 状态：`scale != 1.0 || translation != Offset.zero` 时高亮可点（enabled），否则灰显（disabled）
- 样式与 `_RatioChip` 一致（pill 圆角 + AnimatedContainer）

**测试**（共 14 个新测试）：
- `image_processing_service_test.dart` 加 4 个：`applyTransform` 几何正确性（scale=1 透传、scale=2 中心裁、translation 平移、越界 clamp）
- `filter_view_model_preview_test.dart` 加 3 个：默认 transform 字段、`setTransform` 触发处理、`resetTransform` 回到默认、`setCropRatio` 不重置 transform
- `interactive_crop_editor_test.dart` 新建 3 个：渲染 InteractiveViewer+Image、非自由比例渲染 CustomPaint、自由比例不报错
- `crop_ratio_bar_test.dart` 新建 2 个：默认 state 渲染 6 chip + 重置按钮、scale≠1.0 点重置回 1.0

**潜在改进**（本次未做）：
- 旋转 / 镜像（`img.copyRotate` / 翻转）
- 多选框
- 历史撤销栈

### #2 美颜滑条间距 4pt → 12pt

**背景**：〇四节 #8 把间距从 8pt 砍到 4pt 砍过头了，操作时容易误触相邻滑杆

**修法**（`lib/features/filter/widgets/beauty_slider.dart`）：两处 `const SizedBox(height: 4)` → `const SizedBox(height: AppSpacing.gutterGrid)`（= 12pt）

### 验证
- 76/76 测试通过（+14 个新测试）
- `flutter analyze`：本次新加的代码 0 issues；18 个预存在 issues 无变化
- 8 commits: `4698287` `b146e5b` `6e9377f` `79c265d` `bf708c8` `f589758` `a1a9adc` `dd6d846` `b2d47b8`

### 一并修改的 2 项与之前的关系
- #1 自由裁切：把 〇四节 #6「裁切 Tab」的固定中心裁切升级为交互式
- #2 滑条间距：把 〇四节 #8 的 4pt 调回 12pt（之前砍过头）

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