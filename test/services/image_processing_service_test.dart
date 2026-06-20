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