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