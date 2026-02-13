/// Centralized constants for the drawing/annotation subsystem.
///
/// Replaces magic numbers scattered across [DrawingPainter],
/// [DrawingNotifier], and [SidecarState].
class DrawingConstants {
  DrawingConstants._();

  // ── Rotation Handle ────────────────────────────────────────────
  /// Normalized offset above the selection box for the rotation handle.
  static const double rotationHandleOffset = 0.04;

  /// Hit-test radius (normalized) around the rotation handle.
  static const double rotationHandleHitRadius = 0.025;

  // ── Selection Box ──────────────────────────────────────────────
  /// Corner handle radius in pixels.
  static const double cornerHandleRadius = 4.0;

  /// Rotation handle nub radius in pixels.
  static const double rotationHandleNubRadius = 6.0;

  /// Length of the rotation handle stem in pixels.
  static const double rotationHandleStemLength = 24.0;

  // ── Performance ────────────────────────────────────────────────
  /// Minimum interval between rotation update frames (ms).
  /// Caps state mutations at ~60fps.
  static const int rotationThrottleMs = 16;

  /// Debounce delay for auto-saving drawing state (ms).
  static const int saveDebounceMs = 500;

  // ── Sidecar Canvas ─────────────────────────────────────────────
  /// Maximum canvas height in logical pixels (prevents OOM).
  static const double sidecarMaxCanvasHeight = 20000.0;

  /// Initial canvas height in logical pixels.
  static const double sidecarInitialHeight = 2000.0;

  /// Canvas height growth increment in logical pixels.
  static const double sidecarGrowthStep = 500.0;

  /// Threshold from bottom edge to trigger auto-grow (px).
  static const double sidecarGrowthThreshold = 200.0;

  // ── Stroke Defaults ────────────────────────────────────────────
  /// Default stroke width for new paths.
  static const double defaultStrokeWidth = 3.0;

  /// Minimum stroke width in the picker.
  static const double minStrokeWidth = 1.0;

  /// Maximum stroke width in the picker.
  static const double maxStrokeWidth = 20.0;

  // ── Dashed Lines ───────────────────────────────────────────────
  /// Dash width for lasso path and selection border.
  static const double dashWidth = 5.0;

  /// Dash gap for lasso path and selection border.
  static const double dashSpace = 5.0;

  // ── Selection Border ───────────────────────────────────────────
  /// Width of the dashed selection border.
  static const double selectionBorderWidth = 1.5;

  /// Lasso path line width.
  static const double lassoPathWidth = 2.0;

  /// Highlight padding around selected strokes (extra width).
  static const double selectionHighlightExtra = 4.0;
}
