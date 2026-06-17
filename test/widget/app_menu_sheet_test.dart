import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_beauty_cam/features/camera/widgets/app_menu_sheet.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';

void main() {
  group('AppMenuSheet', () {
    testWidgets('renders 3 menu items: 姿势库 / 设置 / 关于', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: _delegates,
          supportedLocales: _locales,
          locale: Locale('zh'),
          home: Scaffold(
            body: AppMenuSheet(),
          ),
        ),
      );

      expect(find.text('姿势库'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
    });

    testWidgets('点击 姿势库 触发 onPoseLibrary', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _delegates,
          supportedLocales: _locales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: AppMenuSheet(
              onPoseLibrary: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('姿势库'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('点击 设置 触发 onSettings', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _delegates,
          supportedLocales: _locales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: AppMenuSheet(
              onSettings: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('点击 关于 触发 onAbout', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _delegates,
          supportedLocales: _locales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: AppMenuSheet(
              onAbout: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}

// 复用项目本身的 l10n delegates
const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _locales = AppLocalizations.supportedLocales;
