import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/image_processing_service.dart';
import '../../services/photo_album_writer.dart';
import '../photo_album/app_photo_repository.dart';

final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService();
});

final filterViewModelProvider = StateNotifierProvider<FilterViewModel, FilterViewModelState>((ref) {
  return FilterViewModel(
    ref.watch(imageProcessingServiceProvider),
    ref.watch(photoAlbumWriterProvider),
    ref.watch(appPhotoRepositoryProvider),
  );
});

class FilterViewModelState {
  final String? imagePath;
  final FilterType selectedFilter;
  final CropRatio cropRatio;
  final bool isProcessing; // 保存时
  final bool isPreviewProcessing; // 实时预览处理时
  final Uint8List? previewBytes; // 处理后预览图
  final Uint8List? originalBytes; // 原图缓存（避免重复读盘）
  final double scale;
  final Offset translation;

  const FilterViewModelState({
    this.imagePath,
    this.selectedFilter = FilterType.original,
    this.cropRatio = CropRatio.original,
    this.isProcessing = false,
    this.isPreviewProcessing = false,
    this.previewBytes,
    this.originalBytes,
    this.scale = 1.0,
    this.translation = Offset.zero,
  });

  FilterViewModelState copyWith({
    String? imagePath,
    FilterType? selectedFilter,
    CropRatio? cropRatio,
    bool? isProcessing,
    bool? isPreviewProcessing,
    Uint8List? previewBytes,
    Uint8List? originalBytes,
    double? scale,
    Offset? translation,
    bool clearOriginalBytes = false,
    bool clearPreviewBytes = false,
  }) {
    return FilterViewModelState(
      imagePath: imagePath ?? this.imagePath,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      cropRatio: cropRatio ?? this.cropRatio,
      isProcessing: isProcessing ?? this.isProcessing,
      isPreviewProcessing: isPreviewProcessing ?? this.isPreviewProcessing,
      previewBytes: clearPreviewBytes ? null : (previewBytes ?? this.previewBytes),
      originalBytes: clearOriginalBytes ? null : (originalBytes ?? this.originalBytes),
      scale: scale ?? this.scale,
      translation: translation ?? this.translation,
    );
  }
}

class FilterViewModel extends StateNotifier<FilterViewModelState> {
  final ImageProcessingService _processingService;
  final PhotoAlbumWriter _photoAlbumWriter;
  final AppPhotoRepository _appPhotoRepository;

  /// 防抖定时器：滑动 slider 时合并多次请求
  Timer? _debounce;

  FilterViewModel(
    this._processingService,
    this._photoAlbumWriter,
    this._appPhotoRepository,
  ) : super(const FilterViewModelState());

  /// 切换到新的待编辑照片
  void setImage(String path) {
    state = state.copyWith(
      imagePath: path,
      clearOriginalBytes: true,
      clearPreviewBytes: true,
    );
    _scheduleProcess(immediate: true);
  }

  void selectFilter(FilterType filter) {
    state = state.copyWith(selectedFilter: filter);
    _scheduleProcess();
  }

  void setCropRatio(CropRatio ratio) {
    state = state.copyWith(cropRatio: ratio);
    // 不再触发 _runProcess：预览 = 未裁切原图，比例切换只改遮罩
  }

  void setTransform({double? scale, Offset? translation}) {
    state = state.copyWith(
      scale: scale ?? state.scale,
      translation: translation ?? state.translation,
    );
    _scheduleProcess();
  }

  void resetTransform() {
    state = state.copyWith(scale: 1.0, translation: Offset.zero);
    _scheduleProcess();
  }

  /// 防抖调度：
  /// - 新照片立即处理（immediate: true）
  /// - slider/filter 改动用 200ms debounce，避免连发
  void _scheduleProcess({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      _runProcess();
    } else {
      _debounce = Timer(const Duration(milliseconds: 200), _runProcess);
    }
  }

  Future<void> _runProcess() async {
    if (state.imagePath == null) return;
    // 1) 确保原图 bytes 加载
    var origBytes = state.originalBytes;
    if (origBytes == null) {
      final file = File(state.imagePath!);
      if (!await file.exists()) return;
      if (!mounted) return;
      origBytes = await file.readAsBytes();
      if (!mounted) return;
      state = state.copyWith(originalBytes: origBytes);
    }

    if (!mounted) return;
    state = state.copyWith(isPreviewProcessing: true);

    // 2) filter → 亮度补偿（美颜流水线 2026-06-25 移除）
    final processed = await _processingService.processImage(
      origBytes,
      filter: state.selectedFilter,
    );

    if (!mounted) return;
    state = state.copyWith(
      previewBytes: processed,
      isPreviewProcessing: false,
    );
  }

  /// 处理并写入相册 + app 内 grid
  Future<String?> saveProcessedImage() async {
    if (state.imagePath == null) return null;
    state = state.copyWith(isProcessing: true);

    // 优先用已处理的 previewBytes；否则现处理一份
    Uint8List bytes = state.previewBytes ??
        await _processingService.processImage(
          await _readImageBytes(state.imagePath!),
          filter: state.selectedFilter,
        );

    // 裁切 + transform（自由比例 = 仅在用户缩放/平移过时按可见区域裁切）
    final ratio = state.cropRatio;
    if (ratio != CropRatio.original) {
      bytes = await _processingService.applyTransform(
        bytes,
        scale: state.scale,
        translation: state.translation,
        targetRatio: ratio.ratio,
      );
    } else if (state.scale != 1.0 || state.translation != Offset.zero) {
      bytes = await _processingService.applyTransform(
        bytes,
        scale: state.scale,
        translation: state.translation,
        targetRatio: null,
      );
    }

    final filename =
        'easy_beauty_${DateTime.now().millisecondsSinceEpoch}.png';
    await _photoAlbumWriter.saveImage(bytes, filename: filename);
    final appPath = await _appPhotoRepository.add(bytes);

    state = state.copyWith(isProcessing: false);
    return appPath;
  }

  Future<Uint8List> _readImageBytes(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
