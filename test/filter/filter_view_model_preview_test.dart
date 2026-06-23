import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/services/face_detection_service.dart';
import 'package:easy_beauty_cam/services/face_mask_builder.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

/// 测试专用：记录每次 processImage 调用 + 返回不同 bytes（用于断言"参数传对"）
class _CapturingProcessingService extends ImageProcessingService {
  int callCount = 0;
  int applyTransformCallCount = 0;
  int applyFilterCallCount = 0;
  int applyBeautyCallCount = 0;
  int normalizeBrightnessCallCount = 0;
  double? lastScale;
  Offset? lastTranslation;
  double? lastTargetRatio;
  double? lastSmooth;
  double? lastWhiten;
  double? lastSlim;
  img.Image? lastMask;
  // 用真实可解码的 1x1 PNG（每次 append 计数器字节来区分调用），
  // 让 view model 里的 `img.decodeImage(processed)` 走通。
  final Uint8List _basePng = Uint8List.fromList(img.encodePng(
    img.Image(width: 1, height: 1),
  ));
  Uint8List _bytes = Uint8List.fromList(img.encodePng(
    img.Image(width: 1, height: 1),
  ));

  @override
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
    img.Image? mask,
  }) async {
    callCount++;
    // 复用基础 PNG 字节 + 在尾部追加计数器字节，让每个 call 返回值仍然合法 PNG 头
    _bytes = Uint8List.fromList([..._basePng, callCount & 0xff]);
    return _bytes;
  }

  @override
  Future<Uint8List> applyFilter(Uint8List imageBytes, FilterType filter) async {
    applyFilterCallCount++;
    // 返回合法 1x1 PNG（无 counter 后缀），保证后续 decodeImage 走通
    return _basePng;
  }

  @override
  Future<Uint8List> applyBeauty(
    Uint8List imageBytes, {
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
    img.Image? mask,
  }) async {
    applyBeautyCallCount++;
    lastSmooth = smooth;
    lastWhiten = whiten;
    lastSlim = slim;
    lastMask = mask;
    return _basePng;
  }

  @override
  Future<Uint8List> normalizeBrightness(Uint8List imageBytes) async {
    normalizeBrightnessCallCount++;
    return _basePng;
  }

  @override
  Future<Uint8List> applyTransform(
    Uint8List imageBytes, {
    required double scale,
    required Offset translation,
    required double? targetRatio,
  }) async {
    applyTransformCallCount++;
    lastScale = scale;
    lastTranslation = translation;
    lastTargetRatio = targetRatio;
    return imageBytes;
  }
}

class _NoopWriter implements PhotoAlbumWriter {
  Uint8List? lastSavedBytes;
  @override
  Future<void> saveImage(Uint8List bytes, {required String filename}) async {
    lastSavedBytes = bytes;
  }
}

class _NoopRepo implements AppPhotoRepository {
  @override
  Future<List<String>> listAll() async => const [];
  @override
  Future<String> add(Uint8List bytes) async => '/noop';
  @override
  Future<void> delete(List<String> paths) async {}
}

// 记录 detect 调用次数 + 返回固定 1 张脸
// 复刻基类缓存机制：相同 imagePath 第二次调 detect 不算"真正"调用（detectCallCount 不增长）。
class _StubFaceDetector extends FaceDetectionService {
  int detectCallCount = 0;
  final List<FaceContours> cannedResult;
  final Set<String> _seenPaths = {};

  _StubFaceDetector({this.cannedResult = const []})
      : super(detectFn: (path, bytes) async => cannedResult);

  @override
  Future<List<FaceContours>> detect(String imagePath, {Uint8List? bytes}) async {
    if (_seenPaths.add(imagePath)) {
      // 新路径 → 真正"打"到 detectFn
      detectCallCount++;
    }
    // 缓存命中行为：与基类一致（同 path 返回相同结果）
    return cannedResult;
  }
}

class _StubMaskBuilder extends FaceMaskBuilder {
  int buildCallCount = 0;
  img.Image? cannedMask;

  _StubMaskBuilder({this.cannedMask});

  @override
  img.Image buildMask({
    required int width,
    required int height,
    required List<FaceContours> faces,
    int featherRadius = 8,
    bool excludeEyesLips = true,
  }) {
    buildCallCount++;
    return cannedMask ?? img.Image(width: 1, height: 1, numChannels: 1);
  }
}

