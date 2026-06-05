import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../features/pose_library/pose_model.dart';

class PoseDownloadService {
  static const String _baseUrl = 'https://example.com/poses';

  Future<List<PoseModel>> fetchRemotePoses() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/poses.json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => PoseModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // 网络异常或超时，返回空列表，不阻塞 App启动
      return [];
    }
  }

  Future<void> downloadPose(PoseModel pose, String localPath) async {
    if (pose.remoteUrl == null) return;
    try {
      final response = await http
          .get(Uri.parse(pose.remoteUrl!))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      // 下载失败，忽略
    }
  }

  Future<String> get localPoseDirectory async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/poses';
  }
}