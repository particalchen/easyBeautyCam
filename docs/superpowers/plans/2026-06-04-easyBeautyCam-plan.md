# EasyBeautyCam Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建 EasyBeautyCam iOS 拍照辅助应用，支持姿势轮廓叠加、滤镜美颜、远程姿势获取

**Architecture:** Flutter 跨平台应用，单套代码支持 iOS/Android/鸿蒙。分层架构：UI Layer → Business Logic Layer → Platform Layer。核心相机预览和姿势叠加层走 Flutter Widget，滤镜/美颜走本地图片处理。

**Tech Stack:** Flutter / Riverpod / camera / image / Hive / go_router

---

## 文件结构

```
easyBeautyCam/
├── lib/
│   ├── main.dart                          # App 入口
│   ├── app.dart                            # MaterialApp 配置
│   ├── core/
│   │   ├── theme/
│   │   │   └── app_theme.dart              # 色彩/字体/主题定义
│   │   └── constants/
│   │       └── app_constants.dart          # 常量（滤镜色值、姿势配置等）
│   ├── features/
│   │   ├── camera/
│   │   │   ├── camera_screen.dart          # 取景框主页面
│   │   │   ├── camera_view_model.dart      # 相机状态管理
│   │   │   └── widgets/
│   │   │       ├── pose_overlay.dart      # 姿势轮廓叠加 Widget
│   │   │       ├── pose_thumb_strip.dart  # 姿势缩略图横向滑动条
│   │   │       ├── camera_controls.dart   # 相机控制栏（1x/2x/3x、拍照按钮）
│   │   │       └── capture_button.dart     # 拍照按钮
│   │   ├── filter/
│   │   │   ├── filter_panel.dart          # 滤镜浮层
│   │   │   ├── filter_view_model.dart      # 滤镜状态管理
│   │   │   └── widgets/
│   │   │       ├── filter_carousel.dart   # 滤镜横向滑动选择器
│   │   │       └── beauty_slider.dart     # 美颜滑杆
│   │   ├── pose_library/
│   │   │   ├── pose_manager.dart          # 姿势管理器（本地+远程）
│   │   │   ├── pose_model.dart           # 姿势数据模型
│   │   │   └── pose_repository.dart      # 姿势仓储（Hive+远程）
│   │   └── photo_album/
│   │       └── photo_album_screen.dart   # 相册浏览
│   ├── services/
│   │   ├── camera_service.dart           # 相机服务
│   │   ├── image_processing_service.dart # 图片处理服务（滤镜+美颜）
│   │   └── pose_download_service.dart    # 远程姿势下载服务
│   └── shared/
│       └── widgets/
│           └── loading_overlay.dart       # 通用加载浮层
├── resources/
│   └── poses/                             # 内置4个姿势 PNG（手工提供）
├── assets/
│   └── poses/                             # 远程下载的姿势存放
└── pubspec.yaml                           # 依赖配置
```

---

## Task 1: 项目初始化

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/constants/app_constants.dart`

- [ ] **Step 1: 创建 pubspec.yaml**

```yaml
name: easy_beauty_cam
description: 让不会拍照的人轻松指挥模特摆出好看姿势的相机应用
version: 0.1.0

environment:
  sdk: '>=3.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.9
  camera: ^0.10.5+9
  image: ^4.1.3
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.2
  http: ^1.2.0
  go_router: ^13.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true
  assets:
    - resources/poses/
    - assets/poses/
```

- [ ] **Step 2: 创建 lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: EasyBeautyCamApp()));
}
```

- [ ] **Step 3: 创建 lib/app.dart**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/camera/camera_screen.dart';
import 'features/photo_album/photo_album_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const CameraScreen()),
    GoRoute(path: '/album', builder: (context, state) => const PhotoAlbumScreen()),
  ],
);

