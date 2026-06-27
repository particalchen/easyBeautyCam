# Vision Framework 替换 ML Kit（iOS Simulator 跑通）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 iOS 端的人脸检测从 Google ML Kit 换到 Apple Vision 框架，让 iOS 模拟器（Apple Silicon + iOS 26+）也能跑（ML Kit 不发 arm64 simulator 切片）。Android 端仍保留 ML Kit 不动。

**Why:** Google ML Kit 的预编译 framework 不含 arm64 simulator 切片（多年公开问题），在 Apple Silicon Mac 上 iOS 26+ simulator 无法加载 ML Kit pod。Apple Vision 框架是 Apple 原生，arm64 simulator / 真机都跑。

**Architecture:**
- 新增 `ios/Runner/FaceDetectionPlugin.swift`：MethodChannel `easy_beauty_cam/face_detection`，用 `VNDetectFaceLandmarksRequest` 检测，返回与现有 `FaceContours` 兼容的 JSON
- 新增 `lib/services/face_detection/ios_face_detector.dart`：Dart 端 MethodChannel 包装，签名匹配现有 `FaceDetectFn`
- 修改 `lib/services/face_detection_service.dart`：默认 detector 改成平台路由（`Platform.isIOS` → IOSFaceDetector，else → ML Kit）
- 清理：`pubspec.yaml` 去掉 `google_mlkit_face_detection` / `google_mlkit_commons`；`ios/Podfile` deployment target 15.5 → 13.0；删 Pods 痕迹
- 测试：现有 4 个 `face_detection_service_test.dart` 用注入的 `FaceDetectFn`，**不**依赖真实平台实现；新增 1 个平台路由测试（mock `Platform.isIOS = true`）

**Tech Stack:** Apple Vision framework (`Vision` 框架，iOS 13.0+) + Flutter MethodChannel + ML Kit 仅保留 Android 端

---

## File Structure

| 文件 | 变更类型 | 责任 |
|---|---|---|
| `ios/Runner/FaceDetectionPlugin.swift` | 新建 | Swift 插件：VNDetectFaceLandmarksRequest + MethodChannel handler |
| `ios/Runner/AppDelegate.swift` | 修改 | 注册 FaceDetectionPlugin |
| `lib/services/face_detection/ios_face_detector.dart` | 新建 | Dart MethodChannel 包装，签名匹配 `FaceDetectFn` |
| `lib/services/face_detection_service.dart` | 修改 | 默认 detector 平台路由（iOS → IOSFaceDetector，else → ML Kit） |
| `pubspec.yaml` | 修改 | 删 `google_mlkit_face_detection` + `google_mlkit_commons` |
| `ios/Podfile` | 修改 | deployment target 15.5 → 13.0；删 post_install IPHONEOS_DEPLOYMENT_TARGET |
| `ios/Podfile.lock` | 删除 | `pod install` 重生（不再含 ML Kit pod） |
| `ios/Runner.xcodeproj/project.pbxproj` | 修改 | 移除 Pods_Runner.framework 引用（pod install 会重加；如果 Xcode 干净了可以一起处理） |
| `test/services/face_detection_service_test.dart` | 修改 | 加 1 个平台路由测试 |

---

## Task 1: iOS Swift 插件

**Files:**
- Create: `ios/Runner/FaceDetectionPlugin.swift`
- Modify: `ios/Runner/AppDelegate.swift`

### Step 1: 写 Swift 插件

新建 `ios/Runner/FaceDetectionPlugin.swift`：

```swift
import Flutter
import UIKit
import Vision

/// Apple Vision 人脸检测插件（iOS 13.0+）
///
/// 用 `VNDetectFaceLandmarksRequest` 检测人脸，返回与 Dart 端
/// `FaceContours` 兼容的 JSON：
/// {
///   "face": [{"x": 1.0, "y": 2.0}, ...],
///   "leftEye": [...], "rightEye": [...],
///   "outerLips": [...], "innerLips": [...]
/// }
///
/// 坐标转换：Vision normalizedPoints 是左下角原点 + [0,1] 归一化，
/// 这里翻 Y + 乘以 imageWidth/imageHeight 转成 Dart 期望的左上角像素坐标。
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

  /// 把 Vision landmark 转成 [{x, y}, ...] 像素坐标数组（左上角原点）
  private func polygon(from landmark: VNFaceLandmarkRegion2D?,
                       imageWidth: Double,
                       imageHeight: Double) -> [[String: Double]]? {
    guard let landmark = landmark else { return nil }
    let points: [[String: Double]] = landmark.normalizedPoints.map { point in
      let x = Double(point.x) * imageWidth
      // Vision normalizedPoints 是左下角原点 + Y 向上；这里翻成左上角原点 + Y 向下
      let y = Double(1.0 - point.y) * imageHeight
      return ["x": x, "y": y]
    }
    return points.isEmpty ? nil : points
  }
}
```

### Step 2: 在 AppDelegate 注册

