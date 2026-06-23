import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:easy_beauty_cam/services/face_detection_service.dart';
import 'package:easy_beauty_cam/services/face_mask_builder.dart';

void main() {
  group('FaceMaskBuilder', () {
    test('1 张脸覆盖图像中心区域：人脸像素 > 128，背景 = 0', () {
      // 造一个 100x100 中心脸（face 轮廓 = 中心 50x50 矩形点集）
      final facePts = <Offset>[
        for (var x = 25; x <= 75; x++) Offset(x.toDouble(), 25),
        for (var y = 26; y <= 75; y++) Offset(75, y.toDouble()),
        for (var x = 74; x >= 25; x--) Offset(x.toDouble(), 75),
        for (var y = 74; y >= 26; y--) Offset(25, y.toDouble()),
      ];
      final builder = FaceMaskBuilder();
      final mask = builder.buildMask(
        width: 100,
        height: 100,
        faces: [FaceContours(face: facePts)],
        featherRadius: 0, // 0 羽化 = 硬边，方便测断言
        excludeEyesLips: false,
      );

      // 中心像素应 > 128
      final center = mask.getPixel(50, 50);
      expect(center.r, greaterThan(128),
          reason: '人脸中心区域应高亮，实际=${center.r}');
      // 角落像素 = 0
      final corner = mask.getPixel(0, 0);
      expect(corner.r, 0, reason: '背景角落应=0，实际=${corner.r}');
    });

    test('嘴唇区域被排除（mask 值 < 50）', () {
      // 整脸 = 50x50 中心矩形；嘴唇 = 中心 30x10 矩形（用来测试 lip exclusion）
      final facePts = <Offset>[
        for (var x = 25; x <= 75; x++) Offset(x.toDouble(), 25),
        for (var y = 26; y <= 75; y++) Offset(75, y.toDouble()),
        for (var x = 74; x >= 25; x--) Offset(x.toDouble(), 75),
        for (var y = 74; y >= 26; y--) Offset(25, y.toDouble()),
      ];
      final lipPts = <Offset>[
        for (var x = 35; x <= 65; x++) Offset(x.toDouble(), 55),
        for (var y = 56; y <= 65; y++) Offset(65, y.toDouble()),
        for (var x = 64; x >= 35; x--) Offset(x.toDouble(), 65),
        for (var y = 64; y >= 56; y--) Offset(35, y.toDouble()),
      ];
      final builder = FaceMaskBuilder();
      final mask = builder.buildMask(
        width: 100,
        height: 100,
        faces: [
          FaceContours(face: facePts, lipLower: lipPts),
        ],
        featherRadius: 0,
        excludeEyesLips: true,
      );

      // 嘴中心 (50, 60) 应被排除 = 0
      final lipPixel = mask.getPixel(50, 60);
      expect(lipPixel.r, lessThan(50),
          reason: '嘴唇区域应被排除，实际=${lipPixel.r}');
      // 脸其他区域 (50, 30) 仍高亮
      final facePixel = mask.getPixel(50, 30);
      expect(facePixel.r, greaterThan(128),
          reason: '人脸非眼唇区域应高亮，实际=${facePixel.r}');
    });

    test('空 faces → 全 0 mask', () {
      final mask = FaceMaskBuilder().buildMask(
        width: 100, height: 100, faces: const [],
        featherRadius: 0,
      );
      final corner = mask.getPixel(0, 0);
      final center = mask.getPixel(50, 50);
      expect(corner.r, 0);
      expect(center.r, 0);
    });

    test('多张脸：所有脸都覆盖', () {
      List<Offset> rect4(int x0, int y0, int x1, int y1) => [
            Offset(x0.toDouble(), y0.toDouble()),
            Offset(x1.toDouble(), y0.toDouble()),
            Offset(x1.toDouble(), y1.toDouble()),
            Offset(x0.toDouble(), y1.toDouble()),
          ];
      final mask = FaceMaskBuilder().buildMask(
        width: 100,
        height: 100,
        faces: [
          FaceContours(face: rect4(10, 30, 30, 70)),
          FaceContours(face: rect4(70, 30, 90, 70)),
        ],
        featherRadius: 0,
        excludeEyesLips: false,
      );
      // 两张脸中心都高亮
      expect(mask.getPixel(20, 50).r, greaterThan(128));
      expect(mask.getPixel(80, 50).r, greaterThan(128));
      // 中间空隙低
      expect(mask.getPixel(50, 50).r, lessThan(50));
    });

    test('featherRadius=0 vs 8：feather 影响边缘渐变', () {
      final facePts = <Offset>[
        for (var x = 25; x <= 75; x++) Offset(x.toDouble(), 25),
        for (var y = 26; y <= 75; y++) Offset(75, y.toDouble()),
        for (var x = 74; x >= 25; x--) Offset(x.toDouble(), 75),
        for (var y = 74; y >= 26; y--) Offset(25, y.toDouble()),
      ];
      final maskSharp = FaceMaskBuilder().buildMask(
        width: 100, height: 100,
        faces: [FaceContours(face: facePts)],
        featherRadius: 0,
      );
      final maskFeather = FaceMaskBuilder().buildMask(
        width: 100, height: 100,
        faces: [FaceContours(face: facePts)],
        featherRadius: 8,
      );
      // 边缘内侧 (25, 50)：sharp=255（边界上），feather 应被平滑掉一部分
      final edgeSharp = maskSharp.getPixel(25, 50).r;
      final edgeFeather = maskFeather.getPixel(25, 50).r;
      expect(edgeFeather, lessThan(edgeSharp),
          reason: 'feather 8pt 的边缘内侧值应 < sharp 0pt 的边缘内侧值');
    });
  });
}