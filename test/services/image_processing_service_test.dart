import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:easy_beauty_cam/services/image_processing_service.dart';

/// 把全黑图像（rgb 30）跑完 processImage 后，平均亮度应该被自动补偿上来
///
/// 回归：2026-06-20 真机报「拍摄的照片特别暗」—— 环境光充足情况下，相机包
/// 预览/拍照曝光可能不一致，导致照片整体偏暗；要求 image_processing_service
/// 在 processImage 末尾对偏暗图自动做亮度补偿。
void main() {
  group('ImageProcessingService.normalizeBrightness', () {
    test('偏暗图（mean≈30）经 processImage 后 mean 亮度应被提升到 ≥ 90', () async {
      // 1) 造一张 20x20 全 rgb(30) 的"偏暗"图像
      final dark = img.Image(width: 20, height: 20);
      img.fill(dark, color: img.ColorRgb8(30, 30, 30));
      final darkBytes = Uint8List.fromList(img.encodePng(dark));

      // 2) 跑 processImage（filter=original 不改色, smooth/whiten=0 不动）
      final svc = ImageProcessingService();
      final out = await svc.processImage(darkBytes);

      // 3) 解码输出，断言平均亮度 ≥ 90
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull, reason: 'processImage 输出必须是可解码图');

      final meanLuma = _meanLuminance(outImage!);
      expect(
        meanLuma,
        greaterThanOrEqualTo(90),
        reason: '偏暗图应被自动补偿到 mean≥90，实际 mean=$meanLuma',
      );
    });

    test('本来就亮的图（mean≈200）不会被过度提亮', () async {
      // 1) 造一张 20x20 全 rgb(200) 的"已经够亮"图像
      final bright = img.Image(width: 20, height: 20);
      img.fill(bright, color: img.ColorRgb8(200, 200, 200));
      final brightBytes = Uint8List.fromList(img.encodePng(bright));

      // 2) 跑 processImage
      final svc = ImageProcessingService();
      final out = await svc.processImage(brightBytes);

      // 3) 解码输出：mean 不应被无脑拉到 255，应该跟原来差距不大（±20）
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);

      final meanLuma = _meanLuminance(outImage!);
      expect(
        meanLuma,
        lessThanOrEqualTo(220),
        reason: '亮图不应被过度提亮到接近 255，实际 mean=$meanLuma',
      );
      expect(
        meanLuma,
        greaterThanOrEqualTo(180),
        reason: '亮图不应被压暗，实际 mean=$meanLuma',
      );
    });
  });

  group('ImageProcessingService.crop - 中心裁切到指定宽高比', () {
    test('1:1 裁切 400x200 图，输出应为 200x200', () async {
      // 横向 2:1 的图，中心裁成 1:1
      final src = img.Image(width: 400, height: 200);
      img.fill(src, color: img.ColorRgb8(100, 100, 100));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.crop(srcBytes, CropRatio.ratio_1_1);
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 200, reason: '1:1 裁切后宽度');
      expect(outImage.height, 200, reason: '1:1 裁切后高度');
    });

    test('16:9 裁切 200x400 竖图，输出应为 200x113（去掉上下）', () async {
      // 竖向 1:2 的图，中心裁成 16:9 (宽 > 高)
      final src = img.Image(width: 200, height: 400);
      img.fill(src, color: img.ColorRgb8(80, 80, 80));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.crop(srcBytes, CropRatio.ratio_16_9);
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      // 16:9 比例 = 1.7778；200 / 1.7778 = 112.5 → round 113
      expect(outImage!.width, 200, reason: '16:9 裁切后宽度=原宽（因为图比目标更竖）');
      expect(outImage.height, 113, reason: '16:9 裁切后高度=round(width*9/16)');
    });

    test('9:16 裁切 400x200 横图，输出应为 113x200（去掉左右）', () async {
      final src = img.Image(width: 400, height: 200);
      img.fill(src, color: img.ColorRgb8(60, 60, 60));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.crop(srcBytes, CropRatio.ratio_9_16);
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      // 9:16 比例 = 0.5625；200 * 0.5625 = 112.5 → round 113
      expect(outImage!.width, 113, reason: '9:16 裁切后宽度=round(height*9/16)');
      expect(outImage.height, 200, reason: '9:16 裁切后高度=原高');
    });

    test('自由 (free) 不裁切，输出尺寸与原图一致', () async {
      final src = img.Image(width: 300, height: 200);
      img.fill(src, color: img.ColorRgb8(120, 120, 120));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.crop(srcBytes, CropRatio.free);
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 300);
      expect(outImage.height, 200);
    });
  });
}

/// Rec.709 亮度 (0..255)
double _meanLuminance(img.Image image) {
  double sum = 0;
  int n = 0;
  for (final p in image) {
    sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
    n++;
  }
  return sum / n;
}