void main() {
  group('FilterViewModel 实时预览', () {
    late _CapturingProcessingService svc;
    late ProviderContainer container;
    late File tempFile;

    setUp(() async {
      svc = _CapturingProcessingService();
      tempFile = await File(
        '${Directory.systemTemp.path}/preview_${DateTime.now().microsecondsSinceEpoch}.jpg',
      ).create();
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

      container = ProviderContainer(
        overrides: [
          imageProcessingServiceProvider.overrideWithValue(svc),
          photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
          appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
          faceDetectionServiceProvider.overrideWithValue(_StubFaceDetector()),
          faceMaskBuilderProvider.overrideWithValue(_StubMaskBuilder()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      if (await tempFile.exists()) await tempFile.delete();
    });

    test('setImage 后 previewBytes 被填充', () async {
      container.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      // 等异步 _runProcess 完成
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(filterViewModelProvider);
      expect(state.previewBytes, isNotNull);
      expect(state.previewBytes!.isNotEmpty, isTrue);
      expect(state.isPreviewProcessing, isFalse);
      expect(svc.applyFilterCallCount, greaterThanOrEqualTo(1));
    });

    test('selectFilter 触发新一次 processImage', () async {
      container.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.applyFilterCallCount;

      container
          .read(filterViewModelProvider.notifier)
          .selectFilter(FilterType.gangfeng);
      // 200ms debounce 后才执行
      await Future<void>.delayed(const Duration(milliseconds: 280));

      expect(svc.applyFilterCallCount, greaterThan(c1));
    });

    test('saveProcessedImage 优先复用 previewBytes，不再 process', () async {
      container.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.callCount;

      await container
          .read(filterViewModelProvider.notifier)
          .saveProcessedImage();

      // 不再调一次 process（save 时复用 previewBytes）
      expect(svc.callCount, c1);
    });

    test('默认 scale=1.0, translation=Offset.zero', () {
      final state = container.read(filterViewModelProvider);
      expect(state.scale, 1.0);
      expect(state.translation, Offset.zero);
    });

    test('setTransform 更新 scale/translation 并触发处理', () async {
      container.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.applyFilterCallCount;

      container.read(filterViewModelProvider.notifier).setTransform(
            scale: 2.0,
            translation: const Offset(10, 20),
          );
      await Future<void>.delayed(const Duration(milliseconds: 280));

      final state = container.read(filterViewModelProvider);
      expect(state.scale, 2.0);
      expect(state.translation, const Offset(10, 20));
      expect(svc.applyFilterCallCount, greaterThan(c1), reason: 'setTransform 应触发重新处理');
    });

    test('resetTransform 把 scale/translation 拉回默认', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setTransform(scale: 3.0, translation: const Offset(50, 50));
      notifier.resetTransform();
      final state = container.read(filterViewModelProvider);
      expect(state.scale, 1.0);
      expect(state.translation, Offset.zero);
    });

    test('setCropRatio 不重置 transform', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setTransform(scale: 2.5, translation: const Offset(30, 40));

      notifier.setCropRatio(CropRatio.ratio_1_1);

      final state = container.read(filterViewModelProvider);
      expect(state.scale, 2.5, reason: '切换比例不能把 scale 拉回 1.0');
      expect(state.translation, const Offset(30, 40), reason: '切换比例不能把 translation 清零');
      expect(state.cropRatio, CropRatio.ratio_1_1);
    });

    test('setTransform 触发 processImage 重跑（预览只跑滤镜+美颜）', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setCropRatio(CropRatio.ratio_1_1);
      notifier.setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.applyFilterCallCount;
      final at1 = svc.applyTransformCallCount;

      notifier.setTransform(scale: 2.0, translation: const Offset(0.1, 0.2));
      await Future<void>.delayed(const Duration(milliseconds: 280));

      // setTransform 仍触发 _runProcess（重跑滤镜+美颜）
      expect(svc.applyFilterCallCount, greaterThan(c1), reason: 'setTransform 应触发 _runProcess');
      // 但 _runProcess 不再调 applyTransform（裁切只在 save 时）
      expect(svc.applyTransformCallCount, at1,
          reason: '预览不调 applyTransform');
    });

    test('setCropRatio 切换比例不触发 applyTransform (预览保持未裁切图)', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      svc.applyTransformCallCount = 0; // 重置计数

      notifier.setCropRatio(CropRatio.ratio_1_1);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(svc.applyTransformCallCount, 0,
          reason: 'setCropRatio 不应触发 applyTransform');
    });

    test('_runProcess 不调用 applyTransform (预览只跑滤镜+美颜)', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setCropRatio(CropRatio.ratio_1_1); // 即便比例非自由
      notifier.setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(svc.applyTransformCallCount, 0,
          reason: '_runProcess 只跑滤镜+美颜，不做裁切');
    });

    test('saveProcessedImage 自由比例 + scale != 1.0 调用 applyTransform(targetRatio: null)',
        () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      notifier.setTransform(scale: 2.0, translation: Offset.zero);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      svc.applyTransformCallCount = 0;
      await notifier.saveProcessedImage();

      expect(svc.applyTransformCallCount, 1);
      expect(svc.lastTargetRatio, isNull,
          reason: '自由比例 + scale != 1.0 应传 targetRatio: null');
    });

    test('saveProcessedImage 自由比例 + scale=1.0 + translation=zero 不调用 applyTransform',
        () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      svc.applyTransformCallCount = 0;
      await notifier.saveProcessedImage();

      expect(svc.applyTransformCallCount, 0,
          reason: '自由比例 + 未缩放平移 = 不需要 applyTransform');
    });

    test('FilterViewModelState 默认 cropRatio 是 CropRatio.original', () {
      const state = FilterViewModelState();
      expect(state.cropRatio, CropRatio.original);
    });

    test('FilterViewModelState 默认 selectedFilter 是 FilterType.original', () {
      const state = FilterViewModelState();
      expect(state.selectedFilter, FilterType.original);
    });

    test(
        'saveProcessedImage 在 cropRatio=original + scale!=1 时调 applyTransform(targetRatio: null)',
        () async {
      final processing = _CapturingProcessingService();
      final writer = _NoopWriter();
      final repo = _NoopRepo();
      final vm = FilterViewModel(processing, writer, repo, _StubFaceDetector(), _StubMaskBuilder());
      vm.setImage(tempFile.path);
      await Future.delayed(const Duration(milliseconds: 300));

      // vm 默认 cropRatio = original
      vm.setTransform(scale: 2.0, translation: Offset.zero);
      await Future.delayed(const Duration(milliseconds: 300));

      processing.applyTransformCallCount = 0;
      await vm.saveProcessedImage();

      expect(processing.applyTransformCallCount, 1);
      expect(processing.lastTargetRatio, isNull);
    });

    test('saveProcessedImage 比例 1:1 调用 applyTransform(targetRatio: 1.0) 输出不拉伸',
        () async {
      // 用真实 service 跑
      final processing = ImageProcessingService();
      final realWriter = _NoopWriter();
      final realRepo = _NoopRepo();

      final src = img.Image(width: 4000, height: 3000);
      img.fill(src, color: img.ColorRgb8(255, 0, 0));
      final testPath = '${Directory.systemTemp.path}/test_4000x3000.png';
      File(testPath).writeAsBytesSync(Uint8List.fromList(img.encodePng(src)));

      final realContainer = ProviderContainer(
        overrides: [
          imageProcessingServiceProvider.overrideWithValue(processing),
          photoAlbumWriterProvider.overrideWithValue(realWriter),
          appPhotoRepositoryProvider.overrideWithValue(realRepo),
        ],
      );
      final notifier = realContainer.read(filterViewModelProvider.notifier);
      notifier.setImage(testPath);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      notifier.setCropRatio(CropRatio.ratio_1_1);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      realWriter.lastSavedBytes = null;
      await notifier.saveProcessedImage();
      final savedBytes = realWriter.lastSavedBytes;

      expect(savedBytes, isNotNull);
      final out = img.decodeImage(savedBytes!)!;
      expect(out.width, 3000, reason: '1:1 应输出 3000x3000 不拉伸');
      expect(out.height, 3000);

      realContainer.dispose();
      File(testPath).deleteSync();
    });
  });

  group('FilterViewModel 人脸检测 + mask', () {
    test('setImage 后 _runProcess 调 detect 1 次 + buildMask 1 次', () async {
      final tempFile = await File('${Directory.systemTemp.path}/face_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

      final detector = _StubFaceDetector(cannedResult: [
        FaceContours(face: const [Offset(10, 10), Offset(50, 10), Offset(30, 50)]),
      ]);
      final builder = _StubMaskBuilder(cannedMask: img.Image(width: 100, height: 100, numChannels: 1));
      final c = ProviderContainer(
        overrides: [
          imageProcessingServiceProvider.overrideWithValue(_CapturingProcessingService()),
          photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
          appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
          faceDetectionServiceProvider.overrideWithValue(detector),
          faceMaskBuilderProvider.overrideWithValue(builder),
        ],
      );

      c.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(detector.detectCallCount, 1, reason: 'setImage 立即 detect 一次');
      expect(builder.buildCallCount, 1, reason: 'buildMask 在 detect 成功后被调');
      expect(c.read(filterViewModelProvider).faceCount, 1, reason: 'state.faceCount=1');

      c.dispose();
      await tempFile.delete();
    });

    test('detect 返回空 → faceCount=0, buildMask 不被调', () async {
      final tempFile = await File('${Directory.systemTemp.path}/noface_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

      final detector = _StubFaceDetector(cannedResult: const []);
      final builder = _StubMaskBuilder();
      final c = ProviderContainer(
        overrides: [
          imageProcessingServiceProvider.overrideWithValue(_CapturingProcessingService()),
          photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
          appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
          faceDetectionServiceProvider.overrideWithValue(detector),
          faceMaskBuilderProvider.overrideWithValue(builder),
        ],
      );

      c.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = c.read(filterViewModelProvider);
      expect(state.faceCount, 0);
      expect(builder.buildCallCount, 0, reason: '无脸时不应调 buildMask');

      c.dispose();
      await tempFile.delete();
    });

    test('缓存命中：连续调 setSmooth 不重新 detect', () async {
      final tempFile = await File('${Directory.systemTemp.path}/cached_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

      final detector = _StubFaceDetector(cannedResult: [
        FaceContours(face: const [Offset(10, 10), Offset(50, 10), Offset(30, 50)]),
      ]);
      final builder = _StubMaskBuilder(cannedMask: img.Image(width: 100, height: 100, numChannels: 1));
      final c = ProviderContainer(
        overrides: [
          imageProcessingServiceProvider.overrideWithValue(_CapturingProcessingService()),
          photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
          appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
          faceDetectionServiceProvider.overrideWithValue(detector),
          faceMaskBuilderProvider.overrideWithValue(builder),
        ],
      );

      final notifier = c.read(filterViewModelProvider.notifier);
      notifier.setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final initialDetect = detector.detectCallCount;
      final initialBuild = builder.buildCallCount;

      // 改 smooth 滑杆（200ms debounce）→ 应当复用 detect 缓存，但 buildMask 仍跑
      notifier.setSmooth(50);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(detector.detectCallCount, initialDetect, reason: '改 smooth 不重新 detect');
      expect(builder.buildCallCount, initialBuild + 1,
          reason: '改 smooth 后 buildMask 仍跑一次（_runProcess 触发）');

      c.dispose();
      await tempFile.delete();
    });

    test('setImage 切到新 path → 缓存被清空，detect 重跑', () async {
      final tempFile1 = await File('${Directory.systemTemp.path}/a_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
      final tempFile2 = await File('${Directory.systemTemp.path}/b_${DateTime.now().microsecondsSinceEpoch}.jpg').create();
      await tempFile1.writeAsBytes([0xFF, 0xD8, 0xFF]);
      await tempFile2.writeAsBytes([0xFF, 0xD8, 0xFF]);

      final detector = _StubFaceDetector(cannedResult: const []);
      final c = ProviderContainer(
        overrides: [
          imageProcessingServiceProvider.overrideWithValue(_CapturingProcessingService()),
          photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
          appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
          faceDetectionServiceProvider.overrideWithValue(detector),
          faceMaskBuilderProvider.overrideWithValue(_StubMaskBuilder()),
        ],
      );
      final notifier = c.read(filterViewModelProvider.notifier);

      notifier.setImage(tempFile1.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(detector.detectCallCount, 1);

      notifier.setImage(tempFile2.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(detector.detectCallCount, 2, reason: '切到新照片应 detect 第二次');

      c.dispose();
      await tempFile1.delete();
      await tempFile2.delete();
    });
  });
}