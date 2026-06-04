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

class PoseManager extends StateNotifier<PoseManagerState> {
  final PoseRepository _repository;

  PoseManager(this._repository) : super(const PoseManagerState());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    final local = await _repository.loadLocalPoses();
    final remote = await _repository.syncRemotePoses();
    state = state.copyWith(
      poses: [...local, ...remote],
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