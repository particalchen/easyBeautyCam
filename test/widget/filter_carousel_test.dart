import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/filter/widgets/filter_carousel.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

/// 真实 FilterViewModel + 注入 mock 的 ImageProcessingService / PhotoAlbumWriter
ProviderScope buildScope({
  FilterType selected = FilterType.coral,
  void Function(FilterType)? onSelect,
}) {
  return ProviderScope(
    overrides: [
      filterViewModelProvider.overrideWith(
        (ref) => _TestFilterViewModel(
          selected: selected,
          onSelect: onSelect,
        ),
      ),
    ],
    child: const _TestApp(),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('zh'),
      home: Scaffold(body: FilterCarousel()),
    );
  }
}

class _TestFilterViewModel extends FilterViewModel {
  final FilterType selected;
  final void Function(FilterType)? onSelect;
  _TestFilterViewModel({required this.selected, this.onSelect})
      : super(_NoopService(), _NoopWriter(), _NoopRepo());

  @override
  FilterViewModelState get state =>
      FilterViewModelState(selectedFilter: selected);

  @override
  void selectFilter(FilterType filter) {
    onSelect?.call(filter);
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

void main() {
  group('FilterCarousel', () {
    testWidgets('渲染 5 个滤镜名称（中文）', (tester) async {
      await tester.pumpWidget(buildScope());
      await tester.pumpAndSettle();

      expect(find.text('原图'), findsOneWidget);
      expect(find.text('珊瑚'), findsOneWidget);
      expect(find.text('港风'), findsOneWidget);
      expect(find.text('日系'), findsOneWidget);
      expect(find.text('胶片'), findsOneWidget);
    });

    testWidgets('点击珊瑚触发 onSelect(coral)', (tester) async {
      FilterType? captured;
      await tester.pumpWidget(buildScope(
        onSelect: (f) => captured = f,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('珊瑚'));
      await tester.pumpAndSettle();

      expect(captured, FilterType.coral);
    });

    testWidgets('点击日系触发 onSelect(rixi)', (tester) async {
      FilterType? captured;
      await tester.pumpWidget(buildScope(
        onSelect: (f) => captured = f,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('日系'));
      await tester.pumpAndSettle();

      expect(captured, FilterType.rixi);
    });
  });
}
