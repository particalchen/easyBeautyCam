// 测试 PoseLongPressPreview 在不同 long-press 状态下的渲染行为

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/camera/state/pose_long_press_provider.dart';
import 'package:easy_beauty_cam/features/camera/widgets/pose_long_press_preview.dart';
import 'package:easy_beauty_cam/features/pose_library/pose_model.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';

const _localPose = PoseModel(
  id: 'local_01',
  name: '户外姿势1',
  category: 'outdoor',
  assetPath: 'resources/poses/pose_outdoor_01.png',
  isLocal: true,
);

const _remotePose = PoseModel(
  id: 'remote_01',
  name: '远端',
  category: 'x',
  assetPath: 'https://cdn.example.com/p.png',
  isLocal: false,
  remoteUrl: 'https://cdn.example.com/p.png',
);

Widget _wrap({PoseModel? pressed}) {
  return ProviderScope(
    overrides: [
      poseLongPressProvider.overrideWith((ref) => _StaticNotifier(pressed)),
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
      home: Scaffold(
        // Positioned.fill 要求父级是 Stack；模拟真实使用场景
        body: Stack(
          fit: StackFit.expand,
          children: [PoseLongPressPreview()],
        ),
      ),
    ),
  );
}

class _StaticNotifier extends PoseLongPressNotifier {
  _StaticNotifier(this._initial) {
    state = _initial;
  }
  final PoseModel? _initial;
}

void main() {
  group('PoseLongPressPreview', () {
    testWidgets('state 为 null → 不渲染 Image，只剩空 SizedBox', (tester) async {
      await tester.pumpWidget(_wrap(pressed: null));
      await tester.pump();

      expect(find.byType(Image), findsNothing);
    });

    testWidgets('state 是本地 pose → 渲染 -res 参考图（半透明 0.5）', (tester) async {
      await tester.pumpWidget(_wrap(pressed: _localPose));
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName,
          'resources/poses/pose_outdoor_01-res.png',
          reason: '本地 pose 优先取 referenceAssetPath');

      // 外层 Opacity 应是 0.5
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.5);

      // 无颜色叠加（与 PoseOverlay 的白色轮廓不同）
      expect(image.color, isNull);
      expect(image.colorBlendMode, isNull);
    });

    testWidgets('state 是远端 pose (无 -res) → 回退到 assetPath', (tester) async {
      await tester.pumpWidget(_wrap(pressed: _remotePose));
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName,
          'https://cdn.example.com/p.png',
          reason: '无 referenceAssetPath 时回退到 assetPath');
    });
  });
}