class EasyBeautyCamApp extends StatelessWidget {
  const EasyBeautyCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EasyBeautyCam',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 4: 创建 lib/core/theme/app_theme.dart**

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFFF8A7A);
  static const primaryGradientStart = Color(0xFFFFB4A2);
  static const primaryGradientEnd = Color(0xFFFF8A7A);
  static const background = Color(0xFFFFFAF8);
  static const textPrimary = Color(0xFF2D2D2D);
  static const textSecondary = Color(0xFF999999);
  static const poseLine = Color.fromRGBO(255, 255, 255, 0.55);
  static const overlayBackground = Color.fromRGBO(255, 250, 248, 0.95);
  static const cardBorder = Color(0xFFEEEEEE);
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
```

- [ ] **Step 5: 创建 lib/core/constants/app_constants.dart**

```dart
class AppConstants {
  static const int defaultPoseCount = 4;
  static const String poseRemoteBaseUrl = 'https://example.com/poses';
  static const String poseListJsonFile = 'poses.json';

  static const List<String> defaultFilters = [
    'Original',
    'Coral',
    '港风',
    '日系',
    '胶片',
  ];

  static const List<double> beautyRange = [0.0, 100.0];
  static const double defaultBeautySmooth = 30.0;
  static const double defaultBeautyWhiten = 20.0;
  static const double defaultBeautySlim = 0.0;
}
```

- [ ] **Step 6: 提交**

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
git init
git add pubspec.yaml lib/main.dart lib/app.dart lib/core/theme/app_theme.dart lib/core/constants/app_constants.dart
git commit -m "feat: 初始化 Flutter 项目，配置主题和常量"
```

---

## Task 2: 姿势数据模型和仓储

**Files:**
- Create: `lib/features/pose_library/pose_model.dart`
- Create: `lib/features/pose_library/pose_repository.dart`
- Create: `lib/features/pose_library/pose_manager.dart`
- Create: `lib/services/pose_download_service.dart`

- [ ] **Step 1: 创建 lib/features/pose_library/pose_model.dart**

```dart
class PoseModel {
  final String id;
  final String name;
  final String category;
  final String assetPath;
  final bool isLocal;
  final String? remoteUrl;

  const PoseModel({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
    this.isLocal = true,
    this.remoteUrl,
  });

  factory PoseModel.fromJson(Map<String, dynamic> json) {
    return PoseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      assetPath: json['asset_path'] as String,
      isLocal: false,
      remoteUrl: json['remote_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'asset_path': assetPath,
    'remote_url': remoteUrl,
  };
}
```

- [ ] **Step 2: 创建 lib/services/pose_download_service.dart**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'pose_model.dart';

class PoseDownloadService {
  static const String _baseUrl = 'https://example.com/poses';

  Future<List<PoseModel>> fetchRemotePoses() async {
    final response = await http.get(Uri.parse('$_baseUrl/poses.json'));
    if (response.statusCode != 200) return [];

    final List<dynamic> data = json.decode(response.body);
    return data.map((e) => PoseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> downloadPose(PoseModel pose, String localPath) async {
    if (pose.remoteUrl == null) return;
    final response = await http.get(Uri.parse(pose.remoteUrl!));
    if (response.statusCode == 200) {
      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);
    }
  }

  Future<String> get localPoseDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/poses';
  }
}
```

- [ ] **Step 3: 创建 lib/features/pose_library/pose_repository.dart**

```dart
import 'package:hive/hive.dart';
import 'pose_model.dart';
import '../../services/pose_download_service.dart';

class PoseRepository {
  final PoseDownloadService _downloadService = PoseDownloadService();

  Future<List<PoseModel>> loadLocalPoses() async {
    final box = await Hive.openBox<List>('poses');
    final List<dynamic>? stored = box.get('local_poses');
    if (stored != null) {
      return stored.cast<PoseModel>();
    }
    return [];
  }

  Future<void> saveLocalPoses(List<PoseModel> poses) async {
    final box = await Hive.openBox<List>('poses');
    await box.put('local_poses', poses);
  }

