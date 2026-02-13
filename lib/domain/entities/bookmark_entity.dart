import 'dart:math';

class BookmarkEntity {
  final String id;
  final String fileId; // Can be file path or unique identifier
  final int pageIndex;
  final String title;
  final DateTime createdAt;

  const BookmarkEntity({
    required this.id,
    required this.fileId,
    required this.pageIndex,
    required this.title,
    required this.createdAt,
  });

  factory BookmarkEntity.create({
    required String fileId,
    required int pageIndex,
    String? title,
  }) {
    // Generate simple unique ID without external dependency
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return BookmarkEntity(
      id: '$timestamp-$random',
      fileId: fileId,
      pageIndex: pageIndex,
      title: title ?? 'Page ${pageIndex + 1}',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileId': fileId,
      'pageIndex': pageIndex,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BookmarkEntity.fromMap(Map<dynamic, dynamic> map) {
    return BookmarkEntity(
      id: map['id'] as String,
      fileId: map['fileId'] as String,
      pageIndex: map['pageIndex'] as int,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
