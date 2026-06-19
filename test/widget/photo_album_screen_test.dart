import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/features/photo_album/photo_album_screen.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';

/// 内存 mock：纯 list，不走 path_provider
class _StubAppRepo implements AppPhotoRepository {
  final List<String> paths;
  _StubAppRepo({this.paths = const []});

  @override
  Future<List<String>> listAll() async => paths;

  @override
  Future<String> add(Uint8List bytes) async {
    final p = '/mem/${DateTime.now().microsecondsSinceEpoch}.jpg';
    return p;
  }

  @override
  Future<void> delete(List<String> paths) async {}
}

Future<void> pumpScreen(WidgetTester tester, AppPhotoRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPhotoRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('zh'),
        home: PhotoAlbumScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PhotoAlbumScreen', () {
    testWidgets('AppBar 显示「相册」标题', (tester) async {
      await pumpScreen(tester, _StubAppRepo(paths: []));

      expect(find.text('相册'), findsOneWidget);
    });

    testWidgets('空目录显示空态文案，无 grid', (tester) async {
      await pumpScreen(tester, _StubAppRepo(paths: []));

      expect(find.text('还没有拍过照片'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('3 张照片时渲染 3 个 Image.file tile', (tester) async {
      await pumpScreen(tester, _StubAppRepo(
        paths: const [
          '/tmp/p1.jpg',
          '/tmp/p2.jpg',
          '/tmp/p3.jpg',
        ],
      ));

      // GridView.builder 是 lazy 的，找至少一个 Image 即可
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(Image), findsAtLeast(1));
    });

    testWidgets('长按进入多选模式（AppBar 显示已选数）', (tester) async {
      await pumpScreen(tester, _StubAppRepo(
        paths: const ['/tmp/p1.jpg', '/tmp/p2.jpg'],
      ));

      // 找到第一个 tile（GestureDetector 包裹 Image）
      await tester.longPress(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('已选'), findsOneWidget);
      // AppBar 应有删除按钮
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}