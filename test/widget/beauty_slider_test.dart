import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/filter/widgets/beauty_slider.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

class _StubViewModel extends FilterViewModel {
  final FilterViewModelState _state;
  final void Function(double)? onSmooth;
  final void Function(double)? onWhiten;
  final void Function(double)? onSlim;

  _StubViewModel({
    required FilterViewModelState state,
    this.onSmooth,
    this.onWhiten,
    this.onSlim,
  })  : _state = state,
        super(_NoopService(), _NoopWriter(), _NoopRepo());

  @override
  FilterViewModelState get state => _state;

  @override
  void setSmooth(double value) => onSmooth?.call(value);

  @override
  void setWhiten(double value) => onWhiten?.call(value);

  @override
  void setSlim(double value) => onSlim?.call(value);
}

class _NoopService extends ImageProcessingService {
  @override
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
    double smooth = 0,
    double whiten = 0,
    double slim = 0,
    img.Image? mask,
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
  Future<String> add(Uint8List bytes) async => '/noop/${DateTime.now().microsecondsSinceEpoch}.jpg';
  @override
  Future<void> delete(List<String> paths) async {}
}

ProviderScope buildScope({
  double smooth = 30,
  double whiten = 20,
  double slim = 0,
  void Function(double)? onSmooth,
  void Function(double)? onWhiten,
  void Function(double)? onSlim,
}) {
  return ProviderScope(
    overrides: [
      filterViewModelProvider.overrideWith(
        (ref) => _StubViewModel(
          state: FilterViewModelState(
            smooth: smooth,
            whiten: whiten,
            slim: slim,
          ),
          onSmooth: onSmooth,
          onWhiten: onWhiten,
          onSlim: onSlim,
        ),
      ),
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
      home: Scaffold(body: BeautySlider()),
    ),
  );
}

void main() {
  group('BeautySlider', () {
    testWidgets('渲染三档标签 + 当前值', (tester) async {
      await tester.pumpWidget(buildScope());
      await tester.pumpAndSettle();

      expect(find.text('磨皮'), findsOneWidget);
      expect(find.text('美白'), findsOneWidget);
      expect(find.text('瘦脸'), findsOneWidget);
      expect(find.text('30'), findsOneWidget); // smooth default
      expect(find.text('20'), findsOneWidget); // whiten default
      expect(find.text('0'), findsOneWidget); // slim default
    });

    testWidgets('3 个 Slider 组件可拖动', (tester) async {
      await tester.pumpWidget(buildScope());
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNWidgets(3));
    });

    testWidgets('state 改变时数字显示同步', (tester) async {
      await tester.pumpWidget(buildScope(smooth: 75));
      await tester.pumpAndSettle();

      expect(find.text('75'), findsOneWidget);
    });
  });
}
