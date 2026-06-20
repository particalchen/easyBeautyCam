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
  testWidgets('默认 state：渲染 6 个比例 chip + 重置按钮（IconButton）', (tester) async {
    await _pump(tester, _Stub(const FilterViewModelState()));
    expect(find.text('原图'), findsOneWidget);
    expect(find.text('16:9'), findsOneWidget);
    expect(find.text('4:3'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('3:4'), findsOneWidget);
    expect(find.text('9:16'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byTooltip('重置'), findsOneWidget);
  });

  testWidgets('scale≠1.0 时点重置按钮，scale 被 reset 到 1.0', (tester) async {
    final stub = _Stub(const FilterViewModelState(scale: 2.0));
    await _pump(tester, stub);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(stub.state.scale, 1.0);
  });

  testWidgets('CropRatioBar 重置按钮在标题行最右侧（与 chips 不在同一行）', (tester) async {
    await _pump(tester, _Stub(const FilterViewModelState()));
    final resetRect = tester.getRect(find.byIcon(Icons.refresh));
    // 标题 "裁切比例" 文本的 Y 坐标应当接近重置按钮的 Y（在同一行）
    final labelRect = tester.getRect(find.text('裁切比例'));
    expect(
      (resetRect.center.dy - labelRect.center.dy).abs(),
      lessThan(20), // tolerance: same row
      reason: '重置按钮应与 "裁切比例" 标题在同一行',
    );
    // 重置按钮的 X 应大于标题文本（最右侧）
    expect(
      resetRect.center.dx,
      greaterThan(labelRect.center.dx),
      reason: '重置按钮应位于标题文本右侧',
    );
  });

  testWidgets('CropRatioBar chips 行只有 6 个 chip，无重置', (tester) async {
    await _pump(tester, _Stub(const FilterViewModelState()));
    // 重置按钮的 Y 与 chips 文字的 Y 差距较大（不同行）
    final resetRect = tester.getRect(find.byIcon(Icons.refresh));
    final originalChipRect = tester.getRect(find.text('原图'));
    expect(
      (resetRect.center.dy - originalChipRect.center.dy).abs(),
      greaterThan(15), // different rows
      reason: '重置按钮不应在 chips 行',
    );
  });

  testWidgets('CropRatioBar 比例 chip 图标无外框，6 个 CustomPaint 都是 (26,18)',
      (tester) async {
    await _pump(tester, _Stub(const FilterViewModelState()));
    // 6 个 chip 各画一个 CustomPaint（无外框角标）。
    // IconButton 的 Icons.refresh 也走 CustomPaint，因此按 size 过滤：
    // 只有 chip 的 painter size 是 (26, 18)。
    final paints = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.size == const Size(26, 18),
    );
    expect(paints, findsNWidgets(6),
        reason: '应恰好 6 个 size=(26,18) 的 CustomPaint（每个 chip 一个）');
  });

  testWidgets('CropRatioBar 默认状态下重置按钮 disabled', (tester) async {
    await _pump(tester, _Stub(const FilterViewModelState()));
    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.onPressed, isNull,
        reason: '默认 state（scale=1, translation=zero）下重置按钮应 disabled');
  });

  testWidgets('CropRatioBar scale≠1.0 时重置按钮 enabled 且可点', (tester) async {
    final stub = _Stub(const FilterViewModelState(scale: 2.0));
    await _pump(tester, stub);
    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.onPressed, isNotNull,
        reason: 'scale=2.0 时重置按钮应 enabled');
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(stub.state.scale, 1.0);
  });

  testWidgets('CropRatioBar 选中状态: 原图 chip 在默认 state 下被选中', (tester) async {
    await _pump(tester, _Stub(const FilterViewModelState()));
    // 找到包裹 "原图" 文字的 AnimatedContainer，验证它的 decoration 背景是 primary
    final chipContainerFinder = find.ancestor(
      of: find.text('原图'),
      matching: find.byType(AnimatedContainer),
    );
    expect(chipContainerFinder, findsOneWidget);
    final container = tester.widget<AnimatedContainer>(chipContainerFinder);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, isNotNull,
        reason: '原图 chip 默认选中，应有背景色');
  });
}
