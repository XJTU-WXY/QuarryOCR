// lib/widgets/image_viewer.dart

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/ocr_result.dart';

// ─── Color helpers ────────────────────────────────────────────────────────────

Color _fillColor(double score, bool selected) =>
    _scoreBase(score).withValues(alpha: selected ? 0.45 : 0.18);

Color _borderColor(double score, bool selected) =>
    _scoreBase(score).withValues(alpha: selected ? 0.90 : 0.55);

Color _scoreBase(double score) {
  if (score >= 0.85) return Colors.green;
  if (score >= 0.65) return Colors.orange;
  return Colors.red;
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _ImageBoxPainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;
  final OcrResult? ocrResult;

  const _ImageBoxPainter({
    required this.image,
    required this.scale,
    required this.offset,
    this.ocrResult,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw image
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(
        offset.dx, offset.dy, image.width * scale, image.height * scale);
    canvas.drawImageRect(image, src, dst, Paint());

    if (ocrResult == null) return;

    for (final box in ocrResult!.boxes) {
      final pts = box.dtBoxes
          .map((p) =>
              Offset(offset.dx + p.dx * scale, offset.dy + p.dy * scale))
          .toList();

      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy)
        ..lineTo(pts[3].dx, pts[3].dy)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = _fillColor(box.score, box.selected)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _borderColor(box.score, box.selected)
          ..style = PaintingStyle.stroke
          ..strokeWidth = box.selected ? 2.0 : 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(_ImageBoxPainter old) =>
      old.image != image ||
      old.scale != scale ||
      old.offset != offset ||
      old.ocrResult != ocrResult;
}

// ─── ImageViewer ──────────────────────────────────────────────────────────────

class ImageViewer extends StatefulWidget {
  final ui.Image? uiImage;
  final OcrResult? ocrResult;
  final bool isRecognizing;
  final void Function(int index, bool selected)? onBoxSelectionChanged;

  const ImageViewer({
    super.key,
    this.uiImage,
    this.ocrResult,
    this.isRecognizing = false,
    this.onBoxSelectionChanged,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _fitted = false;
  Size? _viewerSize;

  // ── Right-button pan ──
  bool _isRightDragging = false;
  Offset _rightDragStartLocal = Offset.zero;
  Offset _offsetAtRightDragStart = Offset.zero;

  // ── Left-drag box-selection ──
  bool _isDragSelecting = false;
  bool? _dragSelectTarget;
  bool _leftMoved = false; // true once the pointer moved enough to count as drag

  // ── Tap candidate (set on pointer-down, cleared on move) ──
  int? _tapCandidateIdx;

  // ── Fit ───────────────────────────────────────────────────────────────────

  void fitToWindow() {
    if (widget.uiImage == null || _viewerSize == null) return;
    final img = widget.uiImage!;
    final w = _viewerSize!.width;
    final h = _viewerSize!.height;
    final s = math.min(w / img.width, h / img.height);
    setState(() {
      _scale = s;
      _offset = Offset((w - img.width * s) / 2, (h - img.height * s) / 2);
      _fitted = true;
    });
  }

  @override
  void didUpdateWidget(ImageViewer old) {
    super.didUpdateWidget(old);
    if (widget.uiImage != old.uiImage && widget.uiImage != null) {
      _fitted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => fitToWindow());
    }
  }

  // ── Coordinate helpers ────────────────────────────────────────────────────

  Offset _toImageSpace(Offset viewPt) => Offset(
        (viewPt.dx - _offset.dx) / _scale,
        (viewPt.dy - _offset.dy) / _scale,
      );

  int? _hitTest(Offset imagePt) {
    final result = widget.ocrResult;
    if (result == null) return null;
    for (final box in result.boxes) {
      if (box.boundingRect.contains(imagePt)) return box.index;
    }
    return null;
  }

  // ── Scroll-wheel zoom ──────────────────────────────────────────────────────

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || widget.uiImage == null) return;
    const factor = 1.15;
    var newScale =
        event.scrollDelta.dy < 0 ? _scale * factor : _scale / factor;
    newScale = newScale.clamp(0.05, 30.0);
    final local = event.localPosition;
    final imgPt = _toImageSpace(local);
    setState(() {
      _scale = newScale;
      _offset = Offset(
        local.dx - imgPt.dx * _scale,
        local.dy - imgPt.dy * _scale,
      );
    });
  }

  // ── Raw pointer events (replaces onSecondaryPan* which doesn't exist) ─────
  //
  // kPrimaryMouseButton   = 0x01  (left)
  // kSecondaryMouseButton = 0x02  (right)

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryMouseButton) {
      // Right button: start pan
      _isRightDragging = true;
      _rightDragStartLocal = event.localPosition;
      _offsetAtRightDragStart = _offset;
    } else if (event.buttons == kPrimaryMouseButton) {
      // Left button: prepare tap/drag-select
      _leftMoved = false;
      _isDragSelecting = false;
      _dragSelectTarget = null;
      // Record which box is under the cursor (if any)
      if (widget.ocrResult != null && widget.onBoxSelectionChanged != null) {
        final imgPt = _toImageSpace(event.localPosition);
        _tapCandidateIdx = _hitTest(imgPt);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isRightDragging) {
      // Pan
      setState(() {
        _offset = _offsetAtRightDragStart +
            (event.localPosition - _rightDragStartLocal);
      });
    } else if (event.buttons == kPrimaryMouseButton) {
      // Left drag → drag-select mode
      if (!_leftMoved) {
        // Threshold to distinguish tap from drag
        final delta = (event.localPosition - _rightDragStartLocal).distance;
        if (delta > 4.0) {
          _leftMoved = true;
          _tapCandidateIdx = null; // cancel tap
          // Begin drag-select from current position
          if (widget.ocrResult != null &&
              widget.onBoxSelectionChanged != null) {
            final imgPt = _toImageSpace(event.localPosition);
            final idx = _hitTest(imgPt);
            if (idx != null) {
              final box = widget.ocrResult!.boxes[idx];
              _dragSelectTarget = !box.selected;
              _isDragSelecting = true;
              widget.onBoxSelectionChanged!(idx, _dragSelectTarget!);
            }
          }
        }
      } else if (_isDragSelecting &&
          _dragSelectTarget != null &&
          widget.onBoxSelectionChanged != null) {
        final imgPt = _toImageSpace(event.localPosition);
        final idx = _hitTest(imgPt);
        if (idx != null) {
          final box = widget.ocrResult!.boxes[idx];
          if (box.selected != _dragSelectTarget!) {
            widget.onBoxSelectionChanged!(idx, _dragSelectTarget!);
          }
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isRightDragging) {
      _isRightDragging = false;
    } else {
      // Left button released
      if (!_leftMoved) {
        // It was a tap — toggle the candidate box
        final idx = _tapCandidateIdx;
        if (idx != null &&
            widget.ocrResult != null &&
            widget.onBoxSelectionChanged != null) {
          final box = widget.ocrResult!.boxes[idx];
          widget.onBoxSelectionChanged!(idx, !box.selected);
        }
      }
      _leftMoved = false;
      _isDragSelecting = false;
      _dragSelectTarget = null;
      _tapCandidateIdx = null;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _viewerSize = constraints.biggest;
      // Store drag-start reference point for left button too
      // (we re-use _rightDragStartLocal for the initial left-down position)

      if (!_fitted && widget.uiImage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => fitToWindow());
      }

      return ClipRect(
        child: Listener(
          // Scroll-wheel zoom + raw mouse button handling
          onPointerSignal: _onPointerSignal,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          child: Stack(
            children: [
              // Dark background
              Container(color: const Color(0xFF1A1A2E)),

              // Image + OCR boxes
              if (widget.uiImage != null)
                CustomPaint(
                  painter: _ImageBoxPainter(
                    image: widget.uiImage!,
                    scale: _scale,
                    offset: _offset,
                    ocrResult: widget.ocrResult,
                  ),
                  size: constraints.biggest,
                ),

              // Empty state
              if (widget.uiImage == null && !widget.isRecognizing)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined,
                          size: 72, color: Colors.white24),
                      SizedBox(height: 14),
                      Text(
                        '请从剪贴板或文件读入图片',
                        style: TextStyle(color: Colors.white38, fontSize: 15),
                      ),
                    ],
                  ),
                ),

              // Recognizing overlay
              if (widget.isRecognizing)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '正在识别中…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ─── Controller + Wrapper ─────────────────────────────────────────────────────

class ImageViewerController {
  final GlobalKey<_ImageViewerState> _key = GlobalKey();

  void fitToWindow() => _key.currentState?.fitToWindow();
}

/// Wraps [ImageViewer] and wires up the [ImageViewerController].
class ControlledImageViewer extends StatelessWidget {
  final ImageViewerController controller;
  final ui.Image? uiImage;
  final OcrResult? ocrResult;
  final bool isRecognizing;
  final void Function(int index, bool selected)? onBoxSelectionChanged;

  const ControlledImageViewer({
    super.key,
    required this.controller,
    this.uiImage,
    this.ocrResult,
    this.isRecognizing = false,
    this.onBoxSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ImageViewer(
      key: controller._key,
      uiImage: uiImage,
      ocrResult: ocrResult,
      isRecognizing: isRecognizing,
      onBoxSelectionChanged: onBoxSelectionChanged,
    );
  }
}