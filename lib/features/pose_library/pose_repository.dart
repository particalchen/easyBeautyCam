import 'package:hive/hive.dart';
import 'pose_model.dart';
import '../../services/pose_download_service.dart';

class PoseRepository {
  final PoseDownloadService _downloadService = PoseDownloadService();

  Future<List<PoseModel>> loadLocalPoses() async {
    final box = await Hive.openBox<List>('poses');
    final List<dynamic>? stored = box.get('local_poses');
    if (stored != null) {
      return stored.cast<PoseModel>();
    }
    return [];
  }

  Future<void> saveLocalPoses(List<PoseModel> poses) async {
    final box = await Hive.openBox<List>('poses');
    await box.put('local_poses', poses);
  }

  Future<List<PoseModel>> syncRemotePoses() async {
    final remote = await _downloadService.fetchRemotePoses();
    return remote;
  }

  Future<void> downloadAndCachePose(PoseModel pose) async {
    final localDir = await _downloadService.localPoseDirectory;
    final localPath = '$localDir/${pose.id}.png';
    await _downloadService.downloadPose(pose, localPath);
  }
}