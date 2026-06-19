import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// App 内照片仓库 —— 只记录「这个 app 拍过」的照片，跟 device album 区分
///
/// 存储方式：
/// - 实际照片文件 → `<documents>/app_photos/easy_beauty_<ts>.jpg`
/// - 路径索引 → `<documents>/app_photos/manifest.json`
///
/// 设计理由：
/// - F 阶段最初用 photo_manager 读 device album → 跟用户预期不符（应该只显示本 app 拍的）
/// - 用本地文件 + JSON 索引够轻量，不用 hive，避免额外抽象
abstract class AppPhotoRepository {
  /// 列所有 app 内照片（最新在前），跳过磁盘上不存在的 stale 项
  Future<List<String>> listAll();

  /// 保存一份新照片到 app 内目录 + 注册到 manifest
  /// 返回写入的文件绝对路径
  Future<String> add(Uint8List bytes);

  /// 批量删除：删文件 + 从 manifest 移除
  Future<void> delete(List<String> paths);
}

class AppPhotoRepositoryImpl implements AppPhotoRepository {
  static const String _subdir = 'app_photos';
  static const String _manifestName = 'manifest.json';

  Directory? _photosDir;
  File? _manifestFile;
  List<String> _paths = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final docs = await getApplicationDocumentsDirectory();
    _photosDir = Directory('${docs.path}/$_subdir');
    if (!await _photosDir!.exists()) {
      await _photosDir!.create(recursive: true);
    }
    _manifestFile = File('${_photosDir!.path}/$_manifestName');
    if (await _manifestFile!.exists()) {
      try {
        final raw = await _manifestFile!.readAsString();
        final data = jsonDecode(raw);
        if (data is Map && data['paths'] is List) {
          _paths = (data['paths'] as List).cast<String>();
        }
      } catch (_) {
        _paths = [];
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    await _manifestFile!.writeAsString(
      jsonEncode({'paths': _paths}),
      flush: true,
    );
  }

  @override
  Future<List<String>> listAll() async {
    await _ensureLoaded();
    final out = <String>[];
    final alive = <String>[];
    for (final p in _paths) {
      if (await File(p).exists()) {
        out.add(p);
        alive.add(p);
      }
      // stale 路径直接丢弃
    }
    // manifest 漂移修正
    if (alive.length != _paths.length) {
      _paths = alive;
      await _persist();
    }
    return out;
  }

  @override
  Future<String> add(Uint8List bytes) async {
    await _ensureLoaded();
    final filename =
        'easy_beauty_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File('${_photosDir!.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    _paths = [file.path, ..._paths];
    await _persist();
    return file.path;
  }

  @override
  Future<void> delete(List<String> paths) async {
    await _ensureLoaded();
    if (paths.isEmpty) return;
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // 忽略单个失败，继续删其他
      }
    }
    final removeSet = paths.toSet();
    _paths = _paths.where((p) => !removeSet.contains(p)).toList();
    await _persist();
  }
}

/// 内存版（测试用）：不落盘，纯 list
class InMemoryAppPhotoRepository implements AppPhotoRepository {
  final List<String> _paths = [];

  @override
  Future<List<String>> listAll() async => List.unmodifiable(_paths);

  @override
  Future<String> add(Uint8List bytes) async {
    // 测试环境不需要真实写入；返回虚拟路径
    final virtual = '/mem/${DateTime.now().microsecondsSinceEpoch}.jpg';
    _paths.insert(0, virtual);
    return virtual;
  }

  @override
  Future<void> delete(List<String> paths) async {
    final set = paths.toSet();
    _paths.removeWhere(set.contains);
  }
}

final appPhotoRepositoryProvider = Provider<AppPhotoRepository>((ref) {
  return AppPhotoRepositoryImpl();
});