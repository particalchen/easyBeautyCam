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
  static const double defaultBeautySmooth = 30.0;
  static const double defaultBeautyWhiten = 20.0;
  static const double defaultBeautySlim = 0.0;
}