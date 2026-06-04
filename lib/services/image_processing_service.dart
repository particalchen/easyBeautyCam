import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum FilterType { original, coral, gangfeng, rixi, jiaopian }

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

    final colored = img.ColorFilter.mat(_filterMatrices[filter]!);
    final filtered = img.colorFilter(colored).convert(image);

    return Uint8List.fromList(img.encodePng(filtered));
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
    if (smooth > 0) {
      final blurred = img.gaussianBlur(result, radius: (smooth / 10).round());
      final blendFactor = smooth / 100;
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
    return result;
  }
}