import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/data/repositories/book_repository_impl.dart';
import 'package:monkread/domain/entities/book_entity.dart';
import 'package:monkread/domain/repositories/book_repository.dart';
import 'package:monkread/domain/repositories/file_repository.dart';
import 'package:monkread/presentation/providers/file_provider.dart';

// ── Repository provider ──────────────────────────────────────────

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepositoryImpl();
});

// ── Library state ────────────────────────────────────────────────

/// Manages the user's book library backed by Hive.
class LibraryNotifier extends StateNotifier<AsyncValue<List<BookEntity>>> {
  final BookRepository _bookRepository;
  final FileRepository _fileRepository;

  LibraryNotifier(this._bookRepository, this._fileRepository)
      : super(const AsyncValue.loading()) {
    loadBooks();
  }

  /// Loads all books from the database.
  Future<void> loadBooks() async {
    try {
      final books = await _bookRepository.getBooks();
      state = AsyncValue.data(books);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Adds or updates a book in the library (called when a PDF is opened).
  Future<void> addBook(BookEntity book) async {
    await _bookRepository.saveBook(book);
    await loadBooks(); // Refresh the list
  }

  /// Updates the last opened page for a book.
  Future<void> updateLastPage(String filePath, int page) async {
    final books = state.valueOrNull ?? [];
    final existing = books.where((b) => b.filePath == filePath).firstOrNull;
    if (existing != null) {
      final updated = existing.copyWith(
        lastPage: page,
        lastOpened: DateTime.now(),
      );
      await _bookRepository.saveBook(updated);
      // Update in-memory state without full reload
      state = AsyncValue.data(
        books.map((b) => b.filePath == filePath ? updated : b).toList(),
      );
    }
  }

  /// Removes a book from the library.
  Future<void> removeBook(String filePath) async {
    await _bookRepository.removeBook(filePath);
    // Also clear the web cache (bytes) to free memory
    await _fileRepository.clearLastPdfCache();
    await loadBooks();
  }
}

// ── Provider ─────────────────────────────────────────────────────

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, AsyncValue<List<BookEntity>>>((ref) {
  final bookRepository = ref.watch(bookRepositoryProvider);
  final fileRepository = ref.watch(fileRepositoryProvider);
  return LibraryNotifier(bookRepository, fileRepository);
});