  Future<List<PoseModel>> syncRemotePoses() async {
    final remote = await _downloadService.fetchRemotePoses();
    return remote;
  }

  Future<void> downloadAndCachePose(PoseModel pose) async {
    final localDir = await _downloadService.localPoseDirectory;
    final localPath = '$localDir/${pose.id}.png';
    await _downloadService.downloadPose(pose, localPath);
  }
}
```

- [ ] **Step 4: 创建 lib/features/pose_library/pose_manager.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pose_model.dart';
import 'pose_repository.dart';

final poseRepositoryProvider = Provider<PoseRepository>((ref) => PoseRepository());

final poseManagerProvider = StateNotifierProvider<PoseManager, PoseManagerState>((ref) {
  return PoseManager(ref.watch(poseRepositoryProvider));
});

class PoseManagerState {
  final List<PoseModel> poses;
  final int selectedIndex;
  final bool isLoading;

  const PoseManagerState({
    this.poses = const [],
    this.selectedIndex = 0,
    this.isLoading = false,
  });

  PoseManagerState copyWith({
    List<PoseModel>? poses,
    int? selectedIndex,
    bool? isLoading,
  }) {
    return PoseManagerState(
      poses: poses ?? this.poses,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PoseManager extends StateNotifier<PoseManagerState> {
  final PoseRepository _repository;

  PoseManager(this._repository) : super(const PoseManagerState());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    final local = await _repository.loadLocalPoses();
    final remote = await _repository.syncRemotePoses();
    state = state.copyWith(
      poses: [...local, ...remote],
      isLoading: false,
    );
  }

  void selectPose(int index) {
    if (index >= 0 && index < state.poses.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }

  Future<void> addCustomPose(PoseModel pose) async {
    final updated = [...state.poses, pose];
    state = state.copyWith(poses: updated);
    await _repository.saveLocalPoses(updated);
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/features/pose_library/ lib/services/pose_download_service.dart
git commit -m "feat: 姿势数据模型、仓储和远程下载服务"
```

---

## Task 3: 相机服务和取景框页面

**Files:**
- Create: `lib/services/camera_service.dart`
- Create: `lib/features/camera/camera_view_model.dart`
- Create: `lib/features/camera/camera_screen.dart`

- [ ] **Step 1: 创建 lib/services/camera_service.dart**

```dart
import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _controller = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  CameraController? get controller => _controller;

  Future<void> setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setZoomFactor(zoom);
  }

  Future<void> switchCamera(int index) async {
    if (index < 0 || index >= _cameras.length) return;
    _controller?.dispose();
    _controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  Future<XFile?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    return await _controller!.takePicture();
  }

  void dispose() {
    _controller?.dispose();
  }
}
```

- [ ] **Step 2: 创建 lib/features/camera/camera_view_model.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/camera_service.dart';

final cameraServiceProvider = Provider<CameraService>((ref) => CameraService());

final cameraViewModelProvider = StateNotifierProvider<CameraViewModel, CameraViewModelState>((ref) {
  return CameraViewModel(ref.watch(cameraServiceProvider));
});

class CameraViewModelState {
  final bool isInitialized;
  final int cameraIndex;
  final double currentZoom;

  const CameraViewModelState({
    this.isInitialized = false,
    this.cameraIndex = 0,
    this.currentZoom = 1.0,
  });

  CameraViewModelState copyWith({
    bool? isInitialized,
    int? cameraIndex,
    double? currentZoom,
  }) {
    return CameraViewModelState(
      isInitialized: isInitialized ?? this.isInitialized,
      cameraIndex: cameraIndex ?? this.cameraIndex,
      currentZoom: currentZoom ?? this.currentZoom,
    );
  }
}

class CameraViewModel extends StateNotifier<CameraViewModelState> {
  final CameraService _cameraService;

  CameraViewModel(this._cameraService) : super(const CameraViewModelState());

