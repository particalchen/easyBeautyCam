import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../services/face_detection_service.dart';
import '../../services/face_mask_builder.dart';
import '../../services/image_processing_service.dart';
import '../../services/photo_album_writer.dart';
import '../photo_album/app_photo_repository.dart';
import '../../../core/constants/app_constants.dart';

final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService();
});

final faceDetectionServiceProvider = Provider<FaceDetectionService>((ref) {
  return FaceDetectionService();
});

final faceMaskBuilderProvider = Provider<FaceMaskBuilder>((ref) {
  return FaceMaskBuilder();
});

final filterViewModelProvider = StateNotifierProvider<FilterViewModel, FilterViewModelState>((ref) {
  return FilterViewModel(
    ref.watch(imageProcessingServiceProvider),
    ref.watch(photoAlbumWriterProvider),
    ref.watch(appPhotoRepositoryProvider),
    ref.watch(faceDetectionServiceProvider),
    ref.watch(faceMaskBuilderProvider),
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
  final int faceCount; // 当前预览中识别到的人脸数（0 = 没脸或未检测）
  final bool faceDetectionFailed; // ML Kit 异常时降级到无美颜

  const FilterViewModelState({
    this.imagePath,
    this.selectedFilter = FilterType.original,
    this.cropRatio = CropRatio.original,
    this.smooth = AppConstants.defaultBeautySmooth,
    this.whiten = AppConstants.defaultBeautyWhiten,
    this.slim = AppConstants.defaultBeautySlim,
    this.isProcessing = false,
    this.isPreviewProcessing = false,
    this.previewBytes,
    this.originalBytes,
    this.scale = 1.0,
    this.translation = Offset.zero,
    this.faceCount = 0,
    this.faceDetectionFailed = false,
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
    int? faceCount,
    bool? faceDetectionFailed,
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
      faceCount: faceCount ?? this.faceCount,
      faceDetectionFailed: faceDetectionFailed ?? this.faceDetectionFailed,
    );
  }
}

class FilterViewModel extends StateNotifier<FilterViewModelState> {
  final ImageProcessingService _processingService;
  final PhotoAlbumWriter _photoAlbumWriter;
  final AppPhotoRepository _appPhotoRepository;
  final FaceDetectionService _faceDetector;
  final FaceMaskBuilder _maskBuilder;

  /// 防抖定时器：滑动 slider 时合并多次请求
  Timer? _debounce;

  FilterViewModel(
    this._processingService,
    this._photoAlbumWriter,
    this._appPhotoRepository,
    this._faceDetector,
    this._maskBuilder,
  ) : super(const FilterViewModelState());

  /// 切换到新的待编辑照片
  void setImage(String path) {
    _faceDetector.clearCache();
    state = state.copyWith(
      imagePath: path,
      clearOriginalBytes: true,
      clearPreviewBytes: true,
      faceCount: 0,
      faceDetectionFailed: false,
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

    // 2) applyFilter
    final filtered = await _processingService.applyFilter(
      origBytes,
      state.selectedFilter,
    );

    // 3) 人脸检测（带缓存：setImage 触发，setSmooth/Whiten 复用缓存）
    img.Image? mask;
    int faceCount = 0;
    bool failed = false;
    try {
      final contours = await _faceDetector.detect(
        state.imagePath!,
        bytes: filtered,
      );
      faceCount = contours.length;
      if (contours.isNotEmpty) {
        final decoded = img.decodeImage(filtered);
        final w = decoded?.width ?? 0;
        final h = decoded?.height ?? 0;
        if (w > 0 && h > 0) {
          mask = _maskBuilder.buildMask(
            width: w,
            height: h,
            faces: contours,
          );
        }
      }
    } catch (e) {
      // ML Kit 不可用 / 抛异常 → 降级到无美颜（per Q4 默认）
      failed = true;
    }

    if (!mounted) return;

    // 4) 美颜（mask 决定是否生效）
    var processed = await _processingService.applyBeauty(
      filtered,
      smooth: state.smooth,
      whiten: state.whiten,
      slim: state.slim,
      mask: mask,
    );

    // 5) 自动亮度补偿
    processed = await _processingService.normalizeBrightness(processed);

    if (!mounted) return;
    state = state.copyWith(
      previewBytes: processed,
      isPreviewProcessing: false,
      faceCount: faceCount,
      faceDetectionFailed: failed,
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
          smooth: state.smooth,
          whiten: state.whiten,
          slim: state.slim,
          mask: null, // save 时已用 previewBytes，避免重复 detect
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