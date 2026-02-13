import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:monkread/domain/entities/bookmark_entity.dart';

class BookmarkNotifier extends StateNotifier<List<BookmarkEntity>> {
  final String filePath;
  late final Box _box;

  BookmarkNotifier(this.filePath) : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox('bookmarks');
    _loadBookmarks();
  }

  void _loadBookmarks() {
    final allBookmarks = _box.values.map((e) {
        // Handle potential dynamic map issues
        if (e is Map) {
          return BookmarkEntity.fromMap(Map<String, dynamic>.from(e));
        }
        return null;
      })
      .whereType<BookmarkEntity>()
      .where((b) => b.fileId == filePath)
      .toList();
    
    // Sort by page index
    allBookmarks.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    state = allBookmarks;
  }

  Future<void> addBookmark(int pageIndex, {String? title}) async {
    final existing = state.any((b) => b.pageIndex == pageIndex);
    if (existing) return; // Don't duplicate

    final newBookmark = BookmarkEntity.create(
      fileId: filePath,
      pageIndex: pageIndex,
      title: title,
    );

    // Save to Hive
    await _box.put(newBookmark.id, newBookmark.toMap());
    
    // Update state
    state = [...state, newBookmark]..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
  }

  Future<void> removeBookmark(String id) async {
    await _box.delete(id);
    state = state.where((b) => b.id != id).toList();
  }

  Future<void> toggleBookmark(int pageIndex) async {
    // Check if bookmark exists for this page
    try {
      final existing = state.firstWhere((b) => b.pageIndex == pageIndex);
      await removeBookmark(existing.id);
    } catch (_) {
      // Not found, add it
      await addBookmark(pageIndex);
    }
  }

  bool isBookmarked(int pageIndex) {
    return state.any((b) => b.pageIndex == pageIndex);
  }
}

// Provider family to get bookmarks for a specific file
final bookmarkProvider = StateNotifierProvider.family<BookmarkNotifier, List<BookmarkEntity>, String>(
  (ref, filePath) {
    return BookmarkNotifier(filePath);
  }
);
