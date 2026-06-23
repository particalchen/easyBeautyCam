import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'dart:typed_data';

import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/filter/widgets/filter_carousel.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/services/face_detection_service.dart';
import 'package:easy_beauty_cam/services/face_mask_builder.dart';
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
      : super(_NoopService(), _NoopWriter(), _NoopRepo(), _NoopFaceDetector(), _NoopMaskBuilder());

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
  Future<String> add(Uint8List bytes) async =>
      '/noop/${DateTime.now().microsecondsSinceEpoch}.jpg';
  @override
  Future<void> delete(List<String> paths) async {}
}

class _NoopFaceDetector extends FaceDetectionService {
  _NoopFaceDetector() : super(detectFn: (path, bytes) async => const []);
}

class _NoopMaskBuilder extends FaceMaskBuilder {}

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

    // 回归：2026-06-20 真机截图显示选中边框撑满 carousel 高度
    // 原因：border 加在外层 AnimatedContainer（被父 SizedBox 100pt 撑高）上
    // 修法：border 移到内层 50×50 按钮；外层只负责宽度间距
    testWidgets('选中边框只包住 50×50 按钮，不撑满高度', (tester) async {
      await tester.pumpWidget(buildScope(selected: FilterType.coral));
      await tester.pumpAndSettle();

      // FilterCarousel 里的 5 个滤镜都各自有一个 50×50 AnimatedContainer（带颜色块）
      // 选中时这个 AnimatedContainer 还带 Border.all
      final allButtons = find.byType(AnimatedContainer);
      expect(allButtons, findsAtLeastNWidgets(5));

      // 「珊瑚」对应的那个应该是 50×50（不再被父级撑到 70×100）
      // 找所有 AnimatedContainer 并断言没有任何一个高度 = 100
      final heights = tester.widgetList<AnimatedContainer>(allButtons)
          .map((w) => tester.getSize(find.byWidget(w)).height)
          .toSet();
      expect(heights.contains(100), isFalse,
          reason: 'FilterCarousel 里的 AnimatedContainer 不应被撑到 100pt 高');
    });
  });
}
