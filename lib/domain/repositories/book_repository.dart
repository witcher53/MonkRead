import 'package:monkread/domain/entities/book_entity.dart';

/// Abstract contract for book library operations.
abstract class BookRepository {
  /// Returns all saved books, sorted by last opened (most recent first).
  Future<List<BookEntity>> getBooks();

  /// Saves or updates a book in the library.
  Future<void> saveBook(BookEntity book);

  /// Removes a book from the library by file path.
  Future<void> removeBook(String filePath);
}