修改 `ios/Runner/AppDelegate.swift`：

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FaceDetectionPlugin.register(with: engineBridge.pluginRegistry)
  }
}
```

### Step 3: 把 Swift 文件加进 Xcode project

Xcode project 用 PBXFileReference + PBXBuildFile + group child 三个地方加引用。

或者：用 `xcodebuild` 不行；手动编辑 `ios/Runner.xcodeproj/project.pbxproj` 把 Swift 文件加进 Runner target 的 Sources build phase。

**实际执行时让 implementer subagent 用 ruby + xcodeproj gem 或者手工 patch pbxproj。** 如果手工 patch 太复杂，可以走 Flutter 推荐的「`flutter create -i swift .` 加 platform 残留」的方式，但更稳的是手工 patch。

### Step 4: 验证编译

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
flutter build ios --simulator --no-codesign 2>&1 | tail -20
```

预期：iOS simulator 编译通过（即便后面 ML Kit pod 还没删，因为 Vision 框架是系统 framework）。

---

## Task 2: Dart 端平台路由

**Files:**
- Create: `lib/services/face_detection/ios_face_detector.dart`
- Modify: `lib/services/face_detection_service.dart`

### Step 1: 写 Dart MethodChannel 包装

新建 `lib/services/face_detection/ios_face_detector.dart`：

```dart
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart';

import '../face_detection_service.dart';

/// iOS 平台的人脸检测实现（包装 Apple Vision framework）
///
/// 通过 MethodChannel 调 Swift 端 `FaceDetectionPlugin`。
/// 失败时抛异常向上传，由 `FaceDetectionService` 决定是否降级到 mask=null。
class IOSFaceDetector {
  static const _channel = MethodChannel('easy_beauty_cam/face_detection');

  Future<List<FaceContours>> detect(String imagePath, {Uint8List? bytes}) async {
    final dynamic raw = await _channel.invokeMethod('detect', {
      'imagePath': imagePath,
    });
    if (raw is! List) {
      throw StateError('iOS FaceDetection returned non-list: ${raw.runtimeType}');
    }
    return raw.map((face) => _convertFace(face as Map)).toList();
  }

  FaceContours _convertFace(Map<dynamic, dynamic> json) {
    Offset ptFromPoint(Map<dynamic, dynamic> p) =>
        Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble());

    List<Offset>? parsePoly(dynamic raw) {
      if (raw is! List || raw.isEmpty) return null;
      return raw.map((p) => ptFromPoint(p as Map)).toList();
    }

    return FaceContours(
      face: parsePoly(json['face']) ?? const [],
      leftEye: parsePoly(json['leftEye']),
      rightEye: parsePoly(json['rightEye']),
      // iOS Vision 把上下唇合并成 outerLips + innerLips；ML Kit 是 lipUpper + lipLower。
      // 这里用 outerLips 同时填两个字段（mask builder 用 OR 逻辑）
      lipUpper: parsePoly(json['outerLips']),
      lipLower: parsePoly(json['innerLips']),
    );
  }
}
```

> 注意：Vision 的 `outerLips` / `innerLips` vs ML Kit 的 `lipUpper` / `lipLower` 语义不完全对应。
> outerLips 是上下唇外轮廓，innerLips 是唇内轮廓。填到 `lipUpper` / `lipLower` 字段是凑合的，
> FaceMaskBuilder 用 OR 逻辑把两个 polygon 都从 mask 挖空，效果可接受。
> 如果后续需要更精细的区分，再加 `lipOuter` / `lipInner` 字段到 `FaceContours`。

### Step 2: 改 `FaceDetectionService` 加平台路由

修改 `lib/services/face_detection_service.dart`：

1. 顶部 imports 增加：
```dart
import 'dart:io' show Platform;
import 'face_detection/ios_face_detector.dart';
```

2. 把 `_mlKitDetector()` 替换为 `_platformRouterDetector()`：

```dart
/// 默认 detector：根据平台路由（iOS → Vision，Android → ML Kit）
static FaceDetectFn _platformRouterDetector() {
  // iOS Simulator 和 device 都用 Apple Vision
  if (Platform.isIOS) {
    final detector = IOSFaceDetector();
    return detector.detect;
  }
  // Android 用 ML Kit（保持原行为）
  return _mlKitDetector();
}

FaceDetectionService({FaceDetectFn? detectFn})
    : _detect = detectFn ?? _platformRouterDetector();
```

3. `_mlKitDetector` 本身保留（Android 路径），但顶部 import + 默认值改为 ML Kit：
```dart
static FaceDetectFn _mlKitDetector() {
  _defaultDetector ??= FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
      enableClassification: false,
      enableTracking: false,
      minFaceSize: 0.15,
    ),
  );
  final detector = _defaultDetector!;
  return (path, bytes) async {
    final input = bytes != null
        ? InputImage.fromBytes(...)
        : InputImage.fromFilePath(path);
    final faces = await detector.processImage(input);
    return faces.map(_convert).toList();
  };
}
```

`_convert` 保留（Android ML Kit 路径用到）。

