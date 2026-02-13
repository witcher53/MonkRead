import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Path;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/data/repositories/drawing_repository_impl.dart';
import 'package:monkread/domain/entities/drawing_state.dart';
import 'package:monkread/domain/repositories/drawing_repository.dart';

// ── Repository provider ──────────────────────────────────────────

final drawingRepositoryProvider = Provider<DrawingRepository>((ref) {
  return DrawingRepositoryImpl();
});

// ── State provider ───────────────────────────────────────────────

final drawingProvider =
    StateNotifierProvider<DrawingNotifier, DocumentDrawingState>((ref) {
  final repo = ref.watch(drawingRepositoryProvider);
  return DrawingNotifier(repo);
});

// ── Notifier ─────────────────────────────────────────────────────

class DrawingNotifier extends StateNotifier<DocumentDrawingState> {
  final DrawingRepository _repository;

  DrawingNotifier(this._repository) : super(const DocumentDrawingState());

  // ── File Loading & Persistence ─────────────────────────────────

  /// Load drawing data for the given file PDF
  Future<void> loadForFile(String filePath) async {
    // Calling repository with the required signature
    final loaded = await _repository.loadDrawingState(filePath);
    if (loaded != null) {
      state = loaded;
    } else {
      state = DocumentDrawingState(filePath: filePath);
    }
  }

  Future<void> _persistDrawings() async {
    if (state.filePath.isNotEmpty) {
      // Calling repository with the required signature
      await _repository.saveDrawingState(state);
    }
  }

  void clearState() {
    state = const DocumentDrawingState();
  }

  // ── Debounced Saving ──────────────────────────────────────────

  Timer? _saveTimer;

