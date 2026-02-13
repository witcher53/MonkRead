import 'package:hive/hive.dart';
import 'package:monkread/domain/entities/sidecar_state.dart';
import 'package:monkread/domain/repositories/sidecar_repository.dart';

/// Hive-backed sidecar notes persistence.
///
/// Uses box `'sidecar_notes'`, keyed by the primary PDF file path.
class SidecarRepositoryImpl implements SidecarRepository {
  static const _boxName = 'sidecar_notes';

  Future<Box<dynamic>> _openBox() async => Hive.openBox(_boxName);

  @override
  Future<SidecarState?> loadNotes(String filePath) async {
    final box = await _openBox();
    final raw = box.get(filePath);
    if (raw == null) return null;
    return SidecarState.fromMap(raw as Map<dynamic, dynamic>);
  }

  @override
  Future<void> saveNotes(String filePath, SidecarState state) async {
    final box = await _openBox();
    await box.put(filePath, state.toMap());
  }

  @override
  Future<void> deleteNotes(String filePath) async {
    final box = await _openBox();
    await box.delete(filePath);
  }
}
