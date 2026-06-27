// 隔离测试：直接验证 Navigator.push(MaterialPageRoute(builder: FilterPanel))
// 在 GoRouter 上下文里能否成功 mount。
//
// 不挂 CameraScreen —— 直接从 minimal app mount FilterPanel。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/filter/filter_panel.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

class _NoopService extends ImageProcessingService {
  @override
  Future<Uint8List> processImage(Uint8List imageBytes,
      {FilterType filter = FilterType.original}) async {
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
  Future<String> add(Uint8List bytes) async => '/noop';
  @override
  Future<void> delete(List<String> paths) async {}
}

void main() {
  testWidgets('Navigator.push(FilterPanel) 在 GoRouter 上下文里能 mount', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('root'))),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageProcessingServiceProvider.overrideWithValue(_NoopService()),
          photoAlbumWriterProvider.overrideWithValue(_NoopWriter()),
          appPhotoRepositoryProvider.overrideWithValue(_NoopRepo()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('root'), findsOneWidget);

    // 从 root 触发 push
    final rootContext = tester.element(find.text('root'));
    final pushFuture = Navigator.of(rootContext).push<String>(
      MaterialPageRoute(
        builder: (_) => const FilterPanel(),
        fullscreenDialog: true,
      ),
    );

    // 推几帧让 FilterPanel mount
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('取消'), findsOneWidget,
        reason: 'FilterPanel 应已 mount（看到顶部栏文案）');
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);

    // 清理：直接 dismiss，忽略返回值
    pushFuture.then((_) {}).ignore();
  });
}