  void _saveDebounced() {
    if (_saveTimer?.isActive ?? false) _saveTimer!.cancel();
    
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      debugPrint("Auto-saving drawing state...");
      await _persistDrawings();
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ── Tool Selection ─────────────────────────────────────────────

  void setAnnotationMode(AnnotationMode mode) {
    // If switching away from lasso, clear selection
    if (state.annotationMode == AnnotationMode.lasso &&
        mode != AnnotationMode.lasso) {
      clearLassoSelection();
    }
    state = state.copyWith(annotationMode: mode);
  }

  void togglePenMode() {
    setAnnotationMode(
        state.annotationMode == AnnotationMode.pen
            ? AnnotationMode.none
            : AnnotationMode.pen);
  }

  void toggleTextMode() {
    setAnnotationMode(
        state.annotationMode == AnnotationMode.text
            ? AnnotationMode.none
            : AnnotationMode.text);
  }

  void toggleLassoMode() {
    setAnnotationMode(
        state.annotationMode == AnnotationMode.lasso
            ? AnnotationMode.none
            : AnnotationMode.lasso);
  }

  void setActivePage(int pageIndex) {
    if (state.activePageIndex != pageIndex) {
      state = state.copyWith(activePageIndex: pageIndex);
    }
  }

  void setColor(Color color) {
    state = state.copyWith(selectedColor: color);
  }

  void setStrokeWidth(double width) {
    state = state.copyWith(selectedStrokeWidth: width);
  }

  // ── Pen Logic ──────────────────────────────────────────────────

  void startStroke(int pageIndex, Offset normalizedPoint) {
    if (state.annotationMode != AnnotationMode.pen) return;
    
    // Start a new path
    final newPath = DrawingPath(
      points: [normalizedPoint],
      color: state.selectedColor,
      strokeWidth: state.selectedStrokeWidth,
    );

    state = state.copyWith(
      activePageIndex: pageIndex,
      activeStroke: newPath,
    );
  }

  void addPoint(Offset normalizedPoint) {
    if (state.activeStroke == null) return;
    state = state.copyWith(
      activeStroke: state.activeStroke!.addPoint(normalizedPoint),
    );
  }

  void finishStroke() {
    final pageIndex = state.activePageIndex;
    final stroke = state.activeStroke;

    if (pageIndex != null && stroke != null && stroke.points.isNotEmpty) {
      final currentStrokes = state.strokesForPage(pageIndex);
      final newStrokes = List<DrawingPath>.from(currentStrokes)..add(stroke);
      
      final updatedPageStrokes = Map<int, List<DrawingPath>>.from(state.pageStrokes);
      updatedPageStrokes[pageIndex] = newStrokes;

      state = state.copyWith(
        pageStrokes: updatedPageStrokes,
        clearActiveStroke: true,
      );
      _saveDebounced();
    } else {
      state = state.copyWith(clearActiveStroke: true);
    }
  }

  void undoLastStroke(int pageIndex) {
    final strokes = state.strokesForPage(pageIndex);
    if (strokes.isNotEmpty) {
      final newStrokes = List<DrawingPath>.from(strokes)..removeLast();
      final updatedPageStrokes = Map<int, List<DrawingPath>>.from(state.pageStrokes);
      updatedPageStrokes[pageIndex] = newStrokes;
      state = state.copyWith(pageStrokes: updatedPageStrokes);
      _saveDebounced();
    }
  }

  void clearCurrentPage() {
    final pageIndex = state.activePageIndex;
    if (pageIndex == null) return;
    
    final updatedStrokes = Map<int, List<DrawingPath>>.from(state.pageStrokes);
    updatedStrokes.remove(pageIndex);
    
    final updatedTexts = Map<int, List<TextAnnotation>>.from(state.pageTextAnnotations);
    updatedTexts.remove(pageIndex);

    state = state.copyWith(
      pageStrokes: updatedStrokes,
      pageTextAnnotations: updatedTexts,
      lassoSelection: null,
    );
    _saveDebounced();
  }

  // ── Text Logic ─────────────────────────────────────────────────

  void addTextAnnotation(int pageIndex, TextAnnotation annotation) {
    final currentTexts = state.textAnnotationsForPage(pageIndex);
    final newTexts = List<TextAnnotation>.from(currentTexts)..add(annotation);
    
    final updatedPageTexts = Map<int, List<TextAnnotation>>.from(state.pageTextAnnotations);
    updatedPageTexts[pageIndex] = newTexts;

    state = state.copyWith(pageTextAnnotations: updatedPageTexts);
    _saveDebounced();
  }

  void updateTextAnnotation(int pageIndex, TextAnnotation annotation) {
    final currentTexts = state.textAnnotationsForPage(pageIndex);
    final index = currentTexts.indexWhere((t) => t.id == annotation.id);
    if (index == -1) return;

    final newTexts = List<TextAnnotation>.from(currentTexts);
    newTexts[index] = annotation;

    final updatedPageTexts = Map<int, List<TextAnnotation>>.from(state.pageTextAnnotations);
    updatedPageTexts[pageIndex] = newTexts;

    state = state.copyWith(pageTextAnnotations: updatedPageTexts);
    _saveDebounced();
  }

  void removeTextAnnotation(int pageIndex, String id) {
    final currentTexts = state.textAnnotationsForPage(pageIndex);
    final newTexts = currentTexts.where((t) => t.id != id).toList();

    final updatedPageTexts = Map<int, List<TextAnnotation>>.from(state.pageTextAnnotations);
    updatedPageTexts[pageIndex] = newTexts;

    state = state.copyWith(pageTextAnnotations: updatedPageTexts);
    _saveDebounced();
  }

  // ── Lasso Logic ────────────────────────────────────────────────

  void startLasso(int pageIndex, Offset point) {
    state = state.copyWith(
      activePageIndex: pageIndex,
      lassoSelection: LassoSelection(
        pathPoints: [point],
        selectedStrokeIndices: {},
        selectedTextIds: {},
      ),
    );
  }

  void addLassoPoint(Offset point) {
    final lasso = state.lassoSelection;
    if (lasso == null) return;
    state = state.copyWith(
      lassoSelection: lasso.copyWith(
        pathPoints: [...lasso.pathPoints, point],
      ),
    );
  }

  void finishLasso() {
    final lasso = state.lassoSelection;
    final pageIndex = state.activePageIndex;
    if (lasso == null || pageIndex == null) return;

    // Close the path
    final pathPoints = lasso.pathPoints;
    if (pathPoints.length < 3) {
      clearLassoSelection();
      return;
    }

    // Identify selected strokes
    final strokes = state.strokesForPage(pageIndex);
    final selectedIndices = <int>{};
    
    final path = Path();
    path.moveTo(pathPoints.first.dx, pathPoints.first.dy);
    for (int i = 1; i < pathPoints.length; i++) {
      path.lineTo(pathPoints[i].dx, pathPoints[i].dy);
    }
    path.close();

    // Check strokes
    for (int i = 0; i < strokes.length; i++) {
      // If any point of the stroke is inside the lasso path
      bool isSelected = false;
      for (final p in strokes[i].points) {
        if (path.contains(p)) {
          isSelected = true;
          break;
        }
      }
      if (isSelected) selectedIndices.add(i);
    }

    // Check text annotations
    final texts = state.textAnnotationsForPage(pageIndex);
    final selectedTextIds = <String>{};
    for (final t in texts) {
      if (path.contains(t.position)) {
        selectedTextIds.add(t.id);
      }
    }

    if (selectedIndices.isEmpty && selectedTextIds.isEmpty) {
      clearLassoSelection();
    } else {
      state = state.copyWith(
        lassoSelection: lasso.copyWith(
          selectedStrokeIndices: selectedIndices,
          selectedTextIds: selectedTextIds,
          pathPoints: [], // clear the visual loop
        ),
      );
    }
  }

  void clearLassoSelection() {
    state = state.copyWith(lassoSelection: null);
  }

  void deleteSelection() {
    final lasso = state.lassoSelection;
    final pageIndex = state.activePageIndex;
    if (lasso == null || pageIndex == null) return;

    // Remove strokes
    final strokes = state.strokesForPage(pageIndex);
    final newStrokes = <DrawingPath>[];
    for (int i = 0; i < strokes.length; i++) {
      if (!lasso.selectedStrokeIndices.contains(i)) {
        newStrokes.add(strokes[i]);
      }
    }

    // Remove texts
    final texts = state.textAnnotationsForPage(pageIndex);
    final newTexts = texts.where((t) => !lasso.selectedTextIds.contains(t.id)).toList();

    final updatedPageStrokes = Map<int, List<DrawingPath>>.from(state.pageStrokes);
    updatedPageStrokes[pageIndex] = newStrokes;

    final updatedPageTexts = Map<int, List<TextAnnotation>>.from(state.pageTextAnnotations);
    updatedPageTexts[pageIndex] = newTexts;

    state = state.copyWith(
      pageStrokes: updatedPageStrokes,
      pageTextAnnotations: updatedPageTexts,
      lassoSelection: null,
    );
    _saveDebounced();
  }

  // ── Drag & Rotate Logic (Visual Matrix) ────────────────────────

  Offset? _lastPanPosition;
  bool _isMovingSelection = false;
  bool _isRotating = false;
  Offset? _fixedPivot; // The center of rotation (Fixed during drag)
  double _rotationStartAngle = 0.0;
  double _rotationInitial = 0.0;

  void handlePanStart(int pageIndex, Offset point) {
    if (state.activePageIndex != pageIndex) {
      setActivePage(pageIndex);
    }

    if (state.annotationMode == AnnotationMode.pen) {
       startStroke(pageIndex, point);
    } else if (state.annotationMode == AnnotationMode.lasso) {
      final lasso = state.lassoSelection;
      
      // Check interactions with existing selection
      if (lasso != null && !lasso.isEmpty) {
        // 1. Check Rotation Handle
        if (_isPointOnRotationHandle(pageIndex, point, lasso)) {
          _lastPanPosition = point;
          _isRotating = true;
          _isMovingSelection = false;

          // CALCULATE STABLE PIVOT ONCE
          final strokes = state.strokesForPage(pageIndex);
          final texts = state.textAnnotationsForPage(pageIndex);
          final bounds = lasso.computeBounds(strokes, texts);
          
          if (bounds != null) {
            _fixedPivot = bounds.center; // CACHE IT
            _rotationStartAngle = math.atan2(
              point.dy - _fixedPivot!.dy,
              point.dx - _fixedPivot!.dx,
            );
            _rotationInitial = lasso.rotationAngle;
          }
          return;
        }

        // 2. Check Move Selection
        if (_isPointInSelection(pageIndex, point, lasso)) {
          _lastPanPosition = point;
          _isMovingSelection = true;
          _isRotating = false;
          _fixedPivot = null;
          return;
        }
      }

      // 3. New Lasso
      _isMovingSelection = false;
      _isRotating = false;
      _fixedPivot = null;
      startLasso(pageIndex, point);
    }
  }

  void handlePanUpdate(Offset point) {
    if (state.annotationMode == AnnotationMode.pen) {
      addPoint(point);
    } else if (state.annotationMode == AnnotationMode.lasso) {
      if (_isRotating) {
        _updateRotation(point);
      } else if (_isMovingSelection) {
        if (_lastPanPosition != null) {
          final delta = point - _lastPanPosition!;
          moveSelection(delta);
        }
        _lastPanPosition = point;
      } else {
        addLassoPoint(point);
      }
    }
  }

  void handlePanEnd() {
    if (state.annotationMode == AnnotationMode.pen) {
      finishStroke();
    } else if (state.annotationMode == AnnotationMode.lasso) {
      if (_isRotating) {
        applyRotation(); // Commit the visual rotation to data
        _isRotating = false;
        _lastPanPosition = null;
        _fixedPivot = null;
      } else if (_isMovingSelection) {
        applySelectionMove(); 
        _isMovingSelection = false;
        _lastPanPosition = null;
      } else {
        finishLasso();
      }
    }
  }

  // ── Helper Predicates ──────────────────────────────────────────

  static const double _rotationHandleOffset = 0.04;
  static const double _rotationHandleHitRadius = 0.025;

  bool _isPointOnRotationHandle(int pageIndex, Offset point, LassoSelection lasso) {
    final strokes = state.strokesForPage(pageIndex);
    final texts = state.textAnnotationsForPage(pageIndex);
    final bounds = lasso.computeBounds(strokes, texts);
    if (bounds == null) return false;
    
    final center = bounds.center;
    final topCenter = Offset(center.dx, bounds.top - _rotationHandleOffset);
    final rotatedHandle = LassoSelection.rotatePoint(topCenter, center, lasso.rotationAngle);
    
    final dist = (point - rotatedHandle).distance;
    return dist < _rotationHandleHitRadius;
  }

  bool _isPointInSelection(int pageIndex, Offset point, LassoSelection lasso) {
    final strokes = state.strokesForPage(pageIndex);
    final texts = state.textAnnotationsForPage(pageIndex);
    final bounds = lasso.computeBounds(strokes, texts);
    if (bounds == null) return false;

    // Check if point inside rotated rectangle
    final center = bounds.center;
    final unrotatedPoint = LassoSelection.rotatePoint(point, center, -lasso.rotationAngle);
    
    return bounds.contains(unrotatedPoint);
  }

  // ── Transform Implementation ───────────────────────────────────

  void moveSelection(Offset delta) {
    final lasso = state.lassoSelection;
    if (lasso == null) return;

    state = state.copyWith(
      lassoSelection: lasso.copyWith(
        dragOffset: lasso.dragOffset + delta,
      ),
    );
  }

  DateTime _lastRotationUpdate = DateTime(0);

  void _updateRotation(Offset point) {
    // Throttle: skip updates if < 16ms since last (cap at ~60fps)
    final now = DateTime.now();
    if (now.difference(_lastRotationUpdate).inMilliseconds < 16) return;
    _lastRotationUpdate = now;

    // VISUAL ONLY: Update angle. DO NOT MODIFY POINTS.
    final lasso = state.lassoSelection;
    if (lasso == null || _fixedPivot == null) return;

    final currentAngle = math.atan2(
      point.dy - _fixedPivot!.dy,
      point.dx - _fixedPivot!.dx,
    );

    final newAngle = _rotationInitial + (currentAngle - _rotationStartAngle);

    state = state.copyWith(
      lassoSelection: lasso.copyWith(rotationAngle: newAngle),
    );
  }

  void applyRotation() {
    final lasso = state.lassoSelection;
    if (lasso == null || lasso.isEmpty) return;
    if (lasso.rotationAngle == 0.0) return;

    final pageIndex = state.activePageIndex;
    if (pageIndex == null) return;
    
    final center = _fixedPivot; 
    if (center == null) return;

    final angle = lasso.rotationAngle;

    // 1. Bake strokes
    final currentStrokes = state.strokesForPage(pageIndex);
    final newStrokes = List<DrawingPath>.from(currentStrokes);

    for (final i in lasso.selectedStrokeIndices) {
      if (i < newStrokes.length) {
        final oldPath = newStrokes[i];
        final newPoints = oldPath.points.map((p) {
          final pWithDrag = p + lasso.dragOffset;
          return LassoSelection.rotatePoint(pWithDrag, center, angle);
        }).toList();
        
        newStrokes[i] = DrawingPath(
          points: newPoints,
          color: oldPath.color,
          strokeWidth: oldPath.strokeWidth,
        );
      }
    }

    // 2. Bake texts
    final currentTexts = state.textAnnotationsForPage(pageIndex);
    final newTexts = List<TextAnnotation>.from(currentTexts);

    final textMap = {for (var t in newTexts) t.id: t};
    
    for (final id in lasso.selectedTextIds) {
      if (textMap.containsKey(id)) {
        final t = textMap[id]!;
        final pWithDrag = t.position + lasso.dragOffset;
        final newPos = LassoSelection.rotatePoint(pWithDrag, center, angle);
        
        textMap[id] = t.copyWith(position: newPos);
      }
    }
    
    final finalTexts = textMap.values.toList();

    // 3. Update State & Reset Lasso
    final updatedPageStrokes = Map<int, List<DrawingPath>>.from(state.pageStrokes);
    updatedPageStrokes[pageIndex] = newStrokes;

    final updatedPageTexts = Map<int, List<TextAnnotation>>.from(state.pageTextAnnotations);
    updatedPageTexts[pageIndex] = finalTexts;

    state = state.copyWith(
      pageStrokes: updatedPageStrokes,
      pageTextAnnotations: updatedPageTexts,
      // Reset rotation & dragOffset because we baked them in
      lassoSelection: lasso.copyWith(
        rotationAngle: 0.0,
        dragOffset: Offset.zero, 
      ),
    );
    
    _saveDebounced();
  }
  
  void applySelectionMove() {
     final lasso = state.lassoSelection;
    if (lasso == null || lasso.isEmpty) return;
    if (lasso.dragOffset == Offset.zero) return;

    final pageIndex = state.activePageIndex;
    if (pageIndex == null) return;

    // Bake dragOffset
    final currentStrokes = state.strokesForPage(pageIndex);
    final newStrokes = List<DrawingPath>.from(currentStrokes);

    for (final i in lasso.selectedStrokeIndices) {
      if (i < newStrokes.length) {
        final oldPath = newStrokes[i];
        final newPoints = oldPath.points.map((p) => p + lasso.dragOffset).toList();
        newStrokes[i] = DrawingPath(
          points: newPoints,
          color: oldPath.color,
          strokeWidth: oldPath.strokeWidth,
        );
      }
    }

    final currentTexts = state.textAnnotationsForPage(pageIndex);
    final newTexts = currentTexts.map((t) {
      if (lasso.selectedTextIds.contains(t.id)) {
        return t.copyWith(position: t.position + lasso.dragOffset);
      }
      return t;
    }).toList();

    final updatedPageStrokes = Map<int, List<DrawingPath>>.from(state.pageStrokes);
    updatedPageStrokes[pageIndex] = newStrokes;

    final updatedPageTexts = Map<int, List<TextAnnotation>>.from(state.pageTextAnnotations);
    updatedPageTexts[pageIndex] = newTexts;

    state = state.copyWith(
      pageStrokes: updatedPageStrokes,
      pageTextAnnotations: updatedPageTexts,
      lassoSelection: lasso.copyWith(dragOffset: Offset.zero),
    );
     _saveDebounced();
  }
}
