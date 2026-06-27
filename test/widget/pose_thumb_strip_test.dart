import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easy_beauty_cam/features/camera/widgets/pose_thumb_strip.dart';
import 'package:easy_beauty_cam/features/pose_library/pose_manager.dart';
import 'package:easy_beauty_cam/features/pose_library/pose_model.dart';
import 'package:easy_beauty_cam/features/pose_library/pose_repository.dart';
import 'package:easy_beauty_cam/l10n/generated/app_localizations.dart';

const _testPoses = [
  PoseModel(
    id: 'local_01',
    name: '户外姿势1',
    category: 'outdoor',
    assetPath: 'resources/poses/pose_outdoor_01.png',
    isLocal: true,
  ),
  PoseModel(
    id: 'local_02',
    name: '户外姿势2',
    category: 'outdoor',
    assetPath: 'resources/poses/pose_outdoor_02.png',
    isLocal: true,
  ),
  PoseModel(
    id: 'local_03',
    name: '户外姿势3',
    category: 'outdoor',
    assetPath: 'resources/poses/pose_outdoor_03.png',
    isLocal: true,
  ),
  PoseModel(
    id: 'local_04',
    name: '户外姿势4',
    category: 'outdoor',
    assetPath: 'resources/poses/pose_outdoor_04.png',
    isLocal: true,
  ),
  PoseModel(
    id: 'local_05',
    name: '户外姿势5',
    category: 'outdoor',
    assetPath: 'resources/poses/pose_outdoor_05.png',
    isLocal: true,
  ),
  PoseModel(
    id: 'local_06',
    name: '户外姿势6',
    category: 'outdoor',
    assetPath: 'resources/poses/pose_outdoor_06.png',
    isLocal: true,
  ),
];

class _TestPoseManager extends PoseManager {
  _TestPoseManager({required List<PoseModel> poses, int selectedIndex = 0})
      : super(_FakeRepo()) {
    state = PoseManagerState(poses: poses, selectedIndex: selectedIndex);
  }

  @override
  void selectPose(int index) {
    state = state.copyWith(selectedIndex: index);
  }
}

class _FakeRepo implements PoseRepository {
  @override
  Future<List<PoseModel>> loadLocalPoses() async => const [];
  @override
  Future<void> saveLocalPoses(List<PoseModel> poses) async {}
  @override
  Future<List<PoseModel>> syncRemotePoses() async => const [];
  @override
  Future<void> downloadAndCachePose(PoseModel pose) async {}
}

ProviderScope buildScope({int selectedIndex = 0}) {
  return ProviderScope(
    overrides: [
      poseManagerProvider.overrideWith(
        (ref) => _TestPoseManager(
          poses: _testPoses,
          selectedIndex: selectedIndex,
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
      home: Scaffold(body: PoseThumbStrip()),
    );
  }
}

/// 找 ListView 里每个 Image.asset 的 semantic label 对应的 widget。
/// 我们用 key 标记每张缩略图，再用 find.byKey 找。
/// 但更简单的：直接断言 Image widget 存在 N 个并对比路径。

void main() {
  group('PoseThumbStrip（Day 3 默认显示 -res 切换）', () {
    testWidgets('默认 selectedIndex=0：第 1 张显示 pose 轮廓图，其余 5 张显示 -res 原图',
        (tester) async {
      await tester.pumpWidget(buildScope(selectedIndex: 0));
      await tester.pump();

      final imageWidgets = tester.widgetList<Image>(find.byType(Image));
      final paths = imageWidgets
          .map((w) => (w.image as AssetImage).assetName)
          .toList();

      expect(paths.length, 6);
      // 选中 (index=0)：assetPath
      expect(paths[0], 'resources/poses/pose_outdoor_01.png');
      // 未选中 (index=1..5)：-res
      expect(paths[1], 'resources/poses/pose_outdoor_02-res.png');
      expect(paths[2], 'resources/poses/pose_outdoor_03-res.png');
      expect(paths[3], 'resources/poses/pose_outdoor_04-res.png');
      expect(paths[4], 'resources/poses/pose_outdoor_05-res.png');
      expect(paths[5], 'resources/poses/pose_outdoor_06-res.png');
    });

    testWidgets('点击第 2 张 → 第 2 张切换为 pose 轮廓图，第 1 张切回 -res',
        (tester) async {
      await tester.pumpWidget(buildScope(selectedIndex: 0));
      await tester.pump();

      // 点击第 2 张缩略图
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pumpAndSettle();

      final imageWidgets = tester.widgetList<Image>(find.byType(Image));
      final paths = imageWidgets
          .map((w) => (w.image as AssetImage).assetName)
          .toList();

      expect(paths.length, 6);
      // 现在第 2 张被选中：显示 pose 轮廓
      expect(paths[1], 'resources/poses/pose_outdoor_02.png');
      // 第 1 张变回 -res
      expect(paths[0], 'resources/poses/pose_outdoor_01-res.png');
    });

    testWidgets('远程 pose (无 -res)：未选中时回退到 assetPath',
        (tester) async {
      const remotePose = PoseModel(
        id: 'remote_01',
        name: '远端',
        category: 'x',
        assetPath: 'https://cdn.example.com/p.png',
        isLocal: false,
        remoteUrl: 'https://cdn.example.com/p.png',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poseManagerProvider.overrideWith(
              (ref) => _TestPoseManager(
                poses: [remotePose, _testPoses[0]],
                selectedIndex: 1,
              ),
            ),
          ],
          child: const _TestApp(),
        ),
      );
      await tester.pump();

      final imageWidgets = tester.widgetList<Image>(find.byType(Image));
      final paths = imageWidgets
          .map((w) => (w.image is AssetImage)
              ? (w.image as AssetImage).assetName
              : w.image.toString())
          .toList();

      expect(paths.length, 2);
      // 远程未选中：referenceAssetPath 是 null → 回退到 assetPath (URL)
      expect(paths[0], 'https://cdn.example.com/p.png');
    });
  });
}
