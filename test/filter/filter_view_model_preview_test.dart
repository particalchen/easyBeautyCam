import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

/// 测试专用：记录每次 processImage 调用 + 返回不同 bytes（用于断言"参数传对"）
class _CapturingProcessingService extends ImageProcessingService {
  int callCount = 0;
  Uint8List _bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

  @override
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
  }) async {
    callCount++;
    _bytes = Uint8List.fromList([..._bytes, callCount & 0xff]);
    return _bytes;
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
  });
}