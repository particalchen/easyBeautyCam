import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;

enum FilterType { original, coral, gangfeng, rixi, jiaopian }

/// 照片裁切比例 —— 编辑面板「裁切」tab 候选
///
/// - free  = 不裁切（保留原比例）
/// - 16_9  = 横屏宽幅
/// - 4_3   = 经典相机比例
/// - 1_1   = 方形（社交头像常用）
/// - 3_4   = 人像常用
/// - 9_16  = 竖屏全屏
enum CropRatio { free, ratio_16_9, ratio_4_3, ratio_1_1, ratio_3_4, ratio_9_16 }

extension CropRatioX on CropRatio {
  /// 比例值 (width / height)；free 返回 null 表示不约束
  double? get ratio {
    switch (this) {
      case CropRatio.free:
        return null;
      case CropRatio.ratio_16_9:
        return 16 / 9;
      case CropRatio.ratio_4_3:
        return 4 / 3;
      case CropRatio.ratio_1_1:
        return 1.0;
      case CropRatio.ratio_3_4:
        return 3 / 4;
      case CropRatio.ratio_9_16:
        return 9 / 16;
    }
  }

  /// UI 显示文本
  String get label {
    switch (this) {
      case CropRatio.free:
        return '自由';
      case CropRatio.ratio_16_9:
        return '16:9';
      case CropRatio.ratio_4_3:
        return '4:3';
      case CropRatio.ratio_1_1:
        return '1:1';
      case CropRatio.ratio_3_4:
        return '3:4';
      case CropRatio.ratio_9_16:
        return '9:16';
    }
  }
}

class ImageProcessingService {
  static const Map<FilterType, List<double>> _filterMatrices = {
    FilterType.original: [],
    FilterType.coral: [
      1.1, 0, 0, 0, 10,
      0, 1.05, 0, 0, 8,
      0, 0, 0.95, 0, 5,
      0, 0, 0, 1, 0,
    ],
    FilterType.gangfeng: [
      1.2, 0, 0, 0, -10,
      0, 1.1, 0, 0, -5,
      0, 0, 0.9, 0, 10,
      0, 0, 0, 1, 0,
    ],
    FilterType.rixi: [
      1.05, 0, 0, 0, 15,
      0, 1.05, 0, 0, 15,
      0, 0, 1.1, 0, 5,
      0, 0, 0, 1, 0,
    ],
    FilterType.jiaopian: [
      0.9, 0.1, 0.1, 0, 5,
      0.1, 0.85, 0.1, 0, 5,
      0.1, 0.1, 0.9, 0, 10,
      0, 0, 0, 1, 0,
    ],
  };

  Future<Uint8List> applyFilter(Uint8List imageBytes, FilterType filter) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final matrix = _filterMatrices[filter];
    if (matrix == null || matrix.isEmpty) return imageBytes;

    // Apply color matrix manually:5x4 matrix (RGBA)
    // m[0-4]=r, m[5-9]=g, m[10-14]=b, m[15-19]=a, m[20]=offset
    var result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final a = p.a.toDouble();

        final nr = (matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[3] * a + matrix[4]).clamp(0, 255).toInt();
        final ng = (matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[8] * a + matrix[9]).clamp(0, 255).toInt();
        final nb = (matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[13] * a + matrix[14]).clamp(0, 255).toInt();
        final na = (matrix[15] * r + matrix[16] * g + matrix[17] * b + matrix[18] * a + matrix[19]).clamp(0, 255).toInt();

