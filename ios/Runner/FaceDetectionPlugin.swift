import Flutter
import UIKit
import Vision
import ImageIO

public class FaceDetectionPlugin: NSObject, FlutterPlugin {
  private static let channelName = "easy_beauty_cam/face_detection"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = FaceDetectionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "detect":
      guard let args = call.arguments as? [String: Any],
            let path = args["imagePath"] as? String else {
        result(FlutterError(code: "INVALID_ARGS",
                            message: "imagePath required",
                            details: nil))
        return
      }
      self.detect(imagePath: path, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func detect(imagePath: String, result: @escaping FlutterResult) {
    guard let image = UIImage(contentsOfFile: imagePath),
          let cgImage = image.cgImage else {
      result(FlutterError(code: "LOAD_FAILED",
                          message: "Cannot load image at \(imagePath)",
                          details: nil))
      return
    }

    // 关键：UIImage 默认按 EXIF 旋转显示，但 `cgImage` 是 raw sensor 像素。
    // Vision 直接处理 cgImage 的话，返回的 landmark 坐标是 raw pixel 空间；
    // 但 Dart 端 `image` package 4.x 在 decodeJpg 时会**烘焙 EXIF 旋转**进
    // 像素数据（见 image/lib/src/formats/jpeg/_jpeg_quantize_io.dart
    // `getImageFromJpeg` 的 `flipWidthHeight` 逻辑），所以 Dart 端读到的
    // `image.width / height` 是**显示**尺寸（已旋转），像素也已旋转。
    // 不做 orientation 修正的话，mask 会被画到错位置（之前看到的"美白在
    // 右上角"就是 landscape 坐标被误用为 portrait 坐标）。
    //
    // 修法：把 EXIF orientation 传给 Vision，让 Vision 内部旋转图片；返回的
    // 坐标就是 display 空间；polygon() 用 display 尺寸反归一化。
    let cgOrientation = Self.cgOrientation(from: image.imageOrientation)
    let displaySize = Self.displaySize(cgImage: cgImage, orientation: cgOrientation)

    let request = VNDetectFaceLandmarksRequest { (req, err) in
      if let err = err {
        result(FlutterError(code: "DETECT_FAILED",
                            message: err.localizedDescription,
                            details: nil))
        return
      }
      let observations = (req.results as? [VNFaceObservation]) ?? []
      let faces: [[String: Any]] = observations.map { obs in
        return [
          "face":       self.polygon(from: obs.landmarks?.faceContour,
                                     imageWidth: displaySize.width,
                                     imageHeight: displaySize.height) ?? [],
          "leftEye":    self.polygon(from: obs.landmarks?.leftEye,
                                     imageWidth: displaySize.width,
                                     imageHeight: displaySize.height) ?? [],
          "rightEye":   self.polygon(from: obs.landmarks?.rightEye,
                                     imageWidth: displaySize.width,
                                     imageHeight: displaySize.height) ?? [],
          "outerLips":  self.polygon(from: obs.landmarks?.outerLips,
                                     imageWidth: displaySize.width,
                                     imageHeight: displaySize.height) ?? [],
          "innerLips":  self.polygon(from: obs.landmarks?.innerLips,
                                     imageWidth: displaySize.width,
                                     imageHeight: displaySize.height) ?? [],
        ]
      }
      result(faces)
    }

    let handler = VNImageRequestHandler(cgImage: cgImage,
                                        orientation: cgOrientation,
                                        options: [:])
    do {
      try handler.perform([request])
    } catch {
      result(FlutterError(code: "DETECT_FAILED",
                          message: error.localizedDescription,
                          details: nil))
    }
  }

  /// 把 UIImage.Orientation 映射到 CGImagePropertyOrientation
  /// （Vision / Core Image 用后者）
  private static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch uiOrientation {
    case .up:            return .up
    case .upMirrored:    return .upMirrored
    case .down:          return .down
    case .downMirrored:  return .downMirrored
    case .left:          return .left
    case .leftMirrored:  return .leftMirrored
    case .right:         return .right
    case .rightMirrored: return .rightMirrored
    @unknown default:    return .up
    }
  }

  /// 给定 raw cgImage 尺寸 + 最终 display orientation，算显示宽高
  /// （横屏 orientation 时，display 宽 = cgImage 高、display 高 = cgImage 宽）
  private static func displaySize(cgImage: CGImage,
                                  orientation: CGImagePropertyOrientation) -> (width: Double, height: Double) {
    let swapsAxes: Bool
    switch orientation {
    case .left, .leftMirrored, .right, .rightMirrored:
      swapsAxes = true
    default:
      swapsAxes = false
    }
    if swapsAxes {
      return (Double(cgImage.height), Double(cgImage.width))
    }
    return (Double(cgImage.width), Double(cgImage.height))
  }

  private func polygon(from landmark: VNFaceLandmarkRegion2D?,
                       imageWidth: Double,
                       imageHeight: Double) -> [[String: Double]]? {
    guard let landmark = landmark else { return nil }
    let points: [[String: Double]] = landmark.normalizedPoints.map { point in
      let x = Double(point.x) * imageWidth
      // Vision normalizedPoints 是**左下角原点 + Y 向上**；
      // Dart 端 mask 期望**左上角 + Y 向下**——所以翻 Y。
      let y = Double(1.0 - point.y) * imageHeight
      return ["x": x, "y": y]
    }
    return points.isEmpty ? nil : points
  }
}
