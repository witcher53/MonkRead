import 'package:flutter/material.dart';
import 'package:monkread/domain/entities/drawing_state.dart';
import 'package:monkread/domain/entities/sidecar_state.dart';
import 'package:monkread/presentation/widgets/drawing_canvas.dart';

/// Infinite-scroll whiteboard for freehand notes alongside a PDF.
///
/// Reuses [DrawingPainter] for strokes and supports text annotations.
/// The canvas has a white background and scrolls vertically.
class SidecarCanvas extends StatelessWidget {
  final SidecarState sidecarState;
  final AnnotationMode annotationMode;
  final Color selectedColor;
  final double selectedStrokeWidth;
  final void Function(Offset position) onPanStart;
  final void Function(Offset position) onPanUpdate;
  final VoidCallback onPanEnd;
  final void Function(Offset position)? onTextTap;
  final void Function(String id)? onTextRemove;
  final void Function(TextAnnotation annotation)? onTextEdit;
  final void Function(String id, Offset delta)? onTextDrag;
  final VoidCallback? onUndo;

  const SidecarCanvas({
    super.key,
    required this.sidecarState,
    required this.annotationMode,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.onTextTap,
    this.onTextRemove,
    this.onTextEdit,
    this.onTextDrag,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final isPen = annotationMode == AnnotationMode.pen;
    final isText = annotationMode == AnnotationMode.text;
    final isAnnotating = annotationMode != AnnotationMode.none;
    final theme = Theme.of(context);

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            height: 36,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.note_alt_rounded,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Notes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Canvas area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasWidth = constraints.maxWidth;
                final canvasHeight = sidecarState.canvasHeight;

                return SingleChildScrollView(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: isPen
                        ? (d) => onPanStart(_toCanvas(
                            d.localPosition, canvasWidth, canvasHeight))
                        : null,
                    onPanUpdate: isPen
                        ? (d) => onPanUpdate(_toCanvas(
                            d.localPosition, canvasWidth, canvasHeight))
                        : null,
                    onPanEnd: isPen ? (_) => onPanEnd() : null,
                    onTapUp: isText
                        ? (d) => onTextTap?.call(_toCanvas(
                            d.localPosition, canvasWidth, canvasHeight))
                        : null,
                    child: RepaintBoundary(
                      child: SizedBox(
                        width: canvasWidth,
                        height: canvasHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Grid lines (subtle ruled paper)
                            CustomPaint(
                              size: Size(canvasWidth, canvasHeight),
                              painter:
                                  _RuledLinePainter(lineSpacing: 32),
                            ),
                            // Strokes
                            CustomPaint(
                              size: Size(canvasWidth, canvasHeight),
                              painter: DrawingPainter(
                                completedStrokes: sidecarState.strokes,
                                activeStroke: sidecarState.activeStroke,
                                canvasSize:
                                    Size(canvasWidth, canvasHeight),
                              ),
                            ),
                            // Text annotations
                            ...sidecarState.textAnnotations.map(
                              (a) => _SidecarText(
                                annotation: a,
                                canvasSize:
                                    Size(canvasWidth, canvasHeight),
                                isTextMode: isText,
                                onDrag: onTextDrag,
                                onEdit: onTextEdit,
                                onRemove: onTextRemove,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Converts local position to normalized (0–1) coordinates.
  Offset _toCanvas(Offset local, double width, double height) {
    return Offset(
      (local.dx / width).clamp(0.0, 1.0),
      (local.dy / height).clamp(0.0, 1.0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Ruled paper lines
// ─────────────────────────────────────────────────────────────────

class _RuledLinePainter extends CustomPainter {
  final double lineSpacing;

  _RuledLinePainter({required this.lineSpacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5;

    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledLinePainter old) =>
      old.lineSpacing != lineSpacing;
}

// ─────────────────────────────────────────────────────────────────
// Interactive text for sidecar
// ─────────────────────────────────────────────────────────────────

class _SidecarText extends StatefulWidget {
  final TextAnnotation annotation;
  final Size canvasSize;
  final bool isTextMode;
  final void Function(String id, Offset delta)? onDrag;
  final void Function(TextAnnotation annotation)? onEdit;
  final void Function(String id)? onRemove;

  const _SidecarText({
    required this.annotation,
    required this.canvasSize,
    required this.isTextMode,
    this.onDrag,
    this.onEdit,
    this.onRemove,
  });

  @override
  State<_SidecarText> createState() => _SidecarTextState();
}

class _SidecarTextState extends State<_SidecarText> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.annotation;
    final x = a.position.dx * widget.canvasSize.width;
    final y = a.position.dy * widget.canvasSize.height;

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
            ? () => setState(() => _selected = !_selected)
            : null,
        onDoubleTap:
            widget.isTextMode ? () => widget.onEdit?.call(a) : null,
        onLongPress:
            widget.isTextMode ? () => widget.onRemove?.call(a.id) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: _selected
              ? BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                )
              : null,
          child: Text(
            a.text,
            style: TextStyle(
              fontSize: a.fontSize,
              color: a.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
