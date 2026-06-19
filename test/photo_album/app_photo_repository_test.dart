import 'dart:typed_data';

import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryAppPhotoRepository', () {
    late InMemoryAppPhotoRepository repo;

    setUp(() {
      repo = InMemoryAppPhotoRepository();
    });

    test('初始 listAll 返回空', () async {
      expect(await repo.listAll(), isEmpty);
    });

    test('add 写入新照片，新照片排在最前', () async {
      await repo.add(Uint8List.fromList([1, 2, 3]));
      final p1 = await repo.add(Uint8List.fromList([4, 5, 6]));

      final all = await repo.listAll();
      expect(all.first, p1);
      expect(all.length, 2);
    });

    test('delete 移除指定路径', () async {
      final p1 = await repo.add(Uint8List.fromList([1]));
      final p2 = await repo.add(Uint8List.fromList([2]));
      final p3 = await repo.add(Uint8List.fromList([3]));

      await repo.delete([p1, p3]);

      final all = await repo.listAll();
      expect(all, [p2]);
    });

    test('delete 空列表不报错', () async {
      await repo.delete(const []);
      expect(await repo.listAll(), isEmpty);
    });
  });
}