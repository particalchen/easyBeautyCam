import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pose_model.dart';
import 'pose_repository.dart';

final poseRepositoryProvider = Provider<PoseRepository>((ref) => PoseRepository());

final poseManagerProvider = StateNotifierProvider<PoseManager, PoseManagerState>((ref) {
  return PoseManager(ref.watch(poseRepositoryProvider));
});

class PoseManagerState {
  final List<PoseModel> poses;
  final int selectedIndex;
  final bool isLoading;

  const PoseManagerState({
    this.poses = const [],
    this.selectedIndex = 0,
    this.isLoading = false,
  });

  PoseManagerState copyWith({
    List<PoseModel>? poses,
    int? selectedIndex,
    bool? isLoading,
  }) {
    return PoseManagerState(
      poses: poses ?? this.poses,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 内置默认姿势（resources/poses/ 目录下的图片）
const List<PoseModel> _defaultLocalPoses = [
  PoseModel(
    id: 'local_01',
    name: '户外姿势1',
    category: 'outdoor',
    assetPath: 'resources/poses/pose_outdoor_01.png',
    isLocal: true,
  ),
];

class PoseManager extends StateNotifier<PoseManagerState> {
  final PoseRepository _repository;

  PoseManager(this._repository) : super(PoseManagerState(
    poses: _defaultLocalPoses,
  ));

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    final local = await _repository.loadLocalPoses();
    final remote = await _repository.syncRemotePoses();
    //合并：默认内置 + 用户本地添加 + 远程获取
    final allPoses = [..._defaultLocalPoses, ...local, ...remote];
    state = state.copyWith(
      poses: allPoses,
      isLoading: false,
    );
  }

  void selectPose(int index) {
    if (index >= 0 && index < state.poses.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }

  Future<void> addCustomPose(PoseModel pose) async {
    final updated = [...state.poses, pose];
    state = state.copyWith(poses: updated);
    await _repository.saveLocalPoses(updated);
  }
}