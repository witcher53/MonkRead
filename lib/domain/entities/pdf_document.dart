/// Represents a PDF document entity in the domain layer.
///
/// This is a pure data class with no dependency on frameworks or packages.
class PdfDocument {
  /// Absolute file path to the PDF on disk.
  final String filePath;

  /// Human-readable file name (e.g. "report.pdf").
  final String fileName;

  /// Total number of pages in the document (set after loading).
  final int? pageCount;

  /// The page the user was last reading (0-indexed). Used for resume.
  final int lastPage;

  const PdfDocument({
    required this.filePath,
    required this.fileName,
    this.pageCount,
    this.lastPage = 0,
  });

  /// Returns a copy with the given fields replaced.
  PdfDocument copyWith({
    String? filePath,
    String? fileName,
    int? pageCount,
    int? lastPage,
  }) {
    return PdfDocument(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      pageCount: pageCount ?? this.pageCount,
      lastPage: lastPage ?? this.lastPage,
    );
  }

  @override
  String toString() => 'PdfDocument(fileName: $fileName, pages: $pageCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfDocument &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath;

  @override
  int get hashCode => filePath.hashCode;
}
