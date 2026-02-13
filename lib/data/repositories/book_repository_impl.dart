import 'package:hive/hive.dart';
import 'package:monkread/domain/entities/book_entity.dart';
import 'package:monkread/domain/repositories/book_repository.dart';

/// Hive-backed implementation of [BookRepository].
///
/// Stores books as JSON maps in a Hive box named 'books'.
/// Uses the file path as the key.
class BookRepositoryImpl implements BookRepository {
  static const String _boxName = 'books';

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  @override
  Future<List<BookEntity>> getBooks() async {
    final box = await _openBox();
    final books = <BookEntity>[];

    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw is Map) {
          books.add(BookEntity.fromMap(raw));
        }
      } catch (_) {
        // Skip corrupted entries
      }
    }

    // Sort by last opened, most recent first
    books.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    return books;
  }

  @override
  Future<void> saveBook(BookEntity book) async {
    final box = await _openBox();
    await box.put(book.filePath, book.toMap());
  }

  @override
  Future<void> removeBook(String filePath) async {
    final box = await _openBox();
    await box.delete(filePath);
  }
}
