import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'features/pose_library/pose_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 启动时同步远程姿势（非阻塞，失败不影响 App启动）
  try {
    final poseRepo = PoseRepository();
    // 异步同步，不阻塞 UI
    poseRepo.syncRemotePoses();
  } catch (e) {
    // 忽略同步错误
  }

  runApp(const ProviderScope(child: EasyBeautyCamApp()));
}