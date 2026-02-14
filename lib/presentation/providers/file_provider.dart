import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/core/errors/failures.dart';
import 'package:monkread/data/repositories/file_repository_impl.dart';
import 'package:monkread/domain/entities/pdf_document.dart';
import 'package:monkread/domain/repositories/file_repository.dart';

// ── Repository provider ──────────────────────────────────────────
/// Provides the concrete [FileRepository] implementation.
final fileRepositoryProvider = Provider<FileRepository>((ref) {
  return FileRepositoryImpl();
});

// ── State for the PDF picking flow ───────────────────────────────

/// Represents the current state of the PDF picking operation.
sealed class PdfPickState {
  const PdfPickState();
}

class PdfPickInitial extends PdfPickState {
  const PdfPickInitial();
}

class PdfPickLoading extends PdfPickState {
  const PdfPickLoading();
}

class PdfPickSuccess extends PdfPickState {
  final PdfDocument document;
  const PdfPickSuccess(this.document);
}

class PdfPickError extends PdfPickState {
  final Failure failure;
  const PdfPickError(this.failure);
}

// ── Notifier ─────────────────────────────────────────────────────

/// Manages the PDF file picking workflow:
/// 1. Request permission
/// 2. Open file picker
/// 3. Return result
class PdfPickNotifier extends StateNotifier<PdfPickState> {
  final FileRepository _repository;

  PdfPickNotifier(this._repository) : super(const PdfPickInitial());

  /// Kicks off the permission → pick → navigate flow.
  Future<void> pickPdf() async {
    state = const PdfPickLoading();

    try {
      // Step 1: Open the native file picker immediately
      // (Permissions are handled by the plugin/OS, and we must not await anything
      // before this call to preserve the user activation gesture on Web)

      // Step 2: Open the native file picker
      final document = await _repository.pickPdfFile();

      if (document == null) {
        // User cancelled — reset to initial
        state = const PdfPickInitial();
        return;
      }

      // Step 3: File selected successfully
      state = PdfPickSuccess(document);
    } catch (_) {
      state = const PdfPickError(FilePickerFailure());
    }
  }

  /// Resets the state back to initial (e.g. after navigating to reader).
  void reset() {
    state = const PdfPickInitial();
  }
}

// ── Provider ─────────────────────────────────────────────────────

final pdfPickProvider =
    StateNotifierProvider<PdfPickNotifier, PdfPickState>((ref) {
  final repository = ref.watch(fileRepositoryProvider);
  return PdfPickNotifier(repository);
});
