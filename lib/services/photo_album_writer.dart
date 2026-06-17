import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

/// 把图片字节写入系统相册的抽象接口
///
/// 设计目的：
/// - 业务层（FilterViewModel）只依赖此接口，便于单元测试 mock
/// - 真实实现用 [PhotoAlbumWriterImpl]（包装 `PhotoManager.editor.saveImage`）
abstract class PhotoAlbumWriter {
  Future<void> saveImage(Uint8List bytes, {required String filename});
}

/// Riverpod provider —— 注入到 FilterViewModel
final photoAlbumWriterProvider = Provider<PhotoAlbumWriter>((ref) {
  return PhotoAlbumWriterImpl();
});

/// 真实实现：调 [PhotoManager.editor.saveImage]
class PhotoAlbumWriterImpl implements PhotoAlbumWriter {
  @override
  Future<void> saveImage(Uint8List bytes, {required String filename}) async {
    await PhotoManager.editor.saveImage(bytes, filename: filename);
  }
}
