import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/core/theme/app_colors.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/features/camera/widgets/camera_controls.dart';

void main() {
  Widget _wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );
  }

  group('CameraControls - 后置相机', () {
    testWidgets('渲染 4 颗焦段 pill: .5 / 1x / 2 / 3', (tester) async {
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      expect(find.text('.5'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('点击 2x 触发 onZoomSelect(2.0)，不触发 onCameraSwitch', (tester) async {
      double? zoomedTo;
      int? switchedTo;

      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (z) => zoomedTo = z,
          onCapture: () {},
        ),
      ));

      await tester.tap(find.text('2'));
      expect(zoomedTo, 2.0);
      expect(switchedTo, isNull, reason: '2x 不应该触发 onCameraSwitch');
    });

    testWidgets('点击 .5 触发 onZoomSelect(0.5)', (tester) async {
      double? zoomedTo;
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (z) => zoomedTo = z,
          onCapture: () {},
        ),
      ));

      await tester.tap(find.text('.5'));
      expect(zoomedTo, 0.5);
    });

    testWidgets('渲染相机切换按钮，点击触发 onCameraSwitch(1)', (tester) async {
      int? switchedTo;
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.cameraswitch));
      expect(switchedTo, 1);
    });

    testWidgets('currentZoom=2.0 时，2x pill 渲染为 AppColors.primary（选中态）', (tester) async {
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 2.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      // 找到文字 "2" 对应的 AnimatedContainer，验证它的 decoration.color == AppColors.primary
      final containerFinder = find.ancestor(
        of: find.text('2'),
        matching: find.byType(AnimatedContainer),
      );
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primary);
    });
  });

  group('CameraControls - 前置相机', () {
    testWidgets('焦段行只剩 1 颗 1x pill', (tester) async {
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 1,
          currentZoom: 1.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      expect(find.text('1x'), findsOneWidget);
      expect(find.text('.5'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('点击 1x 触发 onZoomSelect(1.0)', (tester) async {
      double? zoomedTo;
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 1,
          currentZoom: 1.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (z) => zoomedTo = z,
          onCapture: () {},
        ),
      ));

      await tester.tap(find.text('1x'));
      expect(zoomedTo, 1.0);
    });

    testWidgets('点击相机切换按钮触发 onCameraSwitch(0)', (tester) async {
      int? switchedTo;
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 1,
          currentZoom: 1.0,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.cameraswitch));
      expect(switchedTo, 0);
    });

    testWidgets('前置相机 1x pill 始终选中（只有 1 颗）', (tester) async {
      await tester.pumpWidget(_wrap(
        CameraControls(
          cameraIndex: 1,
          currentZoom: 1.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      final containerFinder = find.ancestor(
        of: find.text('1x'),
        matching: find.byType(AnimatedContainer),
      );
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primary);
    });
  });
}
