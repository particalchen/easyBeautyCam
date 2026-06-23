import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/camera/camera_screen.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';

void main() {
  Widget wrap() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: const CameraScreen(),
    );
  }

  group('CameraScreen orientation 旋转', () {
    testWidgets('portrait (size 1170x2532) 下 RotatedBox.quarterTurns = 0', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(child: wrap()));
      await tester.pump();

      final rotated = find.byType(RotatedBox);
      expect(rotated, findsOneWidget,
          reason: 'CameraScreen body 应被 RotatedBox 包裹');
      final box = tester.widget<RotatedBox>(rotated);
      expect(box.quarterTurns, 0,
          reason: 'portrait 时 quarterTurns 应该是 0');
    });

    testWidgets('landscape (size 2532x1170) 下 RotatedBox.quarterTurns = 1', (tester) async {
      tester.view.physicalSize = const Size(2532, 1170);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(child: wrap()));
      await tester.pump();

      final box = tester.widget<RotatedBox>(find.byType(RotatedBox));
      expect(box.quarterTurns, 1,
          reason: 'landscape 时 quarterTurns 应该是 1');
    });
  });
}
