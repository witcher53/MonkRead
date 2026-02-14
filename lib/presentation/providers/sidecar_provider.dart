import 'dart:ui' show Color, Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/data/repositories/sidecar_repository_impl.dart';
import 'package:monkread/domain/entities/drawing_state.dart';
import 'package:monkread/domain/entities/sidecar_state.dart';
import 'package:monkread/domain/repositories/sidecar_repository.dart';

// ── Repository provider ──────────────────────────────────────────

final sidecarRepositoryProvider = Provider<SidecarRepository>((ref) {
  return SidecarRepositoryImpl();
});

// ── Notifier ─────────────────────────────────────────────────────

class SidecarNotifier extends StateNotifier<SidecarState> {
  final SidecarRepository _repository;

  SidecarNotifier(this._repository) : super(const SidecarState());

  // ── File lifecycle ─────────────────────────────────────────────

  Future<void> loadForFile(String filePath) async {
    state = SidecarState(filePath: filePath);
    final saved = await _repository.loadNotes(filePath);
    if (saved != null) {
      state = saved.copyWith(filePath: filePath);
    }
  }

  void clearState() {
    state = const SidecarState();
  }

  // ── Pen color & width (uses values from drawing provider) ──────

  Color _penColor = const Color(0xFFFF5252);
  double _penWidth = 3.0;

  void setPenSettings(Color color, double width) {
    _penColor = color;
    _penWidth = width;
  }

  // ── Stroke lifecycle ───────────────────────────────────────────

  void startStroke(Offset point) {
    state = state.copyWith(
      activeStroke: DrawingPath(
        points: [point],
        color: _penColor,
        strokeWidth: _penWidth,
      ),
    );
  }

  void addPoint(Offset point) {
    final stroke = state.activeStroke;
    if (stroke == null) return;
    state = state.copyWith(activeStroke: stroke.addPoint(point));

    // Auto-grow canvas if drawing near bottom
    final maxY = point.dy * state.canvasHeight;
    if (maxY > state.canvasHeight - 200) {
      state = state.copyWith(canvasHeight: state.canvasHeight + 500);
    }
  }

  Future<void> finishStroke() async {
    final stroke = state.activeStroke;
    if (stroke == null) return;

    if (stroke.points.length < 2) {
      state = state.copyWith(clearActiveStroke: true);
      return;
    }

    final updated = List<DrawingPath>.from(state.strokes)..add(stroke);
    state = state.copyWith(strokes: updated, clearActiveStroke: true);
    await _persist();
  }

  Future<void> undoLastStroke() async {
    if (state.strokes.isEmpty) return;
    final updated = List<DrawingPath>.from(state.strokes)..removeLast();
    state = state.copyWith(strokes: updated);
    await _persist();
  }

  // ── Text annotations ──────────────────────────────────────────

  Future<void> addTextAnnotation(TextAnnotation annotation) async {
    final updated = List<TextAnnotation>.from(state.textAnnotations)
      ..add(annotation);
    state = state.copyWith(textAnnotations: updated);
    await _persist();
  }

  Future<void> removeTextAnnotation(String id) async {
    final updated = List<TextAnnotation>.from(state.textAnnotations)
      ..removeWhere((t) => t.id == id);
    state = state.copyWith(textAnnotations: updated);
    await _persist();
  }

  Future<void> updateTextAnnotation(TextAnnotation annotation) async {
    final updated = List<TextAnnotation>.from(state.textAnnotations);
    final idx = updated.indexWhere((t) => t.id == annotation.id);
    if (idx == -1) return;
    updated[idx] = annotation;
    state = state.copyWith(textAnnotations: updated);
    await _persist();
  }

  // ── Private ────────────────────────────────────────────────────

  Future<void> _persist() async {
    if (state.filePath.isEmpty) return;
    await _repository.saveNotes(state.filePath, state);
  }
}

// ── Provider ─────────────────────────────────────────────────────

final sidecarProvider =
    StateNotifierProvider<SidecarNotifier, SidecarState>((ref) {
  final repository = ref.watch(sidecarRepositoryProvider);
  return SidecarNotifier(repository);
});
