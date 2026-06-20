class AppConstants {
  static const int defaultPoseCount = 4;
  static const String poseRemoteBaseUrl = 'https://example.com/poses';
  static const String poseListJsonFile = 'poses.json';

  static const List<String> defaultFilters = [
    'Original',
    'Coral',
    '港风',
    '日系',
    '胶片',
  ];

  static const List<double> beautyRange = [0.0, 100.0];
  // 美颜默认值改为 0（用户偏好：拍出来原图，需要时再手动调）
  static const double defaultBeautySmooth = 0.0;
  static const double defaultBeautyWhiten = 0.0;
  static const double defaultBeautySlim = 0.0;
}