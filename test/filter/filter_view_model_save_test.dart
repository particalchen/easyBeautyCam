import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

class _FakeProcessingService extends ImageProcessingService {
  final Uint8List _fakeBytes;
  _FakeProcessingService(this._fakeBytes);

  @override
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
    img.Image? mask,
  }) async {
    return _fakeBytes;
  }
}

class _FakePhotoAlbumWriter implements PhotoAlbumWriter {
  final List<({Uint8List bytes, String filename})> _calls = [];

  @override
  Future<void> saveImage(Uint8List bytes, {required String filename}) async {
    _calls.add((bytes: bytes, filename: filename));
  }

  int get callCount => _calls.length;
}

class _FakeAppPhotoRepo implements AppPhotoRepository {
  final List<String> _paths = [];

  @override
  Future<List<String>> listAll() async => List.unmodifiable(_paths);

  @override
  Future<String> add(Uint8List bytes) async {
    final p = '/fake/${DateTime.now().microsecondsSinceEpoch}.jpg';
    _paths.add(p);
    return p;
  }

  @override
  Future<void> delete(List<String> paths) async {
    _paths.removeWhere(paths.contains);
  }
}

void main() {
  group('FilterViewModel.saveProcessedImage', () {
    late Uint8List fakeBytes;
    late _FakePhotoAlbumWriter writer;
    late ProviderContainer container;
    late File tempFile;

    setUp(() async {
      fakeBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG magic
      writer = _FakePhotoAlbumWriter();
      // 创建真实临时文件供 _readImageBytes 读取
      tempFile = await File(
        '${Directory.systemTemp.path}/test_photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
      ).create();
      await tempFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic

      container = ProviderContainer(
        overrides: [
          imageProcessingServiceProvider.overrideWithValue(
            _FakeProcessingService(fakeBytes),
          ),
          photoAlbumWriterProvider.overrideWithValue(writer),
          appPhotoRepositoryProvider.overrideWithValue(_FakeAppPhotoRepo()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      if (await tempFile.exists()) await tempFile.delete();
    });

    test('写真册接口被调用一次，bytes 与 filter 处理结果一致', () async {
      container
          .read(filterViewModelProvider.notifier)
          .setImage(tempFile.path);

      await container
          .read(filterViewModelProvider.notifier)
          .saveProcessedImage();

      expect(writer.callCount, 1);
      expect(writer._calls.first.bytes, fakeBytes);
    });

    test('filename 包含 .png 后缀', () async {
      container
          .read(filterViewModelProvider.notifier)
          .setImage(tempFile.path);

      await container
          .read(filterViewModelProvider.notifier)
          .saveProcessedImage();

      expect(writer._calls.first.filename, endsWith('.png'));
    });

    test('无 imagePath 时不调用写真册，直接返回 null', () async {
      final result = await container
          .read(filterViewModelProvider.notifier)
          .saveProcessedImage();

      expect(result, isNull);
      expect(writer.callCount, 0);
    });

    test('处理中 isProcessing 变 true，处理完变 false', () async {
      container
          .read(filterViewModelProvider.notifier)
          .setImage(tempFile.path);

      final future = container
          .read(filterViewModelProvider.notifier)
          .saveProcessedImage();

      expect(
        container.read(filterViewModelProvider).isProcessing,
        isTrue,
        reason: 'saveProcessedImage 启动后 isProcessing 应为 true',
      );

      await future;
      expect(
        container.read(filterViewModelProvider).isProcessing,
        isFalse,
        reason: '处理完成后 isProcessing 应回到 false',
      );
    });
  });
}
