import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/core/theme/app_colors.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/features/camera/widgets/camera_controls.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );
  }

  group('CameraControls - 后置相机（硬件支持 0.5~5.0）', () {
    testWidgets('渲染 4 颗焦段 pill: 0.5x / 1x / 2x / 3x（统一 Nx 格式）', (tester) async {
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 5.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('点击 2x 触发 onZoomSelect(2.0)，不触发 onCameraSwitch', (tester) async {
      double? zoomedTo;
      int? switchedTo;

      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 5.0,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (z) => zoomedTo = z,
          onCapture: () {},
        ),
      ));

      await tester.tap(find.text('2x'));
      expect(zoomedTo, 2.0);
      expect(switchedTo, isNull, reason: '2x 不应该触发 onCameraSwitch');
    });

    testWidgets('点击 0.5x 触发 onZoomSelect(0.5)', (tester) async {
      double? zoomedTo;
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 5.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (z) => zoomedTo = z,
          onCapture: () {},
        ),
      ));

      await tester.tap(find.text('0.5x'));
      expect(zoomedTo, 0.5);
    });

    testWidgets('渲染相机切换按钮，点击触发 onCameraSwitch(1)', (tester) async {
      int? switchedTo;
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 5.0,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.cameraswitch));
      expect(switchedTo, 1);
    });

    testWidgets('currentZoom=2.0 时，2x pill 渲染为 AppColors.primary（选中态）', (tester) async {
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 2.0,
          minZoom: 0.5,
          maxZoom: 5.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      final containerFinder = find.ancestor(
        of: find.text('2x'),
        matching: find.byType(AnimatedContainer),
      );
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primary);
    });
  });

  group('CameraControls - 硬件范围过滤（真实设备 min=1.0）', () {
    testWidgets('minZoom=1.0 时 0.5x pill 被过滤掉', (tester) async {
      // 模拟大部分 iOS 设备：硬件 min=1.0，不支持 0.5x
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          minZoom: 1.0,
          maxZoom: 5.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      expect(find.text('0.5x'), findsNothing, reason: '0.5x 不在硬件 [1.0,5.0] 内');
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('maxZoom=2.0 时 3x pill 被过滤掉', (tester) async {
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 2.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('3x'), findsNothing, reason: '3x 不在硬件 [0.5,2.0] 内');
    });
  });

  group('CameraControls - 前置相机', () {
    testWidgets('焦段行只剩 1 颗 1x pill', (tester) async {
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 1,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 5.0,
          onCameraSwitch: (_) {},
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      expect(find.text('1x'), findsOneWidget);
      expect(find.text('0.5x'), findsNothing);
      expect(find.text('2x'), findsNothing);
      expect(find.text('3x'), findsNothing);
    });

    testWidgets('点击 1x 触发 onZoomSelect(1.0)', (tester) async {
      double? zoomedTo;
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 1,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 5.0,
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
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 1,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 5.0,
          onCameraSwitch: (i) => switchedTo = i,
          onZoomSelect: (_) {},
          onCapture: () {},
        ),
      ));

      await tester.tap(find.byIcon(Icons.cameraswitch));
      expect(switchedTo, 0);
    });

    testWidgets('前置相机 1x pill 始终选中（只有 1 颗）', (tester) async {
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 1,
          currentZoom: 1.0,
          minZoom: 0.5,
          maxZoom: 5.0,
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