  Future<void> initialize() async {
    await _cameraService.initialize();
    state = state.copyWith(isInitialized: true);
  }

  Future<void> setZoom(double zoom) async {
    await _cameraService.setZoom(zoom);
    state = state.copyWith(currentZoom: zoom);
  }

  Future<void> switchCamera(int index) async {
    await _cameraService.switchCamera(index);
    state = state.copyWith(cameraIndex: index);
  }

  Future<String?> takePicture() async {
    final file = await _cameraService.takePicture();
    return file?.path;
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 3: 创建 lib/features/camera/camera_screen.dart**

```dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_view_model.dart';
import 'widgets/pose_overlay.dart';
import 'widgets/pose_thumb_strip.dart';
import 'widgets/camera_controls.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cameraViewModelProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraViewModelProvider);
    final cameraNotifier = ref.read(cameraViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: cameraState.isInitialized
          ? _buildCameraView(cameraState, cameraNotifier)
          : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildCameraView(CameraViewModelState state, CameraViewModel notifier) {
    final controller = ref.watch(cameraServiceProvider).controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 相机画面
        Center(child: CameraPreview(controller)),
        // 姿势轮廓叠加
        const PoseOverlay(),
        // 底部姿势缩略图
        const Positioned(
          left: 0,
          right: 0,
          bottom: 120,
          child: PoseThumbStrip(),
        ),
        // 控制栏
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: CameraControls(
            cameraIndex: state.cameraIndex,
            onCameraSwitch: (index) => notifier.switchCamera(index),
            onCapture: () => notifier.takePicture(),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 提交**

```bash
git add lib/services/camera_service.dart lib/features/camera/camera_view_model.dart lib/features/camera/camera_screen.dart
git commit -m "feat: 相机服务和取景框主页面"
```

---

## Task 4: 姿势叠加 Widget

**Files:**
- Create: `lib/features/camera/widgets/pose_overlay.dart`

- [ ] **Step 1: 创建 lib/features/camera/widgets/pose_overlay.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pose_library/pose_manager.dart';
import '../../../core/theme/app_theme.dart';

class PoseOverlay extends ConsumerWidget {
  const PoseOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poseState = ref.watch(poseManagerProvider);
    if (poseState.poses.isEmpty || poseState.selectedIndex >= poseState.poses.length) {
      return const SizedBox.shrink();
    }

    final currentPose = poseState.poses[poseState.selectedIndex];

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.55,
          child: Image.asset(
            currentPose.assetPath,
            fit: BoxFit.contain,
            color: Colors.white,
            colorBlendMode: BlendMode.srcATop,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/camera/widgets/pose_overlay.dart
git commit -m "feat: 姿势轮廓叠加 Widget"
```

---

## Task 5: 姿势缩略图横向滑动条

**Files:**
- Create: `lib/features/camera/widgets/pose_thumb_strip.dart`

- [ ] **Step 1: 创建 lib/features/camera/widgets/pose_thumb_strip.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pose_library/pose_manager.dart';
import '../../../core/theme/app_theme.dart';

class PoseThumbStrip extends ConsumerWidget {
  const PoseThumbStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poseState = ref.watch(poseManagerProvider);

    if (poseState.poses.isEmpty) {
      return const SizedBox(height: 80);
    }

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: poseState.poses.length,
        itemBuilder: (context, index) {
          final isSelected = index == poseState.selectedIndex;
          final pose = poseState.poses[index];

          return GestureDetector(
            onTap: () => ref.read(poseManagerProvider.notifier).selectPose(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              height: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
                  width: isSelected ? 2 : 1,
                ),
                scale: isSelected ? 1.05 : 1.0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  pose.assetPath,
                  fit: BoxFit.cover,
                  color: Colors.white.withOpacity(isSelected ? 0.9 : 0.5),
                  colorBlendMode: BlendMode.srcATop,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/camera/widgets/pose_thumb_strip.dart
git commit -m "feat: 姿势缩略图横向滑动条"
```

---

## Task 6: 相机控制栏和拍照按钮

**Files:**
- Create: `lib/features/camera/widgets/camera_controls.dart`
- Create: `lib/features/camera/widgets/capture_button.dart`

- [ ] **Step 1: 创建 lib/features/camera/widgets/capture_button.dart**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CaptureButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CaptureButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryGradientStart, AppColors.primaryGradientEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 lib/features/camera/widgets/camera_controls.dart**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'capture_button.dart';

class CameraControls extends StatelessWidget {
  final int cameraIndex;
  final Function(int) onCameraSwitch;
  final VoidCallback onCapture;

  const CameraControls({
    super.key,
    required this.cameraIndex,
    required this.onCameraSwitch,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 相册按钮
          _buildControlButton(
            icon: Icons.photo_library_outlined,
            onTap: () => Navigator.pushNamed(context, '/album'),
          ),
          // 镜头切换按钮
          Row(
            children: [
              _buildLensButton('1x', 0),
              const SizedBox(width: 8),
              _buildLensButton('2x', 1),
              const SizedBox(width: 8),
              _buildLensButton('3x', 2),
            ],
          ),
          // 拍照按钮
          CaptureButton(onPressed: onCapture),
          // 占位（对称布局）
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildLensButton(String label, int index) {
    final isSelected = cameraIndex == index;
    return GestureDetector(
      onTap: () => onCameraSwitch(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/features/camera/widgets/camera_controls.dart lib/features/camera/widgets/capture_button.dart
git commit -m "feat: 相机控制栏和拍照按钮"
```

---

## Task 7: 图片处理服务（滤镜+美颜）

**Files:**
- Create: `lib/services/image_processing_service.dart`

- [ ] **Step 1: 创建 lib/services/image_processing_service.dart**

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum FilterType { original, coral, gangfeng, rixi, jiaopian }

class ImageProcessingService {
  static const Map<FilterType, List<double>> _filterMatrices = {
    FilterType.original: [],
    FilterType.coral: [
      1.1, 0, 0, 0, 10,
      0, 1.05, 0, 0, 8,
      0, 0, 0.95, 0, 5,
      0, 0, 0, 1, 0,
    ],
    FilterType.gangfeng: [
      1.2, 0, 0, 0, -10,
      0, 1.1, 0, 0, -5,
      0, 0, 0.9, 0, 10,
      0, 0, 0, 1, 0,
    ],
    FilterType.rixi: [
      1.05, 0, 0, 0, 15,
      0, 1.05, 0, 0, 15,
      0, 0, 1.1, 0, 5,
      0, 0, 0, 1, 0,
    ],
    FilterType.jiaopian: [
      0.9, 0.1, 0.1, 0, 5,
      0.1, 0.85, 0.1, 0, 5,
      0.1, 0.1, 0.9, 0, 10,
      0, 0, 0, 1, 0,
    ],
  };

  Future<Uint8List> applyFilter(Uint8List imageBytes, FilterType filter) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final matrix = _filterMatrices[filter];
    if (matrix == null || matrix.isEmpty) return imageBytes;

    final colored = img.ColorFilter.mat(_filterMatrices[filter]!);
    final filtered = img.colorFilter(colored).convert(image);

    return Uint8List.fromList(img.encodepng(filtered));
  }

  Future<Uint8List> applyBeauty(
    Uint8List imageBytes, {
    double smooth = 30,
    double whiten = 20,
    double slim = 0,
  }) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    var result = image;

    // 磨皮（高斯模糊 + 叠加）
    if (smooth > 0) {
      final blurred = img.gaussianBlur(result, radius: (smooth / 10).round());
      final blendFactor = smooth / 100;
      result = img.Image(width: result.width, height: result.height);
      for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
          final orig = result.getPixel(x, y);
          final blur = blurred.getPixel(x, y);
          result.setPixelRgba(
            x, y,
            ((orig.r * (1 - blendFactor) + blur.r * blendFactor)).round(),
            ((orig.g * (1 - blendFactor) + blur.g * blendFactor)).round(),
            ((orig.b * (1 - blendFactor) + blur.b * blendFactor)).round(),
            orig.a.toInt(),
          );
        }
      }
    }

    // 美白（调整亮度）
    if (whiten > 0) {
      final adjust = (whiten / 100 * 30).round();
      for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
          final p = result.getPixel(x, y);
          result.setPixelRgba(
            x, y,
            (p.r + adjust).clamp(0, 255),
            (p.g + adjust).clamp(0, 255),
            (p.b + adjust).clamp(0, 255),
            p.a.toInt(),
          );
        }
      }
    }

