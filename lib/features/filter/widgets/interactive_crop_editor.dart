import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../../core/theme/app_colors.dart';
import '../../../services/image_processing_service.dart';

/// 拍后编辑顶部「交互式裁切编辑器」
///
/// - 用 InteractiveViewer 让用户可以双指缩放 / 单指拖动
/// - 顶部叠一层裁切框遮罩（自由比例下不画）
/// - 手势结束 200ms debounce 后回调 onTransformChanged
class InteractiveCropEditor extends StatefulWidget {
  final Uint8List? previewBytes;
  final String? imagePath;
  final CropRatio cropRatio;
  final double scale;
  final Offset translation;
  final void Function(double scale, Offset translation) onTransformChanged;

  const InteractiveCropEditor({
    super.key,
    this.previewBytes,
    this.imagePath,
    required this.cropRatio,
    required this.scale,
    required this.translation,
    required this.onTransformChanged,
  });

  @override
  State<InteractiveCropEditor> createState() => _InteractiveCropEditorState();
}

class _InteractiveCropEditorState extends State<InteractiveCropEditor> {
  late final TransformationController _ctrl;
  Timer? _debounce;

  static const _minScale = 0.5;
  static const _maxScale = 4.0;

  @override
  void initState() {
    super.initState();
    _ctrl = TransformationController();
    _syncFromProps();
  }

  @override
  void didUpdateWidget(InteractiveCropEditor old) {
    super.didUpdateWidget(old);
    if (old.scale != widget.scale || old.translation != widget.translation) {
      _syncFromProps();
    }
  }

  void _syncFromProps() {
    // context.size 在 initState 阶段尚未确定（render tree 未建立），
    // 需要延后到第一帧后再读取。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size ?? const Size(300, 300);
      final halfW = size.width / 2;
      final halfH = size.height / 2;
      final m = Matrix4.identity()
        ..translate(widget.translation.dx * halfW, widget.translation.dy * halfH)
        ..scale(widget.scale);
      _ctrl.value = m;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onInteractionEnd() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final m = _ctrl.value;
      final s = m.getMaxScaleOnAxis().clamp(_minScale, _maxScale);
      final tx = m.getTranslation().x;
      final ty = m.getTranslation().y;
      final size = context.size ?? const Size(300, 300);
      // 用 viewport 半尺寸归一化：translation = size.width/2 时 ntx=1（拖出裁切框半幅）
      final halfW = size.width / 2;
      final halfH = size.height / 2;
      final ntx = halfW > 0 ? (tx / halfW).clamp(-1.0, 1.0) : 0.0;
      final nty = halfH > 0 ? (ty / halfH).clamp(-1.0, 1.0) : 0.0;
      widget.onTransformChanged(s, Offset(ntx, nty));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.cropRatio.ratio;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            transformationController: _ctrl,
            minScale: _minScale,
            maxScale: _maxScale,
            onInteractionEnd: (_) => _onInteractionEnd(),
            child: Center(
              child: widget.previewBytes != null
                  ? Image.memory(widget.previewBytes!, fit: BoxFit.cover)
                  : (widget.imagePath != null
                      ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                      : const SizedBox.shrink()),
            ),
          ),
          if (ratio != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CropFramePainter(ratio: ratio),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 裁切框遮罩 painter：
/// - 框外画半透明黑（alpha 0.55）
/// - 框边画 1.5pt 珊瑚色线
class _CropFramePainter extends CustomPainter {
  final double ratio; // width / height

  _CropFramePainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    double frameW;
    double frameH;
    if (size.width / size.height > ratio) {
      frameH = size.height;
      frameW = frameH * ratio;
    } else {
      frameW = size.width;
      frameH = frameW / ratio;
    }
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameW,
      height: frameH,
    );

    final maskPaint = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, frameRect.top), maskPaint);
    canvas.drawRect(
        Rect.fromLTRB(0, frameRect.bottom, size.width, size.height), maskPaint);
    canvas.drawRect(
        Rect.fromLTRB(0, frameRect.top, frameRect.left, frameRect.bottom), maskPaint);
    canvas.drawRect(Rect.fromLTRB(
        frameRect.right, frameRect.top, size.width, frameRect.bottom), maskPaint);

    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(frameRect, borderPaint);
  }

  @override
  bool shouldRepaint(_CropFramePainter old) => old.ratio != ratio;
}