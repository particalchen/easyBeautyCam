import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/image_processing_service.dart';
import '../../services/photo_album_writer.dart';
import '../../../core/constants/app_constants.dart';

final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService();
});

final filterViewModelProvider = StateNotifierProvider<FilterViewModel, FilterViewModelState>((ref) {
  return FilterViewModel(
    ref.watch(imageProcessingServiceProvider),
    ref.watch(photoAlbumWriterProvider),
  );
});

class FilterViewModelState {
  final String? imagePath;
  final FilterType selectedFilter;
  final double smooth;
  final double whiten;
  final double slim;
  final bool isProcessing;

  const FilterViewModelState({
    this.imagePath,
    this.selectedFilter = FilterType.coral,
    this.smooth = AppConstants.defaultBeautySmooth,
    this.whiten = AppConstants.defaultBeautyWhiten,
    this.slim = AppConstants.defaultBeautySlim,
    this.isProcessing = false,
  });

  FilterViewModelState copyWith({
    String? imagePath,
    FilterType? selectedFilter,
    double? smooth,
    double? whiten,
    double? slim,
    bool? isProcessing,
  }) {
    return FilterViewModelState(
      imagePath: imagePath ?? this.imagePath,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      smooth: smooth ?? this.smooth,
      whiten: whiten ?? this.whiten,
      slim: slim ?? this.slim,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class FilterViewModel extends StateNotifier<FilterViewModelState> {
  final ImageProcessingService _processingService;
  final PhotoAlbumWriter _photoAlbumWriter;

  FilterViewModel(this._processingService, this._photoAlbumWriter)
      : super(const FilterViewModelState());

  void setImage(String path) {
    state = state.copyWith(imagePath: path);
  }

  void selectFilter(FilterType filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setSmooth(double value) {
    state = state.copyWith(smooth: value);
  }

  void setWhiten(double value) {
    state = state.copyWith(whiten: value);
  }

  void setSlim(double value) {
    state = state.copyWith(slim: value);
  }

  /// 处理并写入相册：
  /// 1. 读原图字节
  /// 2. 走 ImageProcessingService（滤镜 + 美颜）→ 拿到 PNG bytes
  /// 3. 写真册（filename: easy_beauty_<timestamp>.png）
  /// 4. 返回写入的相册文件路径（用原图 path 作占位返回，UI 不展示）
  Future<String?> saveProcessedImage() async {
    if (state.imagePath == null) return null;
    state = state.copyWith(isProcessing: true);

    final processed = await _processingService.processImage(
      await _readImageBytes(state.imagePath!),
      filter: state.selectedFilter,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
    );

    final filename = 'easy_beauty_${DateTime.now().millisecondsSinceEpoch}.png';
    await _photoAlbumWriter.saveImage(processed, filename: filename);

    state = state.copyWith(isProcessing: false);
    return state.imagePath;
  }

  Future<Uint8List> _readImageBytes(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }
}