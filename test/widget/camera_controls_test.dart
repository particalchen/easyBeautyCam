import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/features/camera/widgets/camera_controls.dart';
import 'package:easy_beauty_cam/features/camera/widgets/camera_switch_button.dart';
import 'package:easy_beauty_cam/features/camera/widgets/capture_button.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: child),
      ),
    );
  }

  group('CameraControls - 后置相机', () {
    testWidgets('showPoseStrip=true: PoseStrip 可见（包含 SizedBox(80)）', (tester) async {
      await tester.pumpWidget(wrap(
        const CameraControls(
          cameraIndex: 0,
          showPoseStrip: true,
          onCameraSwitch: _noopSwitch,
          onCapture: _noopCapture,
        ),
      ));
      await tester.pump();

      // PoseThumbStrip 用 SizedBox(height: poseThumbnail=80) 包裹 ListView
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 80 && w.child != null,
        ),
        findsAtLeastNWidgets(1),
        reason: 'showPoseStrip=true 时应包含 PoseStrip 的 SizedBox(80)',
      );
    });

    testWidgets('点击 CaptureButton 触发 onCapture', (tester) async {
      var captured = 0;
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          showPoseStrip: true,
          onCameraSwitch: (_) {},
          onCapture: () => captured++,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(CaptureButton));
      await tester.pump();

      expect(captured, 1, reason: '点击快门应触发 onCapture 一次');
    });

    testWidgets('点击 CameraSwitchButton 触发 onCameraSwitch(1)', (tester) async {
      int? switchedTo;
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 0,
          showPoseStrip: true,
          onCameraSwitch: (i) => switchedTo = i,
          onCapture: () {},
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(CameraSwitchButton));
      await tester.pump();

      expect(switchedTo, 1);
    });
  });

  group('CameraControls - 前置相机', () {
    testWidgets('showPoseStrip=false: 不渲染 PoseStrip', (tester) async {
      await tester.pumpWidget(wrap(
        const CameraControls(
          cameraIndex: 1,
          showPoseStrip: false,
          onCameraSwitch: _noopSwitch,
          onCapture: _noopCapture,
        ),
      ));
      await tester.pump();

      // 前置相机隐藏 PoseStrip 后，没有任何 SizedBox(height=80)
      final all80SizedBoxes = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 80 && w.child != null,
      );
      expect(all80SizedBoxes, findsNothing,
          reason: 'showPoseStrip=false 时不应有 PoseStrip 的 SizedBox(80)');
    });

    testWidgets('点击 CameraSwitchButton 触发 onCameraSwitch(0)', (tester) async {
      int? switchedTo;
      await tester.pumpWidget(wrap(
        CameraControls(
          cameraIndex: 1,
          showPoseStrip: false,
          onCameraSwitch: (i) => switchedTo = i,
          onCapture: () {},
        ),
      ));
      await tester.pump();

      await tester.tap(find.byType(CameraSwitchButton));
      await tester.pump();

      expect(switchedTo, 0);
    });
  });
}

void _noopSwitch(int _) {}
void _noopCapture() {}
