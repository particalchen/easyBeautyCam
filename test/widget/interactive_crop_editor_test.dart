import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/filter/widgets/interactive_crop_editor.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;

/// 1x1 透明 PNG
final _kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xC0,
  0xC0, 0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0x9D, 0xA1, 0x88, 0x84, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 300, height: 400, child: child),
      ),
    );

void main() {
  testWidgets('InteractiveCropEditor 渲染 InteractiveViewer + Image', (tester) async {
    await tester.pumpWidget(_wrap(InteractiveCropEditor(
      previewBytes: _kTinyPng,
      cropRatio: CropRatio.original,
      scale: 1.0,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('非自由比例：渲染 CustomPaint 遮罩', (tester) async {
    await tester.pumpWidget(_wrap(InteractiveCropEditor(
      previewBytes: _kTinyPng,
      cropRatio: CropRatio.ratio_1_1,
      scale: 1.0,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();
    // CustomPaint 至少出现一次（_CropFramePainter）
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('自由比例：不报错', (tester) async {
    await tester.pumpWidget(_wrap(InteractiveCropEditor(
      previewBytes: _kTinyPng,
      cropRatio: CropRatio.original,
      scale: 1.0,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();
    expect(find.byType(InteractiveCropEditor), findsOneWidget);
  });

  testWidgets('InteractiveCropEditor minScale 为 0.5（允许拉远）', (tester) async {
    await tester.pumpWidget(_wrap(InteractiveCropEditor(
      previewBytes: _kTinyPng,
      imagePath: null,
      cropRatio: CropRatio.ratio_1_1,
      scale: 0.5,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.minScale, 0.5);
    expect(viewer.maxScale, 4.0);
  });

  testWidgets('InteractiveCropEditor 内 Image 用 BoxFit.cover 铺满', (tester) async {
    final src = img.Image(width: 1, height: 1);
    final bytes = Uint8List.fromList(img.encodePng(src));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: InteractiveCropEditor(
            previewBytes: bytes,
            imagePath: null,
            cropRatio: CropRatio.ratio_1_1,
            scale: 1.0,
            translation: Offset.zero,
            onTransformChanged: (_, __) {},
          ),
        ),
      ),
    ));
    await tester.pump();

    // 找到 InteractiveViewer 内的 Image
    final images = tester.widgetList<Image>(find.descendant(
      of: find.byType(InteractiveViewer),
      matching: find.byType(Image),
    ));
    expect(images, isNotEmpty);
    // 至少有一个 Image 用 BoxFit.cover
    final coverImages = images.where((img) => img.fit == BoxFit.cover);
    expect(coverImages.length, greaterThan(0),
        reason: 'Image 应该用 BoxFit.cover 铺满 viewport 而非 contain');
  });

  testWidgets('_syncFromProps 用 viewport 半尺寸转换 translation', (tester) async {
    final src = img.Image(width: 1, height: 1);
    final bytes = Uint8List.fromList(img.encodePng(src));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: InteractiveCropEditor(
            previewBytes: bytes,
            imagePath: null,
            cropRatio: CropRatio.ratio_1_1,
            scale: 1.0,
            translation: const Offset(0.5, 0), // 归一化 0.5
            onTransformChanged: (_, __) {},
          ),
        ),
      ),
    ));
    // 第一次 pump 完成 build；第二次 pump 触发 addPostFrameCallback 中的 _syncFromProps。
    await tester.pump();
    await tester.pump();

    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final matrix = viewer.transformationController!.value;
    // 期望：translation.x = 0.5 * (300/2) = 75 像素
    final actualTx = matrix.getTranslation().x;
    expect(actualTx, closeTo(75.0, 0.1),
        reason: '_syncFromProps 应该把 translation 归一化值乘以半尺寸');
  });

  testWidgets('InteractiveViewer 允许子节点超出 viewport 拖动 (boundaryMargin=∞)',
      (tester) async {
    await tester.pumpWidget(_wrap(InteractiveCropEditor(
      previewBytes: _kTinyPng,
      cropRatio: CropRatio.ratio_1_1,
      scale: 1.0,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();

    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.boundaryMargin, const EdgeInsets.all(double.infinity),
        reason: 'boundaryMargin 必须为无限大，否则图片拖到裁切框边缘后就卡住');
  });

  testWidgets('InteractiveCropEditor Image 使用 gaplessPlayback 避免闪帧',
      (tester) async {
    await tester.pumpWidget(_wrap(InteractiveCropEditor(
      previewBytes: _kTinyPng,
      cropRatio: CropRatio.original,
      scale: 1.0,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.gaplessPlayback, isTrue,
        reason: 'Image 必须开启 gaplessPlayback，否则切换 previewBytes 时会闪一帧空白');
  });

  testWidgets('InteractiveCropEditor 切换 previewBytes 不报错 (gaplessPlayback 路径)',
      (tester) async {
    // 第一次：null bytes + imagePath 兜底
    await tester.pumpWidget(_wrap(InteractiveCropEditor(
      previewBytes: null,
      imagePath: null,
      cropRatio: CropRatio.original,
      scale: 1.0,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();
    // 第二次：换成真实 bytes
    await tester.pumpWidget(_wrap(InteractiveCropEditor(
      previewBytes: _kTinyPng,
      imagePath: null,
      cropRatio: CropRatio.original,
      scale: 1.0,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();
    // 不应抛任何异常
    expect(tester.takeException(), isNull);
  });
}