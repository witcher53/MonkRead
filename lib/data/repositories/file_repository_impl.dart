import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:monkread/core/constants/app_constants.dart';
import 'package:monkread/domain/entities/pdf_document.dart';
import 'package:monkread/domain/repositories/file_repository.dart';

/// Concrete implementation of [FileRepository].
///
/// Uses [FilePicker] for native file selection.
/// On desktop platforms, storage permissions are not required — the OS
/// file picker dialog runs in the user's security context.
class FileRepositoryImpl implements FileRepository {
  @override
  Future<bool> requestStoragePermission() async {
    // Web doesn't require storage permissions for picking files.
    if (kIsWeb) return true;

    // Desktop platforms (Windows, macOS, Linux) don't use Android/iOS-style
    // runtime permissions. The native file picker handles access itself.
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
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
    );

    if (result == null || result.files.isEmpty) {
      // User cancelled the picker
      return null;
    }

    final file = result.files.first;

    if (file.path == null) {
      // Edge case: picker returned a file without a path
      return null;
    }

    return PdfDocument(
      filePath: file.path!,
      fileName: file.name,
    );
  }
}
