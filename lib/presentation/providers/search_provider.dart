import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

// ── Search Result ────────────────────────────────────────────────

/// A single search match in the PDF.
class SearchResult {
  /// Zero-based page index.
  final int pageIndex;

  /// Bounding rectangles of the matched text, normalized (0–1).
  final List<Rect> bounds;

  /// Context text around the match.
  final String contextText;

  const SearchResult({
    required this.pageIndex,
    required this.bounds,
    required this.contextText,
  });
}

// ── Search State ─────────────────────────────────────────────────

class SearchState {
  final String query;
  final List<SearchResult> results;
  final int currentIndex;
  final bool isSearching;
  final bool caseSensitive;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.currentIndex = -1,
    this.isSearching = false,
    this.caseSensitive = false,
  });

  SearchResult? get currentResult =>
      (currentIndex >= 0 && currentIndex < results.length)
          ? results[currentIndex]
          : null;

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    int? currentIndex,
    bool? isSearching,
    bool? caseSensitive,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      currentIndex: currentIndex ?? this.currentIndex,
      isSearching: isSearching ?? this.isSearching,
      caseSensitive: caseSensitive ?? this.caseSensitive,
    );
  }
}

// ── Search Notifier ──────────────────────────────────────────────

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(const SearchState());

  /// Perform a full-text search across all pages of the PDF at [filePath].
  Future<void> search(String filePath, String query) async {
    if (query.trim().isEmpty) {
      clear();
      return;
    }

    state = state.copyWith(
      query: query,
      isSearching: true,
      results: [],
      currentIndex: -1,
    );

    try {
      final doc = await PdfDocument.openFile(filePath);
      final results = <SearchResult>[];

      for (int i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        final pageText = await page.loadText();
        if (pageText == null) continue;

        final fullText = pageText.fullText;
        if (fullText.isEmpty) continue;

        final searchQuery =
            state.caseSensitive ? query : query.toLowerCase();
        final searchText =
            state.caseSensitive ? fullText : fullText.toLowerCase();

        int startIndex = 0;
        while (true) {
          final matchIndex = searchText.indexOf(searchQuery, startIndex);
          if (matchIndex == -1) break;

          // Extract context (up to 60 chars around the match)
          final contextStart = (matchIndex - 30).clamp(0, fullText.length);
          final contextEnd =
              (matchIndex + query.length + 30).clamp(0, fullText.length);
          final context = (contextStart > 0 ? '…' : '') +
              fullText.substring(contextStart, contextEnd) +
              (contextEnd < fullText.length ? '…' : '');

          // Get bounding rects for the matched text range
          // Get bounding rects for the matched text range
          final rects = <Rect>[];
          for (int ci = matchIndex;
              ci < matchIndex + query.length && ci < pageText.charRects.length;
              ci++) {
            final charRect = pageText.charRects[ci];
            // Normalize bounds relative to page dimensions (PDF uses bottom-left origin)
            final rect = Rect.fromLTRB(
              charRect.left / page.width,
              1.0 - (charRect.top / page.height),
              charRect.right / page.width,
              1.0 - (charRect.bottom / page.height),
            );
            rects.add(rect);
          }

          if (rects.isNotEmpty) {
            results.add(SearchResult(
              pageIndex: i,
              bounds: rects,
              contextText: context,
            ));
          }

          startIndex = matchIndex + 1;
        }
      }

      state = state.copyWith(
        results: results,
        currentIndex: results.isNotEmpty ? 0 : -1,
        isSearching: false,
      );
    } catch (e) {
      debugPrint('Search error: $e');
      state = state.copyWith(isSearching: false);
    }
  }

  void nextResult() {
    if (state.results.isEmpty) return;
    final nextIndex = (state.currentIndex + 1) % state.results.length;
    state = state.copyWith(currentIndex: nextIndex);
  }

  void previousResult() {
    if (state.results.isEmpty) return;
    final prevIndex = (state.currentIndex - 1 + state.results.length) %
        state.results.length;
    state = state.copyWith(currentIndex: prevIndex);
  }

  void toggleCaseSensitivity() {
    state = state.copyWith(caseSensitive: !state.caseSensitive);
  }

  void clear() {
    state = const SearchState();
  }
}

// ── Provider ─────────────────────────────────────────────────────

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});
