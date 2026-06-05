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