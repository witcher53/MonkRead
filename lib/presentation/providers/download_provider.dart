import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart'; // Just for platform check if needed, or path manipulation
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/domain/entities/book_entity.dart';
import 'package:monkread/presentation/providers/library_provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ── State ────────────────────────────────────────────────────────

class DownloadState {
  final bool isDownloading;
  final double progress; // 0.0 to 1.0
  final String? error;
  final String? successMessage;

  const DownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.error,
    this.successMessage,
  });

  DownloadState copyWith({
    bool? isDownloading,
    double? progress,
    String? error, // Nullable override
    String? successMessage,
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      error: error, // If passed, it overrides. If not passed, use existing? No, usually we want to clear error.
                    // Let's say if argument is provided (even null), we use it. 
                    // But optional named args are null if omitted.
                    // So we need a way to clear error.
                    // Let's assume if error is passed, we use it. If not, we keep it? 
                    // Actually, usually in copyWith we clear error if we start loading.
      successMessage: successMessage,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────

class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref _ref;
  final Dio _dio = Dio();

  DownloadNotifier(this._ref) : super(const DownloadState());

  Future<void> downloadFile(String url, {String? customFileName}) async {
    if (state.isDownloading) return;

    state = const DownloadState(isDownloading: true, progress: 0.0);

    try {
      final dir = await getApplicationDocumentsDirectory();
      
      // Determine filename
      String fileName = customFileName ?? _getFileNameFromUrl(url);
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }
      
      final savePath = p.join(dir.path, fileName);
      
      // Check if file exists, maybe append counter?
      // For now, overwrite or simple check.
      // Let's overwrite for simplicity, or fail?
      // Overwrite is fine.

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            state = DownloadState(
              isDownloading: true,
              progress: received / total,
            );
          }
        },
      );

      // Download complete
      state = const DownloadState(
        isDownloading: false,
        progress: 1.0,
        successMessage: 'Download complete!',
      );

      // Add to library
      final book = BookEntity(
        filePath: savePath,
        fileName: fileName,
        lastOpened: DateTime.now(),
        lastPage: 0,
      );

      await _ref.read(libraryProvider.notifier).addBook(book);

    } catch (e) {
      state = DownloadState(
        isDownloading: false,
        error: 'Download failed: ${e.toString()}',
      );
    }
  }
  
  void clearMessage() {
    state = const DownloadState();
  }

  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
    } catch (_) {}
    return 'downloaded_document.pdf';
  }
}

// ── Provider ─────────────────────────────────────────────────────

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref);
});
