import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;

import 'face_detection_service.dart';

/// 人脸轮廓 → 1-channel mask image
///
/// 像素值 ∈ [0, 255]，0 = 不处理（背景 / 眼唇），255 = 完全处理（人脸）
/// 边缘 [featherRadius] 控制羽化程度（高斯模糊）以避免硬接缝
class FaceMaskBuilder {
  /// [width] / [height] = 原图尺寸
  /// [faces] = FaceDetectionService.detect 返回的轮廓
  /// [featherRadius] = 边缘羽化半径（0 = 硬边；8 适合 4K 图）
  /// [excludeEyesLips] = 是否把眼/唇区域从 mask 中挖空（保留细节）
  img.Image buildMask({
    required int width,
    required int height,
    required List<FaceContours> faces,
    int featherRadius = 8,
    bool excludeEyesLips = true,
  }) {
    // 1) 全 0 mask（1-channel grayscale）
    final mask = img.Image(width: width, height: height, numChannels: 1);
    img.fill(mask, color: img.ColorRgb8(0, 0, 0));

    if (faces.isEmpty) return mask;

    // 2) 每个人脸 fillPolygon → 255
    final white = img.ColorRgb8(255, 255, 255);
    for (final f in faces) {
      if (f.face.length < 3) continue;
      img.fillPolygon(
        mask,
        vertices: f.face.map((o) => img.Point(o.dx, o.dy)).toList(),
        color: white,
      );

      // 3) 排除眼/唇：fillPolygon → 0
      if (excludeEyesLips) {
        final black = img.ColorRgb8(0, 0, 0);
        for (final pts in [f.leftEye, f.rightEye, f.lipUpper, f.lipLower]) {
          if (pts == null || pts.length < 3) continue;
          img.fillPolygon(
            mask,
            vertices: pts.map((o) => img.Point(o.dx, o.dy)).toList(),
            color: black,
          );
        }
      }
    }

    // 4) 边缘羽化：高斯模糊 mask（mask 自身就是 1-channel）
    if (featherRadius > 0) {
      return img.gaussianBlur(mask, radius: featherRadius);
    }
    return mask;
  }
}