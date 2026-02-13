import 'package:monkread/domain/entities/drawing_state.dart';

/// State for the sidecar (infinite whiteboard) notes panel.
///
/// Keyed by the primary PDF's [filePath]. Strokes and text use
/// normalized coordinates (0–1) relative to canvas width, but
/// Y can exceed 1.0 since the canvas scrolls infinitely.
class SidecarState {
  /// Hard limit to prevent OOM from infinite canvas growth.
  static const double maxCanvasHeight = 20000.0;

  final String filePath;
  final List<DrawingPath> strokes;
  final List<TextAnnotation> textAnnotations;
  final DrawingPath? activeStroke;

  /// Logical canvas height. Grows as the user draws further down.
  final double canvasHeight;

  const SidecarState({
    this.filePath = '',
    this.strokes = const [],
    this.textAnnotations = const [],
    this.activeStroke,
    this.canvasHeight = 2000.0,
  });

  SidecarState copyWith({
    String? filePath,
    List<DrawingPath>? strokes,
    List<TextAnnotation>? textAnnotations,
    DrawingPath? activeStroke,
    bool clearActiveStroke = false,
    double? canvasHeight,
  }) {
    return SidecarState(
      filePath: filePath ?? this.filePath,
      strokes: strokes ?? this.strokes,
      textAnnotations: textAnnotations ?? this.textAnnotations,
      activeStroke:
          clearActiveStroke ? null : (activeStroke ?? this.activeStroke),
      canvasHeight: canvasHeight ?? this.canvasHeight,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'strokes': strokes.map((s) => s.toMap()).toList(),
      'textAnnotations': textAnnotations.map((t) => t.toMap()).toList(),
      'canvasHeight': canvasHeight,
    };
  }

  factory SidecarState.fromMap(Map<dynamic, dynamic> map) {
    return SidecarState(
      filePath: (map['filePath'] as String?) ?? '',
      strokes: (map['strokes'] as List<dynamic>? ?? [])
          .map((s) => DrawingPath.fromMap(s as Map<dynamic, dynamic>))
          .toList(),
      textAnnotations: (map['textAnnotations'] as List<dynamic>? ?? [])
          .map((t) => TextAnnotation.fromMap(t as Map<dynamic, dynamic>))
          .toList(),
      canvasHeight: (map['canvasHeight'] as num?)?.toDouble() ?? 2000.0,
    );
  }
}
