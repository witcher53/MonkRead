import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect;

/// The split-screen layout mode.
enum SplitViewMode {
  /// No split — single PDF view.
  none,

  /// Two PDFs side-by-side.
  dualPdf,

  /// PDF + infinite whiteboard notes panel.
  sidecar,
}

/// The current annotation tool mode.
enum AnnotationMode {
  /// No annotation — view-only. Pan/zoom enabled.
  none,

  /// Freehand pen drawing.
  pen,

  /// Text placement.
  text,

  /// Lasso selection tool.
  lasso,
}

// ─────────────────────────────────────────────────────────────────
// DrawingPath — freehand stroke
// ─────────────────────────────────────────────────────────────────

/// Represents a single freehand drawing stroke.
class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const DrawingPath({
    required this.points,
    this.color = const Color(0xFFFF5252),
    this.strokeWidth = 3.0,
  });

  DrawingPath addPoint(Offset point) {
    return DrawingPath(
      points: [...points, point],
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'points': points.map((p) => [p.dx, p.dy]).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }

  factory DrawingPath.fromMap(Map<dynamic, dynamic> map) {
    final rawPoints = map['points'] as List<dynamic>;
    return DrawingPath(
      points: rawPoints
          .map((p) => Offset(
                (p[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ))
          .toList(),
      color: Color(map['color'] as int),
      strokeWidth: (map['strokeWidth'] as num).toDouble(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TextAnnotation — positioned text on a page
// ─────────────────────────────────────────────────────────────────

/// A text annotation placed on a specific point of a page.
///
/// [position] is **normalized** (0.0–1.0) relative to page dimensions.
class TextAnnotation {
  final String id;
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;

  const TextAnnotation({
    required this.id,
    required this.text,
    required this.position,
    this.color = const Color(0xFF000000),
    this.fontSize = 16.0,
  });

  TextAnnotation copyWith({
    String? text,
    Offset? position,
    Color? color,
    double? fontSize,
  }) {
    return TextAnnotation(
      id: id,
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'position': [position.dx, position.dy],
      'color': color.value,
      'fontSize': fontSize,
    };
  }

  factory TextAnnotation.fromMap(Map<dynamic, dynamic> map) {
    final pos = map['position'] as List<dynamic>;
    return TextAnnotation(
      id: map['id'] as String,
      text: map['text'] as String,
      position: Offset(
        (pos[0] as num).toDouble(),
        (pos[1] as num).toDouble(),
      ),
      color: Color(map['color'] as int),
      fontSize: (map['fontSize'] as num).toDouble(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// LassoSelection — transient selection state
// ─────────────────────────────────────────────────────────────────

/// Represents the current lasso selection state.
class LassoSelection {
  /// The path drawn by the user to select items (normalized).
  final List<Offset> pathPoints;

  /// Indices of selected strokes on the current page.
  final Set<int> selectedStrokeIndices;

  /// IDs of selected text annotations on the current page.
  final Set<String> selectedTextIds;

  /// The offset applied to the selected group during a drag operation.
  final Offset dragOffset;

  /// Rotation angle in radians applied to the selection group.
  final double rotationAngle;

  const LassoSelection({
    this.pathPoints = const [],
    this.selectedStrokeIndices = const {},
    this.selectedTextIds = const {},
    this.dragOffset = Offset.zero,
    this.rotationAngle = 0.0,
  });

  bool get isEmpty => selectedStrokeIndices.isEmpty && selectedTextIds.isEmpty;

  /// Computes the bounding rectangle (normalized 0–1) of all selected items,
  /// shifted by [dragOffset]. Returns null if nothing is selected.
  Rect? computeBounds(List<DrawingPath> strokes, List<TextAnnotation> texts) {
    if (isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    bool hasPoints = false;

    for (final i in selectedStrokeIndices) {
      if (i < strokes.length) {
        for (final p in strokes[i].points) {
          final px = p.dx + dragOffset.dx;
          final py = p.dy + dragOffset.dy;
          if (px < minX) minX = px;
          if (py < minY) minY = py;
          if (px > maxX) maxX = px;
          if (py > maxY) maxY = py;
          hasPoints = true;
        }
      }
    }

    for (final t in texts) {
      if (selectedTextIds.contains(t.id)) {
        final px = t.position.dx + dragOffset.dx;
        final py = t.position.dy + dragOffset.dy;
        if (px < minX) minX = px;
        if (py < minY) minY = py;
        if (px > maxX) maxX = px;
        if (py > maxY) maxY = py;
        hasPoints = true;
      }
    }

    if (!hasPoints) return null;

    // Add small padding so text/thin strokes get a usable box
    const pad = 0.015;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  /// Returns the center of the bounding box (normalized), or null.
  Offset? computeCenter(List<DrawingPath> strokes, List<TextAnnotation> texts) {
    final bounds = computeBounds(strokes, texts);
    return bounds?.center;
  }

  /// Rotates a point around [center] by [angle] radians.
  static Offset rotatePoint(Offset point, Offset center, double angle) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    return Offset(
      center.dx + dx * cosA - dy * sinA,
      center.dy + dx * sinA + dy * cosA,
    );
  }

  LassoSelection copyWith({
    List<Offset>? pathPoints,
    Set<int>? selectedStrokeIndices,
    Set<String>? selectedTextIds,
    Offset? dragOffset,
    double? rotationAngle,
  }) {
    return LassoSelection(
      pathPoints: pathPoints ?? this.pathPoints,
      selectedStrokeIndices:
          selectedStrokeIndices ?? this.selectedStrokeIndices,
      selectedTextIds: selectedTextIds ?? this.selectedTextIds,
      dragOffset: dragOffset ?? this.dragOffset,
      rotationAngle: rotationAngle ?? this.rotationAngle,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// DocumentDrawingState — all annotation data for one document
// ─────────────────────────────────────────────────────────────────

class DocumentDrawingState {
  final String filePath;

  /// Current tool mode.
  final AnnotationMode annotationMode;

  /// Active pen color.
  final Color selectedColor;

  /// Active pen stroke width.
  final double selectedStrokeWidth;

  /// Map of page index → completed freehand strokes.
  final Map<int, List<DrawingPath>> pageStrokes;

  /// Map of page index → text annotations.
  final Map<int, List<TextAnnotation>> pageTextAnnotations;

  /// The stroke currently being drawn (null when not drawing).
  final DrawingPath? activeStroke;

  /// The page on which the active stroke is being drawn.
  final int? activePageIndex;

  /// Transformation/selection state for the lasso tool.
  final LassoSelection? lassoSelection;

  const DocumentDrawingState({
    this.filePath = '',
    this.annotationMode = AnnotationMode.none,
    this.selectedColor = const Color(0xFFFF5252),
    this.selectedStrokeWidth = 3.0,
    this.pageStrokes = const {},
    this.pageTextAnnotations = const {},
    this.activeStroke,
    this.activePageIndex,
    this.lassoSelection,
  });

  /// Whether any annotation mode is active (pen or text).
  bool get isAnnotating => annotationMode != AnnotationMode.none;

  List<DrawingPath> strokesForPage(int pageIndex) {
    return pageStrokes[pageIndex] ?? const [];
  }

  List<TextAnnotation> textAnnotationsForPage(int pageIndex) {
    return pageTextAnnotations[pageIndex] ?? const [];
  }

  DocumentDrawingState copyWith({
    String? filePath,
    AnnotationMode? annotationMode,
    Color? selectedColor,
    double? selectedStrokeWidth,
    Map<int, List<DrawingPath>>? pageStrokes,
    Map<int, List<TextAnnotation>>? pageTextAnnotations,
    DrawingPath? activeStroke,
    int? activePageIndex,
    LassoSelection? lassoSelection,
    bool clearActiveStroke = false,
  }) {
    return DocumentDrawingState(
      filePath: filePath ?? this.filePath,
      annotationMode: annotationMode ?? this.annotationMode,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedStrokeWidth: selectedStrokeWidth ?? this.selectedStrokeWidth,
      pageStrokes: pageStrokes ?? this.pageStrokes,
      pageTextAnnotations: pageTextAnnotations ?? this.pageTextAnnotations,
      activeStroke:
          clearActiveStroke ? null : (activeStroke ?? this.activeStroke),
      activePageIndex:
          clearActiveStroke ? null : (activePageIndex ?? this.activePageIndex),
      lassoSelection: lassoSelection ?? this.lassoSelection,
    );
  }

  Map<String, dynamic> toMap() {
    final strokesMap = <String, dynamic>{};
    for (final entry in pageStrokes.entries) {
      strokesMap[entry.key.toString()] =
          entry.value.map((s) => s.toMap()).toList();
    }

    final textMap = <String, dynamic>{};
    for (final entry in pageTextAnnotations.entries) {
      textMap[entry.key.toString()] =
          entry.value.map((t) => t.toMap()).toList();
    }

    return {
      'filePath': filePath,
      'pageStrokes': strokesMap,
      'pageTextAnnotations': textMap,
    };
  }

  factory DocumentDrawingState.fromMap(Map<dynamic, dynamic> map) {
    // Strokes
    final rawStrokes = map['pageStrokes'] as Map<dynamic, dynamic>? ?? {};
    final pageStrokes = <int, List<DrawingPath>>{};
    for (final entry in rawStrokes.entries) {
      final pageIndex = int.parse(entry.key.toString());
      final strokes = (entry.value as List<dynamic>)
          .map((s) => DrawingPath.fromMap(s as Map<dynamic, dynamic>))
          .toList();
      pageStrokes[pageIndex] = strokes;
    }

    // Text annotations
    final rawText =
        map['pageTextAnnotations'] as Map<dynamic, dynamic>? ?? {};
    final pageTextAnnotations = <int, List<TextAnnotation>>{};
    for (final entry in rawText.entries) {
      final pageIndex = int.parse(entry.key.toString());
      final annotations = (entry.value as List<dynamic>)
          .map((t) => TextAnnotation.fromMap(t as Map<dynamic, dynamic>))
          .toList();
      pageTextAnnotations[pageIndex] = annotations;
    }

    return DocumentDrawingState(
      filePath: (map['filePath'] as String?) ?? '',
      pageStrokes: pageStrokes,
      pageTextAnnotations: pageTextAnnotations,
    );
  }
}
