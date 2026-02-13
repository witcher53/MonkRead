import 'package:hive/hive.dart';
import 'package:monkread/domain/entities/drawing_state.dart';
import 'package:monkread/domain/repositories/drawing_repository.dart';

/// Hive-backed implementation of [DrawingRepository].
class DrawingRepositoryImpl implements DrawingRepository {
  static const String _boxName = 'drawings';

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  @override
  Future<DocumentDrawingState?> loadDrawingState(String bookId) async {
    final box = await _openBox();
    final raw = box.get(bookId);

    if (raw == null || raw is! Map) return null;

    try {
      return DocumentDrawingState.fromMap(raw);
    } catch (_) {
      // Corrupted data — return null
      return null;
    }
  }

  @override
  Future<void> saveDrawingState(DocumentDrawingState state) async {
    final box = await _openBox();
    // Use the file path as the unique key
    await box.put(state.filePath, state.toMap());
  }
}
