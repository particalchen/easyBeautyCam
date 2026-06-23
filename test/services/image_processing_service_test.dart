import 'dart:typed_data';
import 'dart:ui' show Offset;

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

    test('原图 (original) 不裁切，输出尺寸与原图一致', () async {
      final src = img.Image(width: 300, height: 200);
      img.fill(src, color: img.ColorRgb8(120, 120, 120));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.crop(srcBytes, CropRatio.original);
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 300);
      expect(outImage.height, 200);
    });
  });

  group('ImageProcessingService.applyTransform - zoom + pan', () {
    test('scale=1.0, translation=zero, target=原尺寸：输出=原图', () async {
      final src = img.Image(width: 400, height: 300);
      img.fill(src, color: img.ColorRgb8(120, 120, 120));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyTransform(
        srcBytes,
        scale: 1.0,
        translation: Offset.zero,
        targetRatio: 4 / 3,
      );
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 400);
      expect(outImage.height, 300);
    });

    test('scale=2.0：visible area 是原图中心 1/2', () async {
      final src = img.Image(width: 400, height: 300);
      img.fill(src, color: img.ColorRgb8(80, 80, 80));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyTransform(
        srcBytes,
        scale: 2.0,
        translation: Offset.zero,
        targetRatio: 4 / 3,
      );
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 200);
      expect(outImage.height, 150);
      final centerPixel = outImage.getPixel(100, 75);
      expect(centerPixel.r, 80);
    });

    test('translation 平移可见窗口', () async {
      final src = img.Image(width: 400, height: 300);
      img.fill(src, color: img.ColorRgb8(50, 50, 50));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyTransform(
        srcBytes,
        scale: 1.0,
        translation: const Offset(0.1, 0),
        targetRatio: 4 / 3,
      );
      expect(out, isNotEmpty);
    });

    test('越界 translation 自动 clamp 到图像边界', () async {
      final src = img.Image(width: 200, height: 200);
      img.fill(src, color: img.ColorRgb8(100, 100, 100));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyTransform(
        srcBytes,
        scale: 2.0,
        translation: const Offset(1.0, 1.0),
        targetRatio: 1.0,
      );
      final outImage = img.decodeImage(out);
      expect(outImage, isNotNull);
      expect(outImage!.width, 100);
    });
  });

  group('ImageProcessingService.applyTransform - 按比例裁切（不拉伸）', () {
    test('applyTransform 1:1 比例从 4:3 原图裁出 3000x3000 不拉伸', () async {
      final src = img.Image(width: 4000, height: 3000);
      img.fill(src, color: img.ColorRgb8(255, 0, 0));
      final bytes = Uint8List.fromList(img.encodePng(src));

      final service = ImageProcessingService();
      final out = await service.applyTransform(
        bytes,
        scale: 1.0,
        translation: Offset.zero,
        targetRatio: 1.0,
      );

      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 3000);
      expect(decoded.height, 3000);
    });

    test('applyTransform 16:9 比例从 4:3 原图裁出 4000x2249 不拉伸', () async {
      final src = img.Image(width: 4000, height: 3000);
      img.fill(src, color: img.ColorRgb8(0, 255, 0));
      final bytes = Uint8List.fromList(img.encodePng(src));

      final service = ImageProcessingService();
      final out = await service.applyTransform(
        bytes,
        scale: 1.0,
        translation: Offset.zero,
        targetRatio: 16 / 9,
      );

      final decoded = img.decodeImage(out)!;
      // 16:9 ≈ 1.778，src ratio=4/3≈1.333（更窄），按目标更宽 → 裁上下：保留全宽，newH = 4000 / (16/9) = 2250
      expect(decoded.width, 4000);
      expect(decoded.height, 2250);
    });

    test('applyTransform 原比例 4:3 + 目标比例 4:3 输出原尺寸', () async {
      final src = img.Image(width: 4000, height: 3000);
      img.fill(src, color: img.ColorRgb8(0, 0, 255));
      final bytes = Uint8List.fromList(img.encodePng(src));

      final service = ImageProcessingService();
      final out = await service.applyTransform(
        bytes,
        scale: 1.0,
        translation: Offset.zero,
        targetRatio: 4 / 3,
      );

      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 4000);
      expect(decoded.height, 3000);
    });

    test('applyTransform 自由比例 (targetRatio=null) 输出按 scale 决定的可见区域', () async {
      final src = img.Image(width: 4000, height: 3000);
      img.fill(src, color: img.ColorRgb8(255, 255, 0));
      final bytes = Uint8List.fromList(img.encodePng(src));

      final service = ImageProcessingService();
      final out = await service.applyTransform(
        bytes,
        scale: 2.0,
        translation: Offset.zero,
        targetRatio: null,
      );

      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 2000);
      expect(decoded.height, 1500);
    });

    test('applyTransform scale=0.7 拉远时不报错', () async {
      final src = img.Image(width: 4000, height: 3000);
      img.fill(src, color: img.ColorRgb8(0, 255, 255));
      final bytes = Uint8List.fromList(img.encodePng(src));

      final service = ImageProcessingService();
      final out = await service.applyTransform(
        bytes,
        scale: 0.7,
        translation: Offset.zero,
        targetRatio: 1.0,
      );

      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 3000);
      expect(decoded.height, 3000);
    });
  });

  group('CropRatio.original 重命名', () {
    test('CropRatio.original.ratio 返回 null（语义：不约束比例）', () {
      expect(CropRatio.original.ratio, isNull);
    });

    test('CropRatio.original.label 返回 "原图"', () {
      expect(CropRatio.original.label, '原图');
    });
  });

  group('ImageProcessingService.applyBeauty - mask 行为', () {
    test('mask=null：直接返回原图，不做任何处理', () async {
      // 1) 造一张 20x20 中心 rgb(100)，跑 applyBeauty(smooth=50, whiten=50, mask=null)
      final src = img.Image(width: 20, height: 20);
      img.fill(src, color: img.ColorRgb8(100, 100, 100));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final svc = ImageProcessingService();
      final out = await svc.applyBeauty(
        srcBytes, smooth: 50, whiten: 50, slim: 0, mask: null,
      );

      // 2) 解码输出：所有像素应 == 原图
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      final center = decoded!.getPixel(10, 10);
      expect(center.r, 100, reason: 'mask=null 时原图不被修改');
      expect(center.g, 100);
      expect(center.b, 100);
    });

    test('mask=allZero (全黑 mask)：原图不被修改', () async {
      final src = img.Image(width: 20, height: 20);
      img.fill(src, color: img.ColorRgb8(100, 100, 100));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      // 1-channel 全 0 mask
      final mask = img.Image(width: 20, height: 20, numChannels: 1);
      img.fill(mask, color: img.ColorRgb8(0, 0, 0));

      final svc = ImageProcessingService();
      final out = await svc.applyBeauty(
        srcBytes, smooth: 50, whiten: 50, slim: 0, mask: mask,
      );

      final decoded = img.decodeImage(out)!;
      expect(decoded.getPixel(10, 10).r, 100, reason: 'mask=0 时像素不被处理');
    });

    test('mask=fullWhite (全白 mask)：像素被磨皮', () async {
      final src = img.Image(width: 20, height: 20);
      img.fill(src, color: img.ColorRgb8(100, 100, 100));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      // 1-channel 全 255 mask
      final mask = img.Image(width: 20, height: 20, numChannels: 1);
      img.fill(mask, color: img.ColorRgb8(255, 255, 255));

      final svc = ImageProcessingService();
      final out = await svc.applyBeauty(
        srcBytes, smooth: 50, whiten: 0, slim: 0, mask: mask,
      );

      // 平滑后每个像素应 ≈ 100（前后色相同 → blend 后还是 100）
      final decoded = img.decodeImage(out)!;
      final p = decoded.getPixel(10, 10);
      expect(p.r, closeTo(100, 2));
    });

    test('mask=half (128 灰度)：边缘羽化 (whiten 提亮按 mask 灰度衰减)', () async {
      // 左半边 0 mask，右半边 255 mask
      final src = img.Image(width: 20, height: 20);
      img.fill(src, color: img.ColorRgb8(100, 100, 100));
      final srcBytes = Uint8List.fromList(img.encodePng(src));

      final mask = img.Image(width: 20, height: 20, numChannels: 1);
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 20; x++) {
          mask.setPixel(x, y, x < 10
              ? img.ColorRgb8(0, 0, 0)
              : img.ColorRgb8(255, 255, 255));
        }
      }

      final svc = ImageProcessingService();
      final out = await svc.applyBeauty(
        srcBytes, smooth: 0, whiten: 50, slim: 0, mask: mask,
      );

      final decoded = img.decodeImage(out)!;
      // 左半边：whiten=0 → RGB 不变
      expect(decoded.getPixel(5, 10).r, 100, reason: 'mask=0 区域不应被提亮');
      // 右半边：whiten=50 → 100 + (50/100*30) = 115
      expect(decoded.getPixel(15, 10).r, 115, reason: 'mask=255 区域应被提亮');
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