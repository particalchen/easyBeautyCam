import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/filter/filter_panel.dart';
import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

class _StubRepo extends FilterViewModel {
  _StubRepo({String? imagePath})
      : super(_NoopService(), _NoopWriter(), _NoopRepo()) {
    if (imagePath != null) {
      state = state.copyWith(imagePath: imagePath);
    }
  }
}

class _NoopService extends ImageProcessingService {
  @override
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
  }) async {
    return imageBytes;
  }
}

class _NoopWriter implements PhotoAlbumWriter {
  @override
  Future<void> saveImage(Uint8List bytes, {required String filename}) async {}
}

class _NoopRepo implements AppPhotoRepository {
  @override
  Future<List<String>> listAll() async => const [];
  @override
  Future<String> add(Uint8List bytes) async =>
      '/noop/${DateTime.now().microsecondsSinceEpoch}.jpg';
  @override
  Future<void> delete(List<String> paths) async {}
}

Future<void> pumpPanel(
  WidgetTester tester, {
  String? imagePath,
  Future<String?> Function()? onSave,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        filterViewModelProvider.overrideWith((ref) {
          final vm = _StubRepo(imagePath: imagePath);
          return vm;
        }),
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
        // Modal 上下文提供 Material；测试中用 Material 显式包一层避免 Slider 找不到 ancestor
        home: Scaffold(
          body: Material(child: FilterPanel()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FilterPanel', () {
    testWidgets('渲染顶部栏：取消 / 编辑 / 保存', (tester) async {
      await pumpPanel(tester);

      expect(find.text('取消'), findsOneWidget);
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('默认 tab 显示 FilterCarousel（5 个滤镜名）', (tester) async {
      await pumpPanel(tester);

      expect(find.text('滤镜'), findsOneWidget);
      expect(find.text('美颜'), findsOneWidget);
      expect(find.text('原图'), findsOneWidget);
      expect(find.text('珊瑚'), findsOneWidget);
    });

    testWidgets('切到美颜 tab 显示 BeautySlider（3 个标签）', (tester) async {
      await pumpPanel(tester);

      // 切到「美颜」tab
      await tester.tap(find.text('美颜'));
      await tester.pumpAndSettle();

      expect(find.text('磨皮'), findsOneWidget);
      expect(find.text('美白'), findsOneWidget);
      expect(find.text('瘦脸'), findsOneWidget);
    });

    testWidgets('无 imagePath 时不渲染图片预览', (tester) async {
      await pumpPanel(tester);

      // 找 Container（_buildPhotoPreview 渲染的）—— 简单做法是看是否还有 Image.file
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('点击取消触发 Navigator.pop', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      bool popped = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filterViewModelProvider.overrideWith((ref) => _StubRepo()),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const Scaffold(
                            body: Material(child: FilterPanel()),
                          ),
                        ),
                      );
                      popped = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });
  });
}