    return Uint8List.fromList(img.encodepng(result));
  }

  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
  }) async {
    var result = imageBytes;
    result = await applyFilter(result, filter);
    result = await applyBeauty(
      result,
      smooth: smooth,
      whiten: whiten,
      slim: slim,
    );
    return result;
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/services/image_processing_service.dart
git commit -m "feat: 图片处理服务（滤镜+美颜）"
```

---

## Task 8: 滤镜浮层 UI

**Files:**
- Create: `lib/features/filter/filter_view_model.dart`
- Create: `lib/features/filter/filter_panel.dart`
- Create: `lib/features/filter/widgets/filter_carousel.dart`
- Create: `lib/features/filter/widgets/beauty_slider.dart`

- [ ] **Step 1: 创建 lib/features/filter/filter_view_model.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/image_processing_service.dart';
import '../../../core/constants/app_constants.dart';

final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService();
});

final filterViewModelProvider = StateNotifierProvider<FilterViewModel, FilterViewModelState>((ref) {
  return FilterViewModel(ref.watch(imageProcessingServiceProvider));
});

class FilterViewModelState {
  final String? imagePath;
  final FilterType selectedFilter;
  final double smooth;
  final double whiten;
  final double slim;
  final bool isProcessing;

  const FilterViewModelState({
    this.imagePath,
    this.selectedFilter = FilterType.coral,
    this.smooth = AppConstants.defaultBeautySmooth,
    this.whiten = AppConstants.defaultBeautyWhiten,
    this.slim = AppConstants.defaultBeautySlim,
    this.isProcessing = false,
  });

  FilterViewModelState copyWith({
    String? imagePath,
    FilterType? selectedFilter,
    double? smooth,
    double? whiten,
    double? slim,
    bool? isProcessing,
  }) {
    return FilterViewModelState(
      imagePath: imagePath ?? this.imagePath,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      smooth: smooth ?? this.smooth,
      whiten: whiten ?? this.whiten,
      slim: slim ?? this.slim,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class FilterViewModel extends StateNotifier<FilterViewModelState> {
  final ImageProcessingService _processingService;

  FilterViewModel(this._processingService) : super(const FilterViewModelState());

  void setImage(String path) {
    state = state.copyWith(imagePath: path);
  }

  void selectFilter(FilterType filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setSmooth(double value) {
    state = state.copyWith(smooth: value);
  }

  void setWhiten(double value) {
    state = state.copyWith(whiten: value);
  }

  void setSlim(double value) {
    state = state.copyWith(slim: value);
  }

  Future<String?> saveProcessedImage() async {
    if (state.imagePath == null) return null;
    state = state.copyWith(isProcessing: true);

    final bytes = await _processingService.processImage(
      await _processingService.processImage(
        await _readImageBytes(state.imagePath!),
        filter: state.selectedFilter,
      ),
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
    );

    state = state.copyWith(isProcessing: false);
    return state.imagePath;
  }

  Future<Uint8List> _readImageBytes(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }
}
```

- [ ] **Step 2: 创建 lib/features/filter/widgets/filter_carousel.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../filter_view_model.dart';
import '../../../services/image_processing_service.dart';
import '../../../core/theme/app_theme.dart';

class FilterCarousel extends ConsumerWidget {
  const FilterCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: FilterType.values.length,
        itemBuilder: (context, index) {
          final filter = FilterType.values[index];
          final isSelected = filter == state.selectedFilter;
          final filterName = _getFilterName(filter);

          return GestureDetector(
            onTap: () => notifier.selectFilter(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getFilterPreviewColor(filter),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filterName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getFilterName(FilterType filter) {
    switch (filter) {
      case FilterType.original: return '原图';
      case FilterType.coral: return '珊瑚';
      case FilterType.gangfeng: return '港风';
      case FilterType.rixi: return '日系';
      case FilterType.jiaopian: return '胶片';
    }
  }

  Color _getFilterPreviewColor(FilterType filter) {
    switch (filter) {
      case FilterType.original: return Colors.grey;
      case FilterType.coral: return const Color(0xFFFFB4A2);
      case FilterType.gangfeng: return const Color(0xFF8B7355);
      case FilterType.rixi: return const Color(0xFFFFF8DC);
      case FilterType.jiaopian: return const Color(0xFFD4A574);
    }
  }
}
```

- [ ] **Step 3: 创建 lib/features/filter/widgets/beauty_slider.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../filter_view_model.dart';
import '../../../core/theme/app_theme.dart';

class BeautySlider extends ConsumerWidget {
  const BeautySlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterViewModelProvider);
    final notifier = ref.read(filterViewModelProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          _buildSlider('磨皮', state.smooth, (v) => notifier.setSmooth(v)),
          const SizedBox(height: 8),
          _buildSlider('美白', state.whiten, (v) => notifier.setWhiten(v)),
          const SizedBox(height: 8),
          _buildSlider('瘦脸', state.slim, (v) => notifier.setSlim(v)),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.2),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${value.round()}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 创建 lib/features/filter/filter_panel.dart**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'filter_view_model.dart';
import 'widgets/filter_carousel.dart';
import 'widgets/beauty_slider.dart';
import '../../core/theme/app_theme.dart';

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filterViewModelProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.overlayBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                const Text('编辑', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => _save(context, ref),
                  child: const Text('保存', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
          // 图片预览
          if (state.imagePath != null)
            Container(
              height: 300,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(File(state.imagePath!)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 16),
          // 滤镜选择
          const FilterCarousel(),
          const SizedBox(height: 16),
          // 美颜滑杆
          const BeautySlider(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(filterViewModelProvider.notifier);
    await notifier.saveProcessedImage();
    if (context.mounted) Navigator.pop(context, true);
  }
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/features/filter/
git commit -m "feat: 滤镜浮层 UI 和美颜滑杆"
```

---

## Task 9: 相册页面

**Files:**
- Create: `lib/features/photo_album/photo_album_screen.dart`

- [ ] **Step 1: 创建 lib/features/photo_album/photo_album_screen.dart**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoAlbumScreen extends StatefulWidget {
  const PhotoAlbumScreen({super.key});

  @override
  State<PhotoAlbumScreen> createState() => _PhotoAlbumScreenState();
}

class _PhotoAlbumScreenState extends State<PhotoAlbumScreen> {
  List<AssetEntity> _photos = [];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final permission = await PhotoManager.requestPermission();
    if (!permission.isAuth) return;

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;

    final recent = albums.first;
    final count = await recent.assetCountAsync;
    final assets = await recent.getAssetListRange(start: 0, end: count.clamp(0, 100));

    setState(() => _photos = assets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('相册'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          final photo = _photos[index];
          return FutureBuilder<Widget>(
            future: _buildThumbnail(photo),
            builder: (context, snapshot) {
              return snapshot.data ?? const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  Future<Widget> _buildThumbnail(AssetEntity photo) async {
    final file = await photo.file;
    if (file == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _openPhoto(file.path),
      child: Image.file(file, fit: BoxFit.cover),
    );
  }

  void _openPhoto(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: Center(child: Image.file(File(path))),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/photo_album/photo_album_screen.dart
git commit -m "feat: 相册浏览页面"
```

---

## Task 10: 双指缩放（姿势轮廓固定大小）

**Files:**
- Modify: `lib/features/camera/camera_screen.dart`

- [ ] **Step 1: 修改 camera_screen.dart 添加缩放手势**

在 `_CameraScreenState` 中添加 `GestureDetector` 包裹相机预览：

```dart
// 在 _buildCameraView 里的 CameraPreview 外套一层 GestureDetector
Widget _buildCameraView(CameraViewModelState state, CameraViewModel notifier) {
  final controller = ref.watch(cameraServiceProvider).controller;
  if (controller == null || !controller.value.isInitialized) {
    return const Center(child: CircularProgressIndicator());
  }

  return Stack(
    fit: StackFit.expand,
    children: [
      // 双指缩放手势层（姿势轮廓不在这里，在 Stack 里独立）
      GestureDetector(
        onScaleUpdate: (details) {
          final zoom = (state.currentZoom * details.scale).clamp(1.0, 5.0);
          notifier.setZoom(zoom);
        },
        child: Center(child: CameraPreview(controller)),
      ),
      // 姿势轮廓叠加（不跟随缩放，保持原大小）
      const PoseOverlay(),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 120,
        child: PoseThumbStrip(),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 20,
        child: CameraControls(
          cameraIndex: state.cameraIndex,
          onCameraSwitch: (index) => notifier.switchCamera(index),
          onCapture: () => notifier.takePicture(),
        ),
      ),
    ],
  );
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/camera/camera_screen.dart
git commit -m "feat: 双指缩放手势，姿势轮廓不跟随缩放"
```

---

## Task 11: 拍照后触发滤镜浮层

**Files:**
- Modify: `lib/features/camera/camera_screen.dart`
- Modify: `lib/features/camera/camera_view_model.dart`

- [ ] **Step 1: 修改 CameraControls 的 onCapture**

在 `CaptureButton` 的 `onPressed` 中，拍完照后打开滤镜浮层：

```dart
// 在 CameraControls 的 onCapture 回调中：
GestureDetector(
  onTap: () async {
    final path = await onCapture();
    if (path != null && context.mounted) {
      ref.read(filterViewModelProvider.notifier).setImage(path);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const FilterPanel(),
      );
    }
  },
  child: CaptureButton(onPressed: () {}),
)
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/camera/camera_screen.dart
git commit -m "feat: 拍照后触发滤镜浮层"
```

---

## Task 12: 启动时远程姿势同步

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 在 main.dart 中初始化时触发姿势同步**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 启动时同步远程姿势
  final poseRepo = PoseRepository();
  await poseRepo.syncRemotePoses();

  runApp(const ProviderScope(child: EasyBeautyCamApp()));
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/main.dart
git commit -m "feat: 启动时同步远程姿势"
```

---

## 自检清单

- [ ] Spec 覆盖：P0 功能全部有对应 Task 实现
- [ ] 占位符扫描：无 TBD/TODO/step 代码块完整
- [ ] 类型一致性：FilterType 枚举在 filter_view_model 和 image_processing_service 中一致
- [ ] 姿势轮廓不跟随缩放：已通过 Stack + IgnorePointer 实现分离
- [ ] 单手操作：拍照按钮在屏幕下方中央

---

**Plan 完成，已保存到 `docs/superpowers/plans/2026-06-04-easyBeautyCam-plan.md`**

两个执行选项：

**1. Subagent-Driven（推荐）** — 每个 Task 分派独立的 subagent 完成，Task 间并行的并行，最后你来 review

**2. Inline Execution** — 我在当前 session 里按 Task 顺序执行，每个节点 review 后再往前走

你选哪个？