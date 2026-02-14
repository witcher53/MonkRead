import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import 'package:flutter/material.dart';
import 'package:monkread/domain/entities/drawing_state.dart';

/// Paints completed strokes + the active stroke.
/// All coordinates are normalized (0–1) and scaled to [canvasSize].
class DrawingPainter extends CustomPainter {
  final List<DrawingPath> completedStrokes;
  final DrawingPath? activeStroke;
  final LassoSelection? lassoSelection;
  final Rect? selectionBounds;
  final Size canvasSize;
  final List<TextAnnotation> textAnnotations;

  DrawingPainter({
    required this.completedStrokes,
    required this.canvasSize,
    this.activeStroke,
    this.lassoSelection,
    this.selectionBounds,
    this.textAnnotations = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (canvasSize.isEmpty) return;

    final lasso = lassoSelection;
    final hasLasso = lasso != null;
    final dragOffset = hasLasso ? lasso.dragOffset : Offset.zero;
    final rotation = hasLasso ? lasso.rotationAngle : 0.0;

    // 1. Organize Strokes
    final unselectedStrokes = <DrawingPath>[];
    final selectedStrokes = <DrawingPath>[];

    for (int i = 0; i < completedStrokes.length; i++) {
      if (hasLasso && lasso.selectedStrokeIndices.contains(i)) {
        selectedStrokes.add(completedStrokes[i]);
      } else {
        unselectedStrokes.add(completedStrokes[i]);
      }
    }

    // 2. Draw Unselected Strokes
    for (final stroke in unselectedStrokes) {
      _drawStroke(canvas, stroke, Offset.zero);
    }

    // 3. Draw Selected Items (Maybe Rotated)
    if (hasLasso && !lasso.isEmpty && selectionBounds != null) {
      if (rotation != 0.0) {
        // VISUAL MATRIX ROTATION
        final center = selectionBounds!.center;
        final cx = center.dx * size.width;
        final cy = center.dy * size.height;

        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(rotation);
        canvas.translate(-cx, -cy);

        for (final stroke in selectedStrokes) {
          _drawStroke(canvas, stroke, dragOffset);
          _drawStrokeHighlight(canvas, stroke, dragOffset);
        }
        
        for (final text in textAnnotations) {
          if (lasso.selectedTextIds.contains(text.id)) {
            _drawTextItem(canvas, text, dragOffset);
          }
        }

        _drawSelectionBox(canvas, selectionBounds!, includeRotation: false);
        canvas.restore();
      } else {
        for (final stroke in selectedStrokes) {
          _drawStroke(canvas, stroke, dragOffset);
          _drawStrokeHighlight(canvas, stroke, dragOffset);
        }
        
        _drawSelectionBox(canvas, selectionBounds!, includeRotation: true); 
      }
    }

    // 4. Draw active stroke
    if (activeStroke != null) {
      _drawStroke(canvas, activeStroke!, Offset.zero);
    }

    // 5. Draw lasso path
    if (hasLasso && lasso.pathPoints.isNotEmpty) {
      _drawLassoPath(canvas, lasso.pathPoints);
    }
  }

  void _drawStroke(Canvas canvas, DrawingPath stroke, Offset offset) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    _drawPath(canvas, stroke.points, offset, paint);
  }

