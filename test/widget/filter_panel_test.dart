import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/core/theme/app_colors.dart';
import 'package:easy_beauty_cam/core/theme/app_radii.dart';
import 'package:easy_beauty_cam/features/filter/filter_panel.dart';
import 'package:easy_beauty_cam/features/filter/filter_view_model.dart';
import 'package:easy_beauty_cam/features/photo_album/app_photo_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';
import 'package:easy_beauty_cam/services/image_processing_service.dart';
import 'package:easy_beauty_cam/services/photo_album_writer.dart';

class _StubRepo extends FilterViewModel {
  _StubRepo({String? imagePath, Uint8List? previewBytes})
      : super(
          _NoopService(),
          _NoopWriter(),
          _NoopRepo(),
        ) {
    if (imagePath != null) {
      state = state.copyWith(imagePath: imagePath, previewBytes: previewBytes);
    }
  }

  /// 测试用：绕过 debounce 立即设置 previewBytes
  void debugSetPreview(String path, Uint8List bytes) {
    state = state.copyWith(imagePath: path, previewBytes: bytes);
  }
}

/// 9x16 透明 PNG（竖向，模拟真机 portrait 照片的极端长宽比）
final _kTallPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x00, 0x10,
  0x08, 0x06, 0x00, 0x00, 0x00, 0xC4, 0x48, 0x55, 0x43, 0x00, 0x00, 0x00,
  0x0F, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x18, 0x05, 0xA3,
  0x80, 0x7A, 0x00, 0x00, 0x02, 0x50, 0x00, 0x01, 0x26, 0xC0, 0x37, 0x49,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _NoopService extends ImageProcessingService {
  @override
  Future<Uint8List> processImage(
    Uint8List imageBytes, {
    FilterType filter = FilterType.original,
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
      expect(find.text('裁切'), findsOneWidget);
      expect(find.text('原图'), findsOneWidget);
      expect(find.text('珊瑚'), findsOneWidget);
    });

    testWidgets('切到裁切 tab 显示 6 个比例按钮 + 切比例触发 setCropRatio', (tester) async {
      await pumpPanel(tester);

      // 切到「裁切」tab
      await tester.tap(find.text('裁切'));
      await tester.pumpAndSettle();

      // 6 个比例按钮全在
      expect(find.text('原图'), findsOneWidget);
      expect(find.text('16:9'), findsOneWidget);
      expect(find.text('4:3'), findsOneWidget);
      expect(find.text('1:1'), findsOneWidget);
      expect(find.text('3:4'), findsOneWidget);
      expect(find.text('9:16'), findsOneWidget);

      // 切到 1:1 不会崩（验证 onTap 链路 + setCropRatio 调用）
      await tester.tap(find.text('1:1'));
      await tester.pumpAndSettle();
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

    // 回归：2026-06-19 真机报 RenderFlex overflowed by 144 pixels
    // 原因：_PhotoPreview 在 Image.memory 之前没限高度，竖向照片按
    // intrinsic aspect 把 bottomSheet 撑爆。修法：maxHeight = 屏幕高 45%。
    testWidgets('9:16 竖向 previewBytes 不溢出（800 屏幕 + tall png）', (tester) async {
      // 设置大屏幕，模拟竖向长图容易触发的场景
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 9:16 竖向 PNG，模拟真机 portrait 照片
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filterViewModelProvider.overrideWith((ref) {
              final vm = _StubRepo();
              vm.debugSetPreview('/tmp/test.jpg', _kTallPng);
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
            home: Scaffold(body: Material(child: FilterPanel())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 关键断言：没有 RenderFlex overflow 异常被框架吞掉
      expect(tester.takeException(), isNull);
      // 预览图渲染成功
      expect(find.byType(Image), findsWidgets);
    });

    // Task 5: FilterPanel 全屏布局改造 - 不再是 BottomSheet
    testWidgets('FilterPanel 全屏布局：无 BottomSheet 拖动条', (tester) async {
      // 给一个足够大的 viewport，避免 TabBar/Preview 在小空间内被裁剪到测试不到拖动条
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filterViewModelProvider.overrideWith((ref) {
              final vm = _StubRepo();
              vm.debugSetPreview('/tmp/test.jpg', _kTallPng);
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
            home: Scaffold(body: Material(child: FilterPanel())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 不应再有 36x4 的灰色拖动条
      final dragBar = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 36 &&
            w.constraints?.maxHeight == 4,
      );
      expect(dragBar, findsNothing,
          reason: 'FilterPanel 全屏后不应有 BottomSheet 拖动条');
    });

    testWidgets('FilterPanel 全屏布局：顶层是 Scaffold 不是 BottomSheet 圆角容器',
        (tester) async {
      await pumpPanel(tester);

      // 老的 BottomSheet 圆角容器：
      // Container(decoration: BoxDecoration(color: AppColors.overlayBg, borderRadius: AppRadii.sheetTop))
      // 全屏后应该不再存在
      final sheetTopContainer = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.overlayBg &&
            (w.decoration as BoxDecoration).borderRadius ==
                AppRadii.sheetTop,
      );
      expect(sheetTopContainer, findsNothing,
          reason: 'FilterPanel 全屏后不应再有 sheetTop 圆角容器');
    });

    testWidgets('FilterPanel 顶部栏包含 "编辑" 标题、取消和保存按钮',
        (tester) async {
      await pumpPanel(tester);

      // 默认 state.isProcessing == false，所以保存按钮显示文字而非 spinner
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });
  });
}
