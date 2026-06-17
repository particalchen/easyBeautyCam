import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

/// 相册仓库接口 —— 抽象 photo_manager API，便于测试 mock
abstract class PhotoAlbumRepository {
  /// 请求相册读取权限
  Future<bool> requestPermission();

  /// 取最近 100 张图片
  Future<List<String>> loadRecentPhotoPaths({int limit = 100});
}

/// 默认实现：走 photo_manager 平台 channel
class PhotoAlbumRepositoryImpl implements PhotoAlbumRepository {
  @override
  Future<bool> requestPermission() async {
    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
    return permission.isAuth;
  }

  @override
  Future<List<String>> loadRecentPhotoPaths({int limit = 100}) async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return const [];
    final recent = albums.first;
    final count = await recent.assetCountAsync;
    final end = count < limit ? count : limit;
    final assets = await recent.getAssetListRange(start: 0, end: end);
    final paths = <String>[];
    for (final asset in assets) {
      final file = await asset.file;
      if (file != null) paths.add(file.path);
    }
    return paths;
  }
}

/// Riverpod provider
final photoAlbumRepositoryProvider = Provider<PhotoAlbumRepository>((ref) {
  return PhotoAlbumRepositoryImpl();
});
