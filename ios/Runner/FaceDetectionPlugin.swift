import Flutter
import UIKit
import Vision

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

    let request = VNDetectFaceLandmarksRequest { (req, err) in
      if let err = err {
        result(FlutterError(code: "DETECT_FAILED",
                            message: err.localizedDescription,
                            details: nil))
        return
      }
      let observations = (req.results as? [VNFaceObservation]) ?? []
      let imageWidth = Double(cgImage.width)
      let imageHeight = Double(cgImage.height)
      let faces: [[String: Any]] = observations.map { obs in
        return [
          "face":       self.polygon(from: obs.landmarks?.faceContour,
                                     imageWidth: imageWidth, imageHeight: imageHeight) ?? [],
          "leftEye":    self.polygon(from: obs.landmarks?.leftEye,
                                     imageWidth: imageWidth, imageHeight: imageHeight) ?? [],
          "rightEye":   self.polygon(from: obs.landmarks?.rightEye,
                                     imageWidth: imageWidth, imageHeight: imageHeight) ?? [],
          "outerLips":  self.polygon(from: obs.landmarks?.outerLips,
                                     imageWidth: imageWidth, imageHeight: imageHeight) ?? [],
          "innerLips":  self.polygon(from: obs.landmarks?.innerLips,
                                     imageWidth: imageWidth, imageHeight: imageHeight) ?? [],
        ]
      }
      result(faces)
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
      try handler.perform([request])
    } catch {
      result(FlutterError(code: "DETECT_FAILED",
                          message: error.localizedDescription,
                          details: nil))
    }
  }

  private func polygon(from landmark: VNFaceLandmarkRegion2D?,
                       imageWidth: Double,
                       imageHeight: Double) -> [[String: Double]]? {
    guard let landmark = landmark else { return nil }
    let points: [[String: Double]] = landmark.normalizedPoints.map { point in
      let x = Double(point.x) * imageWidth
      let y = Double(1.0 - point.y) * imageHeight
      return ["x": x, "y": y]
    }
    return points.isEmpty ? nil : points
  }
}