        result.setPixelRgba(x, y, nr, ng, nb, na);
      }
    }

    return Uint8List.fromList(img.encodePng(result));
  }

  Future<Uint8List> applyBeauty(
    Uint8List imageBytes, {
    double smooth = 30,
    double whiten = 20,
    double slim = 0,
  }) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    var result = image;

    // Smooth (Gaussian blur + blend)
    // radius 保持极小（≤2），blendFactor 也很低（≤0.20），避免"模糊糊脸"感
    if (smooth > 0) {
      final radius = (smooth / 30).round().clamp(1, 2);
      final blurred = img.gaussianBlur(result, radius: radius);
      final blendFactor = smooth / 500; // 30 → 0.06, 100 → 0.20
      result = img.Image(width: result.width, height: result.height);
      for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
          final orig = result.getPixel(x, y);
          final blur = blurred.getPixel(x, y);
          result.setPixelRgba(
            x, y,
            ((orig.r * (1 - blendFactor) + blur.r * blendFactor)).round(),
            ((orig.g * (1 - blendFactor) + blur.g * blendFactor)).round(),
            ((orig.b * (1 - blendFactor) + blur.b * blendFactor)).round(),
            orig.a.toInt(),
          );
        }
      }
    }

    // Whiten (brightness adjustment)
    if (whiten > 0) {
      final adjust = (whiten / 100 * 30).round();
      for (int y = 0; y < result.height; y++) {
        for (int x = 0; x < result.width; x++) {
          final p = result.getPixel(x, y);
          result.setPixelRgba(
            x, y,
            (p.r + adjust).clamp(0, 255),
            (p.g + adjust).clamp(0, 255),
            (p.b + adjust).clamp(0, 255),
            p.a.toInt(),
          );
        }
      }
    }

    return Uint8List.fromList(img.encodePng(result));
  }

  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
  }) async {
    var result = imageBytes;
    result = await applyFilter(result, filter);
    result = await applyBeauty(
      result,
      smooth: smooth,
      whiten: whiten,
      slim: slim,
    );
    // 自动亮度补偿：兜底「相机预览/拍照曝光不一致」导致的偏暗照片
    // 仅当 mean luma < 75 时提升，亮图不被动
    result = await normalizeBrightness(result);
    return result;
  }

  /// 自动亮度补偿：当图像整体偏暗时，把 RGB 通道统一往上抬到接近目标亮度。
  ///
  /// 算法：
  /// - 计算 Rec.709 mean luma
  /// - mean < 75 时，按 (110 - mean) * 0.85 加到 RGB；否则原样返回
  /// - 用 clamp(0,255) 防止过曝
  ///
  /// 阈值与目标值的取舍：
  /// - threshold=75 避免给本来就够亮的图加曝光
  /// - target=110 + factor=0.85 让偏暗图（mean≈30）被提到 ≈98
  Future<Uint8List> normalizeBrightness(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    double sum = 0;
    int n = 0;
    for (final p in image) {
      sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
      n++;
    }
    final mean = sum / n;

    const threshold = 75.0;
    const target = 110.0;
    if (mean >= threshold) return imageBytes;

    final boost = ((target - mean) * 0.85).round();
    if (boost <= 0) return imageBytes;

    var result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        result.setPixelRgba(
          x, y,
          (p.r + boost).clamp(0, 255),
          (p.g + boost).clamp(0, 255),
          (p.b + boost).clamp(0, 255),
          p.a.toInt(),
        );
      }
    }
    return Uint8List.fromList(img.encodePng(result));
  }

  /// 按指定比例中心裁切图像
  ///
  /// - ratio == null（CropRatio.free）→ 原样返回
  /// - 图比目标更宽（imageW/H > targetRatio）→ 裁左右，保留上下
  /// - 图比目标更窄（imageW/H < targetRatio）→ 裁上下，保留左右
  /// - 等比 → 不动
  Future<Uint8List> crop(Uint8List imageBytes, CropRatio ratio) async {
    final target = ratio.ratio;
    if (target == null) return imageBytes;
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final w = image.width;
    final h = image.height;
    final currentRatio = w / h;

    int newW;
    int newH;
    if ((currentRatio - target).abs() < 0.001) {
      // 等比，不动
      return imageBytes;
    } else if (currentRatio > target) {
      // 图更宽 → 裁左右
      newH = h;
      newW = (h * target).round();
    } else {
      // 图更窄（更竖）→ 裁上下
      newW = w;
      newH = (w / target).round();
    }

    final x = (w - newW) ~/ 2;
    final y = (h - newH) ~/ 2;
    final cropped = img.copyCrop(image, x: x, y: y, width: newW, height: newH);
    return Uint8List.fromList(img.encodePng(cropped));
  }

  /// 按 scale + translation 提取源图可见区域，按目标比例二次裁切。
  ///
  /// 参数：
  /// - [scale] ∈ [0.5, 4.0]：1.0 = 全图可见；>1 放大（只显示中心区域）；<1 拉远（保留更多）
  /// - [translation] ∈ [-1, 1]：相对图像中心的归一化偏移
  /// - [targetRatio] == null（CropRatio.free）→ 输出按 scale/translation 决定的可见矩形，保持原图宽高比
  /// - [targetRatio] != null → 在可见矩形上按目标宽高比二次裁切，保持原图宽高比（**不拉伸**）
  Future<Uint8List> applyTransform(
    Uint8List imageBytes, {
    required double scale,
    required Offset translation,
    required double? targetRatio,
  }) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final srcW = image.width;
    final srcH = image.height;
    final s = scale.clamp(0.5, 4.0);

    // 1) 计算"可见区域"在源图中的矩形（按原图宽高比）。
    // scale<1 时 visible 可能 > src（拉远看全图），clamp 到 src 范围。
    var visibleW = (srcW / s).round().clamp(1, srcW);
    var visibleH = (srcH / s).round().clamp(1, srcH);

    // 2) translation 偏移中心
    final tx = translation.dx.clamp(-1.0, 1.0);
    final ty = translation.dy.clamp(-1.0, 1.0);
    var cx = (srcW / 2.0 - tx * srcW).round();
    var cy = (srcH / 2.0 - ty * srcH).round();

    // 3) clamp 到源图边界
    final halfW = visibleW ~/ 2;
    final halfH = visibleH ~/ 2;
    cx = cx.clamp(halfW, srcW - halfW);
    cy = cy.clamp(halfH, srcH - halfH);

    final x = cx - halfW;
    final y = cy - halfH;
    final visible = img.copyCrop(image, x: x, y: y, width: visibleW, height: visibleH);

    // 4) 没有目标比例 → 直接返回可见区域
    if (targetRatio == null) {
      return Uint8List.fromList(img.encodePng(visible));
    }

    // 5) 在可见区域上按目标比例二次裁切（保持原图宽高比，**不拉伸**）
    final vW = visible.width;
    final vH = visible.height;
    final currentRatio = vW / vH;

    int finalW;
    int finalH;
    if ((currentRatio - targetRatio).abs() < 0.001) {
      return Uint8List.fromList(img.encodePng(visible));
    } else if (currentRatio > targetRatio) {
      // visible 比目标宽 → 裁左右
      finalH = vH;
      finalW = (vH * targetRatio).round();
    } else {
      // visible 比目标窄（更竖）→ 裁上下
      finalW = vW;
      finalH = (vW / targetRatio).round();
    }

    final fx = (vW - finalW) ~/ 2;
    final fy = (vH - finalH) ~/ 2;
    final cropped = img.copyCrop(visible, x: fx, y: fy, width: finalW, height: finalH);
    return Uint8List.fromList(img.encodePng(cropped));
  }
}