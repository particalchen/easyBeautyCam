import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/core/theme/app_colors.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/features/camera/widgets/zoom_pill_bar.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );
  }

  group('ZoomPillBar - 后置相机（硬件 0.5~5.0）', () {
    testWidgets('渲染 4 颗 pill: 0.5x / 1x / 2x / 3x', (tester) async {
      await tester.pumpWidget(wrap(
        ZoomPillBar(
          cameraIndex: 0,
          minZoom: 0.5,
          maxZoom: 5.0,
          lastSelectedPillZoom: null,
          onSelect: (_) {},
        ),
      ));

      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('点击 2x 触发 onSelect(2.0)', (tester) async {
      double? selected;
      await tester.pumpWidget(wrap(
        ZoomPillBar(
          cameraIndex: 0,
          minZoom: 0.5,
          maxZoom: 5.0,
          lastSelectedPillZoom: null,
          onSelect: (z) => selected = z,
        ),
      ));

      await tester.tap(find.text('2x'));
      expect(selected, 2.0);
    });

    testWidgets('lastSelectedPillZoom=2.0 时，2x pill 渲染为 AppColors.primary（选中态）',
        (tester) async {
      await tester.pumpWidget(wrap(
        ZoomPillBar(
          cameraIndex: 0,
          minZoom: 0.5,
          maxZoom: 5.0,
          lastSelectedPillZoom: 2.0,
          onSelect: (_) {},
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

    testWidgets('lastSelectedPillZoom=null 时所有 pill 都不高亮（即便 currentZoom 等于某 pill）',
        (tester) async {
      // 即使 currentZoom 已是 2.0，但因为 lastSelectedPillZoom=null（来自 pinch），
      // pill 应该全部取消高亮
      await tester.pumpWidget(wrap(
        ZoomPillBar(
          cameraIndex: 0,
          minZoom: 0.5,
          maxZoom: 5.0,
          lastSelectedPillZoom: null,
          onSelect: (_) {},
        ),
      ));

      // 2x pill 的 AnimatedContainer 背景色应该是 transparent
      final containerFinder = find.ancestor(
        of: find.text('2x'),
        matching: find.byType(AnimatedContainer),
      );
      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.transparent,
          reason: 'lastSelectedPillZoom=null 时 pill 不应高亮');
    });
  });

  group('ZoomPillBar - 硬件范围过滤', () {
    testWidgets('minZoom=1.0 时 0.5x pill 被过滤掉', (tester) async {
      await tester.pumpWidget(wrap(
        ZoomPillBar(
          cameraIndex: 0,
          minZoom: 1.0,
          maxZoom: 5.0,
          lastSelectedPillZoom: null,
          onSelect: (_) {},
        ),
      ));

      expect(find.text('0.5x'), findsNothing);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('maxZoom=2.0 时 3x pill 被过滤掉', (tester) async {
      await tester.pumpWidget(wrap(
        ZoomPillBar(
          cameraIndex: 0,
          minZoom: 0.5,
          maxZoom: 2.0,
          lastSelectedPillZoom: null,
          onSelect: (_) {},
        ),
      ));

      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('3x'), findsNothing);
    });
  });

  group('ZoomPillBar - 前置相机', () {
    testWidgets('只渲染 1 颗 1x pill', (tester) async {
      await tester.pumpWidget(wrap(
        ZoomPillBar(
          cameraIndex: 1,
          minZoom: 0.5,
          maxZoom: 5.0,
          lastSelectedPillZoom: null,
          onSelect: (_) {},
        ),
      ));

      expect(find.text('1x'), findsOneWidget);
      expect(find.text('0.5x'), findsNothing);
      expect(find.text('2x'), findsNothing);
      expect(find.text('3x'), findsNothing);
    });
  });
}
