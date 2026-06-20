import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/filter/widgets/interactive_crop_editor.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';

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
      cropRatio: CropRatio.free,
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
      cropRatio: CropRatio.free,
      scale: 1.0,
      translation: Offset.zero,
      onTransformChanged: (_, __) {},
    )));
    await tester.pump();
    expect(find.byType(InteractiveCropEditor), findsOneWidget);
  });
}