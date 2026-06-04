import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'features/pose_library/pose_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 启动时同步远程姿势
  final poseRepo = PoseRepository();
  await poseRepo.syncRemotePoses();

  runApp(const ProviderScope(child: EasyBeautyCamApp()));
}