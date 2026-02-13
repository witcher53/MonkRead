import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/presentation/providers/search_provider.dart';
import 'package:pdfrx/pdfrx.dart';

/// Slide-in sidebar for full-text PDF search.
class SearchSidebar extends ConsumerStatefulWidget {
  final String filePath;
  final PdfViewerController pdfController;
  final VoidCallback onClose;

  const SearchSidebar({
    super.key,
    required this.filePath,
    required this.pdfController,
    required this.onClose,
  });

  @override
  ConsumerState<SearchSidebar> createState() => _SearchSidebarState();
}

class _SearchSidebarState extends ConsumerState<SearchSidebar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    ref.read(searchProvider.notifier).search(widget.filePath, query);
  }

  void _goToResult(SearchResult result) {
    widget.pdfController.goToPage(pageNumber: result.pageIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final theme = Theme.of(context);

    // When currentResult changes, jump to that page
    ref.listen<SearchState>(searchProvider, (prev, next) {
      final result = next.currentResult;
      if (result != null &&
          (prev?.currentIndex != next.currentIndex ||
              prev?.results != next.results)) {
        _goToResult(result);
      }
    });

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(searchState, theme),
          const Divider(height: 1),
          _buildSearchBar(searchState, theme),
          const Divider(height: 1),
          Expanded(child: _buildResultsList(searchState, theme)),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────

  Widget _buildHeader(SearchState searchState, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search in Document',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (searchState.results.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${searchState.currentIndex + 1}/${searchState.results.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              ref.read(searchProvider.notifier).clear();
              widget.onClose();
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────

  Widget _buildSearchBar(SearchState searchState, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search text…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchProvider.notifier).clear();
                            },
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: theme.textTheme.bodySmall,
                  onSubmitted: (_) => _performSearch(),
                  onChanged: (_) => setState(() {}), // update suffix icon
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: searchState.isSearching ? null : _performSearch,
                icon: searchState.isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Case sensitivity toggle
              GestureDetector(
                onTap: () {
                  ref.read(searchProvider.notifier).toggleCaseSensitivity();
                  if (_searchController.text.trim().isNotEmpty) {
                    _performSearch();
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: searchState.caseSensitive
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: searchState.caseSensitive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.text_format_rounded,
                        size: 14,
                        color: searchState.caseSensitive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withAlpha(153),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Aa',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: searchState.caseSensitive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Navigation arrows
              if (searchState.results.isNotEmpty) ...[
                IconButton(
                  onPressed: () =>
                      ref.read(searchProvider.notifier).previousResult(),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Previous result',
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(searchProvider.notifier).nextResult(),
                  icon:
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Next result',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Results List ───────────────────────────────────────────────

  Widget _buildResultsList(SearchState searchState, ThemeData theme) {
    if (searchState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.query.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Enter a search term to find\ntext within this document.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(127),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 40, color: theme.colorScheme.onSurface.withAlpha(100)),
              const SizedBox(height: 12),
              Text(
                'No results found for\n"${searchState.query}"',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: searchState.results.length,
      itemBuilder: (context, index) {
        final result = searchState.results[index];
        final isCurrent = index == searchState.currentIndex;

        return InkWell(
          onTap: () {
            // Set currentIndex and jump to page
            ref.read(searchProvider.notifier)
              ..previousResult() // dummy to sync
              ..nextResult(); // will cycle — use direct approach
            // Actually just set the result directly via goToPage
            _goToResult(result);
            // Update currentIndex by calculating steps
            final notifier = ref.read(searchProvider.notifier);
            // Navigate to the specific result index
            while (ref.read(searchProvider).currentIndex != index) {
              notifier.nextResult();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrent
                  ? theme.colorScheme.primaryContainer.withAlpha(127)
                  : null,
              border: Border(
                bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(80)),
              ),
            ),
            child: Row(
              children: [
                // Page badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'P${result.pageIndex + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isCurrent
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.contextText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withAlpha(204),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