  void _drawStrokeHighlight(Canvas canvas, DrawingPath stroke, Offset offset) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.3)
      ..strokeWidth = stroke.strokeWidth + 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    _drawPath(canvas, stroke.points, offset, paint);
  }
  
  void _drawTextItem(Canvas canvas, TextAnnotation text, Offset dragOffset) {
     final pos = text.position + dragOffset;
     final x = pos.dx * canvasSize.width;
     final y = pos.dy * canvasSize.height;
     
     final span = TextSpan(
       text: text.text,
       style: TextStyle(
         color: text.color,
         fontSize: text.fontSize, 
       ),
     );
     
     final tp = TextPainter(
       text: span,
       textDirection: TextDirection.ltr,
     );
     tp.layout();
     tp.paint(canvas, Offset(x, y));
  }

  void _drawLassoPath(Canvas canvas, List<Offset> points) {
    if (points.length < 2) return;
    
    final scaledPoints = points.map((p) => Offset(p.dx * canvasSize.width, p.dy * canvasSize.height)).toList();

    final paint = Paint()
      ..color = Colors.deepOrangeAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final path = Path();
    path.moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
    for (int i = 1; i < scaledPoints.length - 1; i++) {
      final p0 = scaledPoints[i];
      final p1 = scaledPoints[i+1];
      path.quadraticBezierTo(p0.dx, p0.dy, (p0.dx + p1.dx)/2, (p0.dy + p1.dy)/2);
    }
    path.lineTo(scaledPoints.last.dx, scaledPoints.last.dy);

    _drawDashedPath(canvas, path, paint);
  }

  void _drawPath(Canvas canvas, List<Offset> points, Offset offset, Paint paint) {
    final path = Path();
    Offset toPixel(Offset n) => Offset(
        (n.dx + offset.dx) * canvasSize.width,
        (n.dy + offset.dy) * canvasSize.height);

    final first = toPixel(points.first);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = toPixel(points[i]);
      final p1 = toPixel(points[i + 1]);
      path.quadraticBezierTo(
          p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    }

    final last = toPixel(points.last);
    path.lineTo(last.dx, last.dy);
    canvas.drawPath(path, paint);
  }

  void _drawSelectionBox(Canvas canvas, Rect normalizedBounds, {required bool includeRotation}) {
    final rect = Rect.fromLTRB(
      normalizedBounds.left * canvasSize.width,
      normalizedBounds.top * canvasSize.height,
      normalizedBounds.right * canvasSize.width,
      normalizedBounds.bottom * canvasSize.height,
    );

    // FIXED: Using bool flag because Canvas.save() returns void
    bool shouldRestore = false;
    if (includeRotation && (lassoSelection?.rotationAngle ?? 0) != 0) {
      canvas.save();
      shouldRestore = true;
      
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(lassoSelection!.rotationAngle);
      canvas.translate(-rect.center.dx, -rect.center.dy);
    }

    final borderPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final path = Path()..addRect(rect);
    _drawDashedPath(canvas, path, borderPaint);

    final handlePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;
    const handleRadius = 4.0;
    for (final corner in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
      canvas.drawCircle(corner, handleRadius, handlePaint);
    }

    const rotHandleLen = 24.0;
    const rotHandleRadius = 6.0;
    final topCenter = Offset(rect.center.dx, rect.top);
    final handleEnd = Offset(topCenter.dx, topCenter.dy - rotHandleLen);

    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(topCenter, handleEnd, linePaint);
    
    canvas.drawCircle(handleEnd, rotHandleRadius, handlePaint);

    if (shouldRestore) {
      canvas.restore();
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (metric.length > 0 && distance < metric.length) {
        final extractPath = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter old) =>
      old.completedStrokes != completedStrokes ||
      old.activeStroke != activeStroke ||
      old.lassoSelection != lassoSelection ||
      old.selectionBounds != selectionBounds ||
      old.canvasSize != canvasSize ||
      old.lassoSelection?.rotationAngle != lassoSelection?.rotationAngle; 
}

/// Per-page overlay for drawing strokes and interactive text annotations.
class DrawingCanvas extends StatelessWidget {
  final AnnotationMode annotationMode;
  final int currentPage;
  final List<DrawingPath> completedStrokes;
  final DrawingPath? activeStroke;
  final LassoSelection? lassoSelection;
  final List<TextAnnotation> textAnnotations;
  final double pageWidthPt;
  final void Function(Offset normalizedPosition) onPanStart;
  final void Function(Offset normalizedPosition) onPanUpdate;
  final VoidCallback onPanEnd;
  final void Function(Offset normalizedPosition)? onTextTap;
  final void Function(String id)? onTextRemove;
  final void Function(TextAnnotation annotation)? onTextEdit;
  final void Function(String id, Offset normalizedDelta)? onTextDrag;

  const DrawingCanvas({
    super.key,
    required this.annotationMode,
    required this.currentPage,
    required this.completedStrokes,
    this.activeStroke,
    this.textAnnotations = const [],
    this.lassoSelection,
    required this.pageWidthPt,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.onTextTap,
    this.onTextRemove,
    this.onTextEdit,
    this.onTextDrag,
  });

  @override
  Widget build(BuildContext context) {
    final isPen = annotationMode == AnnotationMode.pen;
    final isText = annotationMode == AnnotationMode.text;
    final isLasso = annotationMode == AnnotationMode.lasso;
    final isAnnotating = annotationMode != AnnotationMode.none;

    return IgnorePointer(
      ignoring: !isAnnotating,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final zoomScale = pageWidthPt > 0 ? size.width / pageWidthPt : 1.0;
          final lassoOffset = lassoSelection?.dragOffset ?? Offset.zero;
          final rotation = lassoSelection?.rotationAngle ?? 0.0;
          final isRotating = rotation != 0.0;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            // Explicit user request: use arrow syntax (d) => ...
            // Explicit user request: use arrow syntax (d) => ...
            onPanStart: (isPen || isLasso)
                ? (d) {
                    var pos = _normalize(d.localPosition, size);
                    final currentLasso = lassoSelection;
                    if (isLasso && isRotating && currentLasso != null) {
                      // MATRIX FIX: Apply inverse rotation to map pointer back to local space
                      final bounds = currentLasso.computeBounds(
                          completedStrokes, textAnnotations);
                      
                      if (bounds != null) {
                        final center = bounds.center;
                        
                        // Convert to pixel space
                        final cx = center.dx * size.width;
                        final cy = center.dy * size.height;
                        final px = pos.dx * size.width;
                        final py = pos.dy * size.height;

                        // Construct the Forward Transformation Matrix M
                        // M = T(cx, cy) * R(rotation) * T(-cx, -cy)
                        final matrix = Matrix4.identity()
                          ..translate(cx, cy)
                          ..rotateZ(rotation)
                          ..translate(-cx, -cy);

                        // Compute Inverse M^-1
                        final inverseMatrix = Matrix4.inverted(matrix);

                        // Apply M^-1 to global point P
                        final pointVector = Vector3(px, py, 0);
                        final transformedVector = inverseMatrix.transformed3(pointVector);

                        // Normalize back
                        pos = _normalize(
                            Offset(transformedVector.x, transformedVector.y), 
                            size
                        );
                      }
                    }
                    onPanStart(pos);
                  }
                : null,
            onPanUpdate: (isPen || isLasso)
                ? (d) {
                    var pos = _normalize(d.localPosition, size);
                    final currentLasso = lassoSelection;
                     if (isLasso && isRotating && currentLasso != null) {
                      // MATRIX FIX: Apply inverse rotation to map pointer back to local space
                      final bounds = currentLasso.computeBounds(
                          completedStrokes, textAnnotations);
                      
                      if (bounds != null) {
                        final center = bounds.center;
                        
                        final cx = center.dx * size.width;
                        final cy = center.dy * size.height;
                        final px = pos.dx * size.width;
                        final py = pos.dy * size.height;

                        // Construct the Forward Transformation Matrix M
                        // M = T(cx, cy) * R(rotation) * T(-cx, -cy)
                        final matrix = Matrix4.identity()
                          ..translate(cx, cy)
                          ..rotateZ(rotation)
                          ..translate(-cx, -cy);

                        // Compute Inverse M^-1
                        final inverseMatrix = Matrix4.inverted(matrix);

                        // Apply M^-1 to global point P
                        final pointVector = Vector3(px, py, 0);
                        final transformedVector = inverseMatrix.transformed3(pointVector);

                        // Normalize back
                        pos = _normalize(
                            Offset(transformedVector.x, transformedVector.y), 
                            size
                        );
                      }
                    }
                    onPanUpdate(pos);
                  }
                : null,
            onPanEnd: (isPen || isLasso)
                ? (_) => onPanEnd()
                : null,
            onTapUp: isText
                ? (d) => onTextTap?.call(_normalize(d.localPosition, size))
                : null,
            child: RepaintBoundary(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: size,
                    painter: DrawingPainter(
                      completedStrokes: completedStrokes,
                      activeStroke: activeStroke,
                      lassoSelection: lassoSelection,
                      selectionBounds: lassoSelection?.computeBounds(
                        completedStrokes,
                        textAnnotations,
                      ),
                      canvasSize: size,
                      textAnnotations: textAnnotations,
                    ),
                  ),
                  
                  ...textAnnotations.map((a) {
                    final isSelected = lassoSelection?.selectedTextIds.contains(a.id) ?? false;
                    
                    if (isSelected && isRotating) {
                      return const SizedBox.shrink();
                    }

                    var displayAnnotation = a;
                    if (isSelected) {
                      displayAnnotation = a.copyWith(
                        position: a.position + lassoOffset,
                      );
                    }

                    return _InteractiveText(
                      annotation: displayAnnotation,
                      canvasSize: size,
                      zoomScale: zoomScale,
                      isTextMode: isText,
                      isSelectedByLasso: isSelected,
                      onDrag: onTextDrag,
                      onEdit: onTextEdit,
                      onRemove: onTextRemove,
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Offset _normalize(Offset pixel, Size size) {
    if (size.isEmpty) return Offset.zero;
    return Offset(pixel.dx / size.width, pixel.dy / size.height);
  }
}

class _InteractiveText extends StatefulWidget {
  final TextAnnotation annotation;
  final Size canvasSize;
  final double zoomScale;
  final bool isTextMode;
  final bool isSelectedByLasso;
  final void Function(String id, Offset normalizedDelta)? onDrag;
  final void Function(TextAnnotation annotation)? onEdit;
  final void Function(String id)? onRemove;

  const _InteractiveText({
    required this.annotation,
    required this.canvasSize,
    required this.zoomScale,
    required this.isTextMode,
    this.isSelectedByLasso = false,
    this.onDrag,
    this.onEdit,
    this.onRemove,
  });

  @override
  State<_InteractiveText> createState() => _InteractiveTextState();
}

class _InteractiveTextState extends State<_InteractiveText> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.annotation;
    final x = a.position.dx * widget.canvasSize.width;
    final y = a.position.dy * widget.canvasSize.height;

    final scaledFontSize = a.fontSize * widget.zoomScale;
    final showBorder = _selected || widget.isSelectedByLasso;

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: widget.isTextMode
            ? (d) {
                final dx = d.delta.dx / widget.canvasSize.width;
                final dy = d.delta.dy / widget.canvasSize.height;
                widget.onDrag?.call(a.id, Offset(dx, dy));
              }
            : null,
        onTap: widget.isTextMode
            ? () { setState(() => _selected = !_selected); }
            : null,
        onDoubleTap: widget.isTextMode 
            ? () { widget.onEdit?.call(a); } 
            : null,
        onLongPress: widget.isTextMode 
            ? () { widget.onRemove?.call(a.id); } 
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: showBorder
              ? BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                  color: widget.isSelectedByLasso
                      ? Colors.blueAccent.withOpacity(0.1)
                      : null,
                )
              : null,
          child: Text(
            a.text,
            style: TextStyle(
              fontSize: scaledFontSize,
              color: a.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