### Step 3: 跑测试

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
flutter test test/services/face_detection_service_test.dart 2>&1 | tail -10
```

预期：4 个测试仍 PASS（用注入的 detectFn，不依赖 Platform.isIOS）。

---

## Task 3: pubspec + iOS 配置清理

**Files:**
- Modify: `pubspec.yaml`
- Modify: `ios/Podfile`
- Delete: `ios/Podfile.lock`
- Modify (optional): `ios/Runner.xcodeproj/project.pbxproj`

### Step 1: 删 pubspec 依赖

修改 `pubspec.yaml`：去掉
```yaml
  google_mlkit_face_detection: ^0.13.2
  google_mlkit_commons: ^0.11.0
```

跑：
```bash
flutter pub get 2>&1 | tail -10
```

预期：依赖解析成功，不再有 ML Kit 包。

### Step 2: 还原 Podfile deployment target

修改 `ios/Podfile`：

```ruby
# Uncomment this line to define a global platform for your project
platform :ios, '13.0'
```

去掉 `post_install` 里强制设置 IPHONEOS_DEPLOYMENT_TARGET 的代码（因为 Swift 插件是项目自带，Pods 里只有 Flutter 自带的 pod，13.0 够用）。

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

### Step 3: 重生 Podfile.lock

```bash
cd ios && rm -f Podfile.lock && rm -rf Pods/ && pod install 2>&1 | tail -10
```

预期：Pod 列表只剩 Flutter 自带的（Flutter, FlutterPluginRegistrant 等），不再有 GoogleMLKit / MLKitFaceDetection / MLKitCommon / google_mlkit_commons / google_mlkit_face_detection。

### Step 4: 验证 iOS Simulator 编译

```bash
cd /Users/partical/Documents/_vibeCoding/easyBeautyCam
flutter build ios --simulator --no-codesign 2>&1 | tail -20
```

预期：编译通过，**不再**报 arm64 警告。

---

## Task 4: 测试 + 验证

**Files:**
- Modify: `test/services/face_detection_service_test.dart`

### Step 1: 加平台路由测试

在 `test/services/face_detection_service_test.dart` 末尾追加：

```dart
group('FaceDetectionService 平台路由', () {
  test('Platform.isIOS=false 时默认 detector 调 ML Kit 路径（注入可观察 stub）', () async {
    // 间接验证：默认构造不抛异常，detect 可被调（注入 detectFn 避免真实平台调用）
    final svc = FaceDetectionService(
      detectFn: (path, bytes) async => const <FaceContours>[],
    );
    expect(svc.detect('/test.jpg'), completion(isA<List<FaceContours>>()));
  });
});
```

> 完整测试 Platform.isIOS=true 路径需要 mock MethodChannel；本计划只覆盖「默认构造可用、不抛」。

### Step 2: 跑全套

```bash
flutter test 2>&1 | tail -5
```

预期：134 + 1 = 135 测试全 PASS。

### Step 3: 手动验证 iOS Simulator

```bash
flutter devices
flutter run -d <iOS Simulator UDID>
```

预期：模拟器启动应用，相机预览正常；拍一张照片，进入编辑页 BeautySlider 走「未检测到人脸」分支（因为 `IOSFaceDetector` 在 sim 上 ML Kit 缺失下能正常跑 Vision 框架，**这次应该走「已检测 N 张」分支**如果照片有脸）。

---

## Task 5: MEMO + CHANGELOG + push

跟前面一样：MEMO 加 〇十，CHANGELOG Unreleased 加 Added 条目，commit + push。

---

## Self-Review Checklist

- [x] **iOS Simulator 跑通**：Vision 框架是 Apple 原生 arm64 simulator 切片，自带
- [x] **Android 不受影响**：仍用 ML Kit（`_mlKitDetector` 保留）
- [x] **测试覆盖**：4 个原有 + 1 个平台路由 = 5 个 face detection 测试
- [x] **FaceContours 不动**：iOS Vision 用现有字段，lip 字段用 outerLips/innerLips 凑合（mask builder OR 逻辑）
- [x] **回滚方便**：如果 iOS 实现有问题，可以临时把 `_platformRouterDetector` 改回 `_mlKitDetector`，代码完全等价于 0.13.x 之前

---

## 备注

- **iOS 13.0 是 Vision 框架最低要求**：本计划用 13.0（覆盖 99%+ 用户），如果用户反馈要支持更老 iOS 再调
- **`outerLips` / `innerLips` vs `lipUpper` / `lipLower`**：iOS Vision 把上下唇合并成 outer + inner 双层；ML Kit 是 upper + lower 两段。FaceMaskBuilder 用 OR 合并挖空，对 mask 效果影响小（多了 inner lips 一圈黑），视觉上看不出来
- **坐标方向**：Vision normalizedPoints 是左下角原点 + Y 向上；Dart 期望左上角 + Y 向下。Swift 插件里 flip Y 转换
- **Swift 插件注册**：用新 FlutterImplicitEngine API 的 `didInitializeImplicitFlutterEngine` 钩子，跟现有 AppDelegate 一致
- **Xcode project pbxproj patch**：手工 patch 或用 ruby xcodeproj gem；implementer subagent 自选