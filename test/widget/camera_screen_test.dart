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

    testWidgets('portrait (size 1170x2532) 下 SizedBox 拿到 portrait 形状约束', (tester) async {
      // 回归 bug：之前 SizedBox 主动 swap 了宽高，子节点以横屏形状渲染、上面挤满下面留黑
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(child: wrap()));
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('cameraContentSizedBox')),
      );
      // portrait 时 SizedBox 应跟随屏幕（宽 < 高），不 swap
      expect(sizedBox.width, isNotNull);
      expect(sizedBox.height, isNotNull);
      expect(sizedBox.width!, lessThan(sizedBox.height!),
          reason: 'portrait 时宽 < 高（不 swap）');
    });

    testWidgets('landscape (size 2532x1170) 下 SizedBox 拿到 portrait 形状约束（RotatedBox 已自动 swap）', (tester) async {
      // 关键事实：RotatedBox 内部已经 swap 了 constraints，
      // 所以 LayoutBuilder 拿到的 maxWidth/maxHeight 已经是 portrait 形状（宽 < 高）。
      // SizedBox 直接用 constraints 即可，不要再手动 swap（否则就反向变横屏了）。
      tester.view.physicalSize = const Size(2532, 1170);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(child: wrap()));
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('cameraContentSizedBox')),
      );
      expect(sizedBox.width!, lessThan(sizedBox.height!),
          reason: 'landscape 时宽 < 高（RotatedBox 已 swap，SizedBox 直接跟随）');
    });
  });
}
