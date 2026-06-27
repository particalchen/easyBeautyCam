class PoseModel {
  final String id;
  final String name;
  final String category;
  final String assetPath;
  final bool isLocal;
  final String? remoteUrl;

  const PoseModel({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
    this.isLocal = true,
    this.remoteUrl,
  });

  /// 参考图（pose 的真实照片）。约定与 `assetPath` 同目录，扩展名前加 `-res`。
  /// 例如 `resources/poses/pose_outdoor_01.png` → `resources/poses/pose_outdoor_01-res.png`。
  /// 仅内置 assets 派生；远程/自定义 pose 没有对应参考图时返回 null，UI 应回退到 [assetPath]。
  String? get referenceAssetPath {
    if (!isLocal) return null;
    final dot = assetPath.lastIndexOf('.');
    if (dot < 0) return null;
    return '${assetPath.substring(0, dot)}-res${assetPath.substring(dot)}';
  }

  factory PoseModel.fromJson(Map<String, dynamic> json) {
    return PoseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      assetPath: json['asset_path'] as String,
      isLocal: false,
      remoteUrl: json['remote_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'asset_path': assetPath,
    'remote_url': remoteUrl,
  };
}