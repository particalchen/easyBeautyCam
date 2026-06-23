import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/camera/widgets/app_circle_icon_button.dart';
import 'package:easy_beauty_cam/core/theme/app_colors.dart';

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

    testWidgets('渲染传入的 icon 子树', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () {},
                size: 56,
              ),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AppCircleIconButton),
          matching: find.byIcon(Icons.photo_library_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('bordered: false 渲染时 Material 是 CircleBorder(BorderSide.none)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () {},
                size: 56,
                bordered: false,
              ),
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(find.descendant(
        of: find.byType(AppCircleIconButton),
        matching: find.byType(Material),
      ));
      final shape = material.shape;
      expect(shape, isA<CircleBorder>());
      // 关键：无描边时 BorderSide.none
      expect((shape! as CircleBorder).side, BorderSide.none);
    });

    testWidgets('bordered: true（默认）有 1.5pt 描边', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () {},
                size: 56,
              ),
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(find.descendant(
        of: find.byType(AppCircleIconButton),
        matching: find.byType(Material),
      ));
      final side = (material.shape! as CircleBorder).side;
      expect(side.width, 1.5);
      expect(side.color, AppColors.onPrimary);
    });

    testWidgets('iconOpacity 改变 icon color 的 alpha', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCircleIconButton(
                icon: Icons.photo_library_outlined,
                onPressed: () {},
                size: 56,
                iconOpacity: 0.75,
              ),
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.photo_library_outlined));
      // Flutter 新版 Color API: `.a` 是 double ∈ [0, 1]（不是 0~255）
      expect(icon.color!.a, closeTo(0.75, 0.01));
    });
  });
}
