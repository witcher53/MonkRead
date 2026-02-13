import 'package:monkread/domain/entities/drawing_state.dart';

/// Abstract contract for drawing persistence operations.
abstract class DrawingRepository {
  /// Loads all drawing strokes for a specific file (bookId).
  /// Returns null if no drawings exist for this file.
  Future<DocumentDrawingState?> loadDrawingState(String bookId);

  /// Saves all drawing strokes for a specific file.
  Future<void> saveDrawingState(DocumentDrawingState state);
}
