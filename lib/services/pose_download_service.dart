import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../features/pose_library/pose_model.dart';

class PoseDownloadService {
  static const String _baseUrl = 'https://example.com/poses';

  Future<List<PoseModel>> fetchRemotePoses() async {
    final response = await http.get(Uri.parse('$_baseUrl/poses.json'));
    if (response.statusCode != 200) return [];

    final List<dynamic> data = json.decode(response.body);
    return data.map((e) => PoseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> downloadPose(PoseModel pose, String localPath) async {
    if (pose.remoteUrl == null) return;
    final response = await http.get(Uri.parse(pose.remoteUrl!));
    if (response.statusCode == 200) {
      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);
    }
  }

  Future<String> get localPoseDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/poses';
  }
}