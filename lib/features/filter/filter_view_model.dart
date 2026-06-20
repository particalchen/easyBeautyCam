import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../services/image_processing_service.dart';
import '../../services/photo_album_writer.dart';
import '../photo_album/app_photo_repository.dart';
import '../../../core/constants/app_constants.dart';

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
  final double smooth;
  final double whiten;
  final double slim;
  final bool isProcessing; // 保存时
  final bool isPreviewProcessing; // 实时预览处理时
  final Uint8List? previewBytes; // 处理后预览图
  final Uint8List? originalBytes; // 原图缓存（避免重复读盘）
  final double scale;
  final Offset translation;

  const FilterViewModelState({
    this.imagePath,
    this.selectedFilter = FilterType.coral,
    this.cropRatio = CropRatio.free,
    this.smooth = AppConstants.defaultBeautySmooth,
    this.whiten = AppConstants.defaultBeautyWhiten,
    this.slim = AppConstants.defaultBeautySlim,
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
    double? smooth,
    double? whiten,
    double? slim,
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
      smooth: smooth ?? this.smooth,
      whiten: whiten ?? this.whiten,
      slim: slim ?? this.slim,
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
    _scheduleProcess();
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

  void setSmooth(double value) {
    state = state.copyWith(smooth: value);
    _scheduleProcess();
  }

  void setWhiten(double value) {
    state = state.copyWith(whiten: value);
    _scheduleProcess();
  }

  void setSlim(double value) {
    state = state.copyWith(slim: value);
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

    var processed = await _processingService.processImage(
      origBytes,
      filter: state.selectedFilter,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
    );

    // 裁切 + transform
    final ratio = state.cropRatio;
    if (ratio != CropRatio.free && processed.isNotEmpty) {
      final procImg = _safeDecodeImage(processed);
      if (procImg != null) {
        processed = await _processingService.applyTransform(
          processed,
          scale: state.scale,
          translation: state.translation,
          targetRatio: ratio.ratio,
        );
      }
    }

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
    var bytes = state.previewBytes;
    bytes ??= await _processingService.processImage(
      await _readImageBytes(state.imagePath!),
      filter: state.selectedFilter,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
    );

    // 裁切 + transform（与 _runProcess 一致）
    final ratio = state.cropRatio;
    if (ratio != CropRatio.free && bytes != null) {
      final procImg = _safeDecodeImage(bytes);
      if (procImg != null) {
        bytes = await _processingService.applyTransform(
          bytes,
          scale: state.scale,
          translation: state.translation,
          targetRatio: ratio.ratio,
        );
      }
    }

    if (bytes == null) {
      state = state.copyWith(isProcessing: false);
      return null;
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

  /// 包装 `img.decodeImage`，对非法字节（mock/损坏文件）返回 null 而不是抛异常。
  img.Image? _safeDecodeImage(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}