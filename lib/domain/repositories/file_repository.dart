import 'package:monkread/domain/entities/pdf_document.dart';

/// Abstract contract for file operations.
///
/// The domain layer depends only on this interface.
/// Concrete implementations live in the data layer.
abstract class FileRepository {
  /// Requests storage permission from the OS.
  ///
  /// Returns `true` if permission was granted (or was already granted).
  Future<bool> requestStoragePermission();

  /// Opens a native file picker filtered to PDF files.
  ///
  /// Returns a [PdfDocument] if a file was selected, or `null` if the user
  /// cancelled the picker.
  Future<PdfDocument?> pickPdfFile();

  /// Retrieves the last opened PDF document (Web persistence).
  /// Returns `null` on native platforms or if no file is cached.
  Future<PdfDocument?> getLastOpenedPdf();

  /// Clears the last cached PDF from storage (Web only).
  Future<void> clearLastPdfCache();
}
