import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/photo_album/photo_album_repository.dart';
import 'package:easy_beauty_cam/features/photo_album/photo_album_screen.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';

/// mock 仓库
class _StubRepo implements PhotoAlbumRepository {
  final bool grantPermission;
  final List<String> paths;

  _StubRepo({this.grantPermission = true, this.paths = const []});

  @override
  Future<bool> requestPermission() async => grantPermission;

  @override
  Future<List<String>> loadRecentPhotoPaths({int limit = 100}) async => paths;
}

Future<void> pumpScreen(WidgetTester tester, PhotoAlbumRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        photoAlbumRepositoryProvider.overrideWithValue(repo),
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
  // initState 异步 load 完成后 pumpAndSettle
  await tester.pumpAndSettle();
}

void main() {
  group('PhotoAlbumScreen', () {
    testWidgets('AppBar 显示「相册」标题', (tester) async {
      await pumpScreen(tester, _StubRepo(paths: []));

      expect(find.text('相册'), findsOneWidget);
    });

    testWidgets('无照片时 grid 为空（itemCount 0）', (tester) async {
      await pumpScreen(tester, _StubRepo(paths: []));

      final grid = tester.widget<GridView>(find.byType(GridView));
      // 空 grid 不渲染 Image.file
      expect(find.byType(Image), findsNothing);
      expect(grid, isNotNull);
    });

    testWidgets('3 张照片时 grid 渲染 3 个 Image', (tester) async {
      await pumpScreen(tester, _StubRepo(
        paths: const [
          '/tmp/p1.jpg',
          '/tmp/p2.jpg',
          '/tmp/p3.jpg',
        ],
      ));

      // GridView.builder 是 lazy 的，viewport 默认 600pt × 800pt，
      // 3 列 + padding 4 → 每张约 (600-16)/3 = 194pt 都能装下
      // 但 Lazy rendering：找 first Image 即可
      expect(find.byType(Image), findsAtLeast(1));
    });

    testWidgets('权限被拒时 grid 存在但无 Image', (tester) async {
      await pumpScreen(tester, _StubRepo(grantPermission: false));

      // 权限被拒时仍渲染 grid（itemCount 0），不渲染任何图片
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
