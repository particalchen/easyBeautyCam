import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/pose_library/pose_model.dart';

void main() {
  group('PoseModel.referenceAssetPath', () {
    test('本地 pose：在 assetPath 扩展名前插入 -res', () {
      const pose = PoseModel(
        id: 'local_01',
        name: '户外姿势1',
        category: 'outdoor',
        assetPath: 'resources/poses/pose_outdoor_01.png',
        isLocal: true,
      );
      expect(pose.referenceAssetPath, 'resources/poses/pose_outdoor_01-res.png');
    });

    test('远程 pose：返回 null（远端没有约定 -res 后缀图）', () {
      final pose = PoseModel.fromJson({
        'id': 'remote_01',
        'name': '远端姿势',
        'category': 'outdoor',
        'asset_path': 'https://cdn.example.com/poses/foo.png',
        'remote_url': 'https://cdn.example.com/poses/foo.png',
      });
      expect(pose.referenceAssetPath, isNull);
    });

    test('本地无扩展名：返回 null（不破坏路径）', () {
      const pose = PoseModel(
        id: 'local_x',
        name: '测试',
        category: 'x',
        assetPath: 'no_extension_path',
        isLocal: true,
      );
      expect(pose.referenceAssetPath, isNull);
    });
  });
}
