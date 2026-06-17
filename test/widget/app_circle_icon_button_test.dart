import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/camera/widgets/app_circle_icon_button.dart';

void main() {
  group('AppCircleIconButton', () {
    testWidgets('点击触发 onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () => tapped = true,
                size: 56,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppCircleIconButton));
      expect(tapped, isTrue);
    });

    testWidgets('onPressed 为 null 时不响应点击', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.cameraswitch,
                onPressed: null,
                size: 56,
              ),
            ),
          ),
        ),
      );
      // 不应崩即可
      await tester.tap(find.byType(AppCircleIconButton));
      await tester.pump();
    });

    testWidgets('size 参数决定按钮直径', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () {},
                size: 64,
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(AppCircleIconButton));
      expect(size.width, 64);
      expect(size.height, 64);
    });
  });
}
