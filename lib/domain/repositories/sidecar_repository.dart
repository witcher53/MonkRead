import 'package:monkread/domain/entities/sidecar_state.dart';

/// Abstract repository for sidecar (whiteboard) notes persistence.
abstract class SidecarRepository {
  Future<SidecarState?> loadNotes(String filePath);
  Future<void> saveNotes(String filePath, SidecarState state);
  Future<void> deleteNotes(String filePath);
}
