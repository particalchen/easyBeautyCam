import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/filter/widgets/crop_ratio_bar.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

class _Stub extends FilterViewModel {
  _Stub(FilterViewModelState s)
      : super(_NoopService(), _NoopWriter(), _NoopRepo()) {
    state = s;
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
  }) async => imageBytes;

  @override
  Future<Uint8List> applyTransform(
    Uint8List imageBytes, {
    required double scale,
    required Offset translation,
    required double? targetRatio,
  }) async => imageBytes;
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

Future<void> _pump(WidgetTester tester, FilterViewModel stub) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      filterViewModelProvider.overrideWith((_) => stub),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: const Scaffold(body: Material(child: CropRatioBar())),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('默认 state：渲染 6 个比例 chip + 重置按钮', (tester) async {
    await _pump(tester, _Stub(const FilterViewModelState()));
    expect(find.text('自由'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('重置'), findsOneWidget);
  });

  testWidgets('scale≠1.0 时点重置按钮，scale 被 reset 到 1.0', (tester) async {
    final stub = _Stub(const FilterViewModelState(scale: 2.0));
    await _pump(tester, stub);
    await tester.tap(find.text('重置'));
    await tester.pump();
    expect(stub.state.scale, 1.0);
  });
}
