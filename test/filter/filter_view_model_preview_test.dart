import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

/// 测试专用：记录每次 processImage 调用 + 返回不同 bytes（用于断言"参数传对"）
class _CapturingProcessingService extends ImageProcessingService {
  int callCount = 0;
  int applyTransformCallCount = 0;
  double? lastScale;
  Offset? lastTranslation;
  double? lastTargetRatio;
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
  }) async {
    callCount++;
    // 复用基础 PNG 字节 + 在尾部追加计数器字节，让每个 call 返回值仍然合法 PNG 头
    _bytes = Uint8List.fromList([..._basePng, callCount & 0xff]);
    return _bytes;
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
  @override
  Future<void> saveImage(Uint8List bytes, {required String filename}) async {}
}

class _NoopRepo implements AppPhotoRepository {
  @override
  Future<List<String>> listAll() async => const [];
  @override
  Future<String> add(Uint8List bytes) async => '/noop';
  @override
  Future<void> delete(List<String> paths) async {}
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
      expect(svc.callCount, greaterThanOrEqualTo(1));
    });

    test('selectFilter 触发新一次 processImage', () async {
      container.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.callCount;

      container
          .read(filterViewModelProvider.notifier)
          .selectFilter(FilterType.gangfeng);
      // 200ms debounce 后才执行
      await Future<void>.delayed(const Duration(milliseconds: 280));

      expect(svc.callCount, greaterThan(c1));
    });

    test('saveProcessedImage 优先复用 previewBytes，不再 process', () async {
      container.read(filterViewModelProvider.notifier).setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.callCount;

      await container
          .read(filterViewModelProvider.notifier)
          .saveProcessedImage();

      // 不再调一次 process
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
      final c1 = svc.callCount;

      container.read(filterViewModelProvider.notifier).setTransform(
            scale: 2.0,
            translation: const Offset(10, 20),
          );
      await Future<void>.delayed(const Duration(milliseconds: 280));

      final state = container.read(filterViewModelProvider);
      expect(state.scale, 2.0);
      expect(state.translation, const Offset(10, 20));
      expect(svc.callCount, greaterThan(c1), reason: 'setTransform 应触发重新处理');
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

    test('setTransform 触发 applyTransform 调用', () async {
      final notifier = container.read(filterViewModelProvider.notifier);
      notifier.setCropRatio(CropRatio.ratio_1_1);
      notifier.setImage(tempFile.path);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c1 = svc.applyTransformCallCount;

      notifier.setTransform(scale: 2.0, translation: const Offset(0.1, 0.2));
      await Future<void>.delayed(const Duration(milliseconds: 280));

      expect(svc.applyTransformCallCount, greaterThan(c1));
      expect(svc.lastScale, 2.0);
      expect(svc.lastTranslation, const Offset(0.1, 0.2));
    });
  });
}