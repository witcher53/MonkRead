/// Represents a book (PDF file) in the user's library.
class BookEntity {
  /// Absolute file path — acts as the unique key.
  final String filePath;

  /// Display name (e.g. "report.pdf").
  final String fileName;

  /// When the user last opened this book.
  final DateTime lastOpened;

  /// The page the user was last reading (0-indexed).
  final int lastPage;

  const BookEntity({
    required this.filePath,
    required this.fileName,
    required this.lastOpened,
    this.lastPage = 0,
  });

  BookEntity copyWith({
    String? filePath,
    String? fileName,
    DateTime? lastOpened,
    int? lastPage,
  }) {
    return BookEntity(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      lastOpened: lastOpened ?? this.lastOpened,
      lastPage: lastPage ?? this.lastPage,
    );
  }

  /// Serializes to a JSON-compatible map for Hive storage.
  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'lastOpened': lastOpened.toIso8601String(),
      'lastPage': lastPage,
    };
  }

  /// Deserializes from a Hive-stored map.
  factory BookEntity.fromMap(Map<dynamic, dynamic> map) {
    return BookEntity(
      filePath: map['filePath'] as String,
      fileName: map['fileName'] as String,
      lastOpened: DateTime.parse(map['lastOpened'] as String),
      lastPage: (map['lastPage'] as int?) ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookEntity &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath;

  @override
  int get hashCode => filePath.hashCode;

  @override
  String toString() => 'BookEntity(fileName: $fileName)';
}
