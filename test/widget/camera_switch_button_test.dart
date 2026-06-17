import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/camera/widgets/app_circle_icon_button.dart';
import 'package:easy_beauty_cam/features/camera/widgets/camera_switch_button.dart';

void main() {
  group('CameraSwitchButton', () {
    testWidgets('渲染 cameraswitch 图标', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CameraSwitchButton(onPressed: () {}),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.cameraswitch), findsOneWidget);
    });

    testWidgets('点击触发 onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CameraSwitchButton(onPressed: () => tapped = true),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CameraSwitchButton));
      expect(tapped, isTrue);
    });

    testWidgets('复用 AppCircleIconButton（视觉与相册按钮一致）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CameraSwitchButton(onPressed: () {}),
            ),
          ),
        ),
      );

      // CameraSwitchButton 内部应该是 AppCircleIconButton
      expect(
        find.descendant(
          of: find.byType(CameraSwitchButton),
          matching: find.byType(AppCircleIconButton),
        ),
        findsOneWidget,
      );
    });
  });
}