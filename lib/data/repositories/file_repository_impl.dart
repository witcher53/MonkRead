import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:monkread/core/constants/app_constants.dart';
import 'package:monkread/domain/entities/pdf_document.dart';
import 'package:monkread/domain/repositories/file_repository.dart';
import 'package:universal_io/io.dart' as io;

/// Concrete implementation of [FileRepository].
///
/// Uses [FilePicker] for native file selection.
/// On Web, persists the selected file's bytes to IndexedDB via Hive.
class FileRepositoryImpl implements FileRepository {
  static const String _boxName = 'pdf_cache';
  static const String _keyBytes = 'last_pdf_bytes';
  static const String _keyName = 'last_pdf_name';

  @override
  Future<bool> requestStoragePermission() async {
    // Web doesn't require storage permissions for picking files.
    if (kIsWeb) return true;

    // Desktop platforms (Windows, macOS, Linux) don't use Android/iOS-style
    // runtime permissions. The native file picker handles access itself.
    if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
      return true;
    }

    // On mobile, file_picker handles its own permission requests internally
    // when opening the file dialog. Return true and let pickPdfFile() handle
    // any permission errors.
    return true;
  }

  @override
  Future<PdfDocument?> pickPdfFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedExtensions,
      allowMultiple: false,
      withData: kIsWeb, // Important: load bytes on Web
    );

    if (result == null || result.files.isEmpty) {
      // User cancelled the picker
      return null;
    }

    final file = result.files.first;

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes != null) {
        // Persist to Hive
        final box = await Hive.openBox(_boxName);
        await box.put(_keyBytes, bytes);
        await box.put(_keyName, file.name);

        return PdfDocument(
          filePath: 'memory://${file.name}', // Fake path for Web
          fileName: file.name,
          bytes: bytes,
        );
      }
      return null;
    }

    if (file.path == null) {
      // Edge case: picker returned a file without a path
      return null;
    }

    return PdfDocument(
      filePath: file.path!,
      fileName: file.name,
    );
  }

  /// Retrieves the last opened PDF from Hive (Web only).
  /// This method can be called on app startup.
  Future<PdfDocument?> getLastOpenedPdf() async {
    if (!kIsWeb) return null;

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    final box = Hive.box(_boxName);
    final bytes = box.get(_keyBytes) as Uint8List?;
    final name = box.get(_keyName) as String?;

    if (bytes != null && name != null) {
       return PdfDocument(
          filePath: 'memory://$name',
          fileName: name,
          bytes: bytes,
       );
    }
    return null;
  }

  @override
  Future<void> clearLastPdfCache() async {
    if (!kIsWeb) return;
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    final box = Hive.box(_boxName);
    await box.delete(_keyBytes);
    await box.delete(_keyName);
  }
}
