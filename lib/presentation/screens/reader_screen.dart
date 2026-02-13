import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:monkread/data/services/pdf_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:monkread/domain/entities/pdf_document.dart' as entity;
import 'package:monkread/domain/entities/drawing_state.dart';
import 'package:monkread/presentation/providers/drawing_provider.dart';
import 'package:monkread/presentation/providers/library_provider.dart';
import 'package:monkread/presentation/providers/sidecar_provider.dart';
import 'package:monkread/presentation/providers/split_view_provider.dart';
import 'package:monkread/presentation/providers/toolbar_visibility_provider.dart';
import 'package:monkread/presentation/providers/search_provider.dart';
import 'package:monkread/presentation/widgets/ai_sidebar.dart';
import 'package:monkread/presentation/widgets/drawing_canvas.dart';
import 'package:monkread/presentation/widgets/drawing_toolbar.dart';
import 'package:monkread/presentation/widgets/search_sidebar.dart';
import 'package:monkread/presentation/widgets/search_highlight_painter.dart';
import 'package:monkread/presentation/widgets/sidecar_canvas.dart';
import 'package:monkread/presentation/widgets/split_handle.dart';
import 'package:monkread/presentation/widgets/text_input_dialog.dart';
import 'package:monkread/presentation/widgets/navigation_sidebar.dart';
import 'package:monkread/presentation/providers/bookmark_provider.dart';
import 'package:printing/printing.dart';
import 'dart:io';

/// Renders a PDF with per-page drawing/text overlays, optional dual PDF
/// view, and sidecar infinite whiteboard.
class ReaderScreen extends ConsumerStatefulWidget {
  final entity.PdfDocument document;

  const ReaderScreen({super.key, required this.document});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  bool _showAiSidebar = false;
  bool _showSearchSidebar = false;
  bool _showNavigationSidebar = false;
  Timer? _debounceTimer;
  final PdfViewerController _pdfController = PdfViewerController();

  // Ghost divider state — for lag-free split-view resizing
  bool _isDraggingSplit = false;
  double _ghostDividerX = 0.0; // absolute pixel position

  // Secondary PDF (dual view)
  final PdfViewerController _secondaryPdfController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    debugPrint('DEBUG: Opening "${widget.document.fileName}" at lastPage=${widget.document.lastPage}, initialPageNumber=${widget.document.lastPage + 1}');
    _currentPage = widget.document.lastPage; // Initialize with saved page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(drawingProvider.notifier).loadForFile(widget.document.filePath);
      ref
          .read(sidecarProvider.notifier)
          .loadForFile(widget.document.filePath);
    });
  }

  /// Safely retrieves the document or returns null if controller is detached.
  PdfDocument? get _safeDocument {
    try {
      // This getter throws if controller._state is null in pdfrx
      return _pdfController.document;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawingState = ref.watch(drawingProvider);
    final mode = drawingState.annotationMode;
    final completedStrokes = drawingState.strokesForPage(_currentPage);
    final isAnnotating = drawingState.isAnnotating;
    final splitState = ref.watch(splitViewProvider);
    final isSplit = splitState.mode != SplitViewMode.none;
    final toolbarVisible = ref.watch(toolbarVisibilityProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(drawingProvider.notifier).clearState();
          ref.read(sidecarProvider.notifier).clearState();
          ref.read(splitViewProvider.notifier).closeSplitView();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.document.fileName,
            overflow: TextOverflow.ellipsis,
          ),
          leadingWidth: 100,
          leading: Row(
            children: [
              const BackButton(),
              IconButton(
                icon: const Icon(Icons.grid_view_rounded),
                onPressed: () => setState(() => _showNavigationSidebar = !_showNavigationSidebar),
                tooltip: 'Navigation',
              ),
            ],
          ),
          actions: [
            // Bookmark toggle
            Consumer(
              builder: (context, ref, child) {
                final bookmarks = ref.watch(bookmarkProvider(widget.document.filePath));
                final isBookmarked = bookmarks.any((b) => b.pageIndex == _currentPage);
                return IconButton(
                  icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                  color: isBookmarked ? Colors.amber : null,
                  onPressed: () {
                    ref.read(bookmarkProvider(widget.document.filePath).notifier).toggleBookmark(_currentPage);
                  },
                  tooltip: 'Toggle Bookmark',
                );
              },
            ),
            // Print
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printPdf,
              tooltip: 'Print',
            ),

            // ── Mode indicator ───────────────────────
            if (isAnnotating)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _indicatorColor(mode).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _indicatorIcon(mode),
                          size: 14,
                          color: _indicatorColor(mode),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _indicatorLabel(mode),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _indicatorColor(mode),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Page counter ─────────────────────────
            if (_isReady)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentPage + 1} / $_totalPages',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ),
              ),
            // ── Search button ─────────────────────────────
            IconButton(
              icon: Icon(
                Icons.search_rounded,
                color: _showSearchSidebar
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: 'Search in Document',
              onPressed: () {
                setState(() {
                  _showSearchSidebar = !_showSearchSidebar;
                  if (!_showSearchSidebar) {
                    ref.read(searchProvider.notifier).clear();
                  }
                });
              },
            ),
            // ── AI button ─────────────────────────────
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                color: _showAiSidebar
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: 'AI Assistant',
              onPressed: () =>
                  setState(() => _showAiSidebar = !_showAiSidebar),
            ),
            // ── Export button ─────────────────────────────
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Export Annotated PDF',
              onPressed: () => _exportAnnotatedPdf(context),
            ),
          ],
        ),
        body: Stack(
          children: [
            // ── Main content (single or split) ──────────
            if (isSplit)
              _buildSplitLayout(splitState, mode, isAnnotating)
            else
              _buildPrimaryPdf(mode, isAnnotating),

            // ── Loading overlay ──────────────────────────
            if (!_isReady)
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading PDF…',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Toolbar ──────────────────────────────────
            DrawingToolbar(
              annotationMode: mode,
              canUndo: completedStrokes.isNotEmpty,
              selectedColor: drawingState.selectedColor,
              selectedStrokeWidth: drawingState.selectedStrokeWidth,
              pdfController: _pdfController,
              splitViewMode: splitState.mode,
              isVisible: toolbarVisible,
              onToggleVisibility: () =>
                  ref.read(toolbarVisibilityProvider.notifier).toggle(),
              onTogglePen: () =>
                  ref.read(drawingProvider.notifier).togglePenMode(),
              onToggleText: () =>
                  ref.read(drawingProvider.notifier).toggleTextMode(),
              onToggleLasso: () =>
                  ref.read(drawingProvider.notifier).toggleLassoMode(),
              onHandMode: () => ref
                  .read(drawingProvider.notifier)
                  .setAnnotationMode(AnnotationMode.none),
              onUndo: () => ref
                  .read(drawingProvider.notifier)
                  .undoLastStroke(_currentPage),
              onColorChanged: (color) =>
                  ref.read(drawingProvider.notifier).setColor(color),
              onStrokeWidthChanged: (width) =>
                  ref.read(drawingProvider.notifier).setStrokeWidth(width),
              onToggleDualPdf: _handleToggleDualPdf,
              onToggleSidecar: () =>
                  ref.read(splitViewProvider.notifier).toggleSidecar(),
              onDeleteSelection: (drawingState.lassoSelection?.isEmpty ?? true)
                  ? null
                  : () => ref
                      .read(drawingProvider.notifier)
                      .deleteSelection(),
              onClearPage: () =>
                  ref.read(drawingProvider.notifier).clearCurrentPage(),
            ),

            // ── Show Toolbar FAB (when hidden) ──────────
            if (!toolbarVisible)
              Positioned(
                right: 12,
                bottom: 24,
                child: FloatingActionButton.small(
                  heroTag: 'show_toolbar_fab',
                  onPressed: () =>
                      ref.read(toolbarVisibilityProvider.notifier).show(),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.chevron_left_rounded),
                ),
              ),

            // ── Sidebars (Only show when ready AND document is available) ────────────────
            if (_isReady && _safeDocument != null) ...[
              
              // Helper for mobile scrim
              if (MediaQuery.of(context).size.width < 600) ...[
                // Mobile: Scrim + Overlay
                if (_showNavigationSidebar)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _showNavigationSidebar = false),
                          child: Container(color: Colors.black54),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.85,
                            child: NavigationSidebar(
                              controller: _pdfController,
                              document: _safeDocument!,
                              filePath: widget.document.filePath,
                              onClose: () => setState(() => _showNavigationSidebar = false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_showAiSidebar)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _showAiSidebar = false),
                          child: Container(color: Colors.black54),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.85,
                            child: AiSidebar(
                              onExtractPageText: _extractCurrentPageText,
                              onClose: () => setState(() => _showAiSidebar = false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_showSearchSidebar)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                             setState(() => _showSearchSidebar = false);
                             ref.read(searchProvider.notifier).clear();
                          },
                          child: Container(color: Colors.black54),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.85,
                            child: SearchSidebar(
                              filePath: widget.document.filePath,
                              pdfController: _pdfController,
                              onClose: () {
                                setState(() => _showSearchSidebar = false);
                                ref.read(searchProvider.notifier).clear();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                // Desktop: Standard Sidebars (Push content or overlay)
                if (_showAiSidebar)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: AiSidebar(
                      onExtractPageText: _extractCurrentPageText,
                      onClose: () => setState(() => _showAiSidebar = false),
                    ),
                  ),

                if (_showNavigationSidebar)
                  Positioned(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    child: NavigationSidebar(
                      controller: _pdfController,
                      document: _safeDocument!,
                      filePath: widget.document.filePath,
                      onClose: () => setState(() => _showNavigationSidebar = false),
                    ),
                  ),

                if (_showSearchSidebar)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: SearchSidebar(
                      filePath: widget.document.filePath,
                      pdfController: _pdfController,
                      onClose: () {
                        setState(() => _showSearchSidebar = false);
                        ref.read(searchProvider.notifier).clear();
                      },
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Extracts text from the current PDF page using pdfrx.
  Future<String> _extractCurrentPageText() async {
    try {
      final doc = await PdfDocument.openFile(widget.document.filePath);
      if (_currentPage < doc.pages.length) {
        final page = doc.pages[_currentPage];
        final pageText = await page.loadText();
        final text = pageText?.fullText ?? '';
        return text.isNotEmpty
            ? text
            : 'Could not extract text from this page. The page may be scanned/image-based.';
      }
    } catch (e) {
      debugPrint('Text extraction error: $e');
    }
    return 'Could not extract text from this page. The page may be scanned/image-based.';
  }

  Future<void> _printPdf() async {
    try {
      final file = File(widget.document.filePath);
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: widget.document.fileName,
      );
    } catch (e) {
      debugPrint('Print error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print: $e')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Layout builders
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPrimaryPdf(AnnotationMode mode, bool isAnnotating) {
    return PdfViewer.file(
      widget.document.filePath,
      controller: _pdfController,
      initialPageNumber: widget.document.lastPage + 1,
      params: PdfViewerParams(
        maxScale: 8.0,
        scrollByMouseWheel: 1.5,
        scaleEnabled: !isAnnotating,
        panEnabled: !isAnnotating,
        onPageChanged: (pageNumber) {
          final page = (pageNumber ?? 1) - 1;
          setState(() => _currentPage = page);

          // Debounce the database update
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) {
              ref.read(libraryProvider.notifier).updateLastPage(
                    widget.document.filePath,
                    page,
                  );
            }
          });
        },
        onViewerReady: (document, controller) {
          setState(() {
            _totalPages = document.pages.length;
            _isReady = true;
          });
        },
        pageOverlaysBuilder: (context, pageRect, page) =>
            _buildPageOverlays(mode, page),
      ),
    );
  }

  List<Widget> _buildPageOverlays(AnnotationMode mode, PdfPage page) {
    final pageIndex = page.pageNumber - 1;
    final drawingState = ref.watch(drawingProvider);
    final pageStrokes = drawingState.strokesForPage(pageIndex);
    final activeStroke =
        (drawingState.activePageIndex == pageIndex)
            ? drawingState.activeStroke
            : null;
    final lassoSelection =
        (drawingState.activePageIndex == pageIndex)
            ? drawingState.lassoSelection
            : null;
    final textAnnotations =
        drawingState.textAnnotationsForPage(pageIndex);

    // Search highlights for this page
    final searchState = ref.watch(searchProvider);
    final searchMatches = searchState.results
        .where((r) => r.pageIndex == pageIndex)
        .toList();

    return [
      // Search highlight layer (below drawing canvas)
      if (searchMatches.isNotEmpty)
        for (final match in searchMatches)
          Positioned.fill(
            child: CustomPaint(
              painter: SearchHighlightPainter(
                matchBounds: match.bounds,
                isCurrentMatch: searchState.currentResult == match,
              ),
            ),
          ),
      // Drawing canvas layer
      Positioned.fill(
        child: DrawingCanvas(
          annotationMode: mode,
          currentPage: pageIndex,
          completedStrokes: pageStrokes,
          activeStroke: activeStroke,
          lassoSelection: lassoSelection,
          textAnnotations: textAnnotations,
          pageWidthPt: page.width,
          onPanStart: (pos) {
            ref.read(drawingProvider.notifier).handlePanStart(pageIndex, pos);
          },
          onPanUpdate: (pos) {
            ref.read(drawingProvider.notifier).handlePanUpdate(pos);
          },
          onPanEnd: () {
            ref.read(drawingProvider.notifier).handlePanEnd();
          },
          onTextTap: (normalizedPos) {
            _showTextInputDialog(pageIndex, normalizedPos);
          },
          onTextRemove: (id) {
            ref
                .read(drawingProvider.notifier)
                .removeTextAnnotation(pageIndex, id);
          },
          onTextDrag: (id, delta) {
            _handleTextDrag(pageIndex, id, delta);
          },
          onTextEdit: (annotation) {
            _editTextAnnotation(pageIndex, annotation);
          },
        ),
      ),
    ];
  }

  Widget _buildSplitLayout(
      SplitViewState splitState, AnnotationMode mode, bool isAnnotating) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const handleWidth = 24.0;
        final usableWidth = totalWidth - handleWidth;

        // Use committed ratio for the actual panels
        final leftWidth = usableWidth * splitState.splitRatio;
        final rightWidth = usableWidth * (1 - splitState.splitRatio);

        return Stack(
          children: [
            // ── Actual panels (only re-layout on commit) ──
            Row(
              children: [
                RepaintBoundary(
                  child: SizedBox(
                    width: leftWidth,
                    child: _buildPrimaryPdf(mode, isAnnotating),
                  ),
                ),
                // Real divider handle (grabs the drag)
                SplitHandle(
                  onDragStart: () {
                    setState(() {
                      _isDraggingSplit = true;
                      _ghostDividerX =
                          leftWidth + handleWidth / 2;
                    });
                  },
                  onDrag: (dx) {
                    setState(() {
                      _ghostDividerX = (_ghostDividerX + dx)
                          .clamp(usableWidth * 0.2, usableWidth * 0.8);
                    });
                  },
                  onDragEnd: () {
                    // Commit the ratio
                    final newRatio =
                        (_ghostDividerX - handleWidth / 2) / usableWidth;
                    ref
                        .read(splitViewProvider.notifier)
                        .setSplitRatio(newRatio);
                    setState(() => _isDraggingSplit = false);
                  },
                ),
                RepaintBoundary(
                  child: SizedBox(
                    width: rightWidth,
                    child: splitState.mode == SplitViewMode.dualPdf
                        ? _buildSecondaryPdf(splitState)
                        : _buildSidecarPanel(mode),
                  ),
                ),
              ],
            ),

            // ── Ghost divider overlay (visible only while dragging) ──
            if (_isDraggingSplit)
              Positioned(
                left: _ghostDividerX - 1.5,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 3,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withAlpha(180),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryPdf(SplitViewState splitState) {
    final filePath = splitState.secondaryFilePath;
    if (filePath == null || filePath.isEmpty) {
      return _buildPickSecondaryPrompt();
    }
    return PdfViewer.file(
      filePath,
      controller: _secondaryPdfController,
      params: const PdfViewerParams(
        maxScale: 8.0,
        scrollByMouseWheel: 1.5,
      ),
    );
  }

  Widget _buildPickSecondaryPrompt() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_rounded,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Open a second PDF',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _pickSecondaryFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Browse Files'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidecarPanel(AnnotationMode mode) {
    final sidecarState = ref.watch(sidecarProvider);
    final drawingState = ref.watch(drawingProvider);

    // Sync pen settings
    ref.read(sidecarProvider.notifier).setPenSettings(
          drawingState.selectedColor,
          drawingState.selectedStrokeWidth,
        );

    return SidecarCanvas(
      sidecarState: sidecarState,
      annotationMode: mode,
      selectedColor: drawingState.selectedColor,
      selectedStrokeWidth: drawingState.selectedStrokeWidth,
      onPanStart: (pos) =>
          ref.read(sidecarProvider.notifier).startStroke(pos),
      onPanUpdate: (pos) =>
          ref.read(sidecarProvider.notifier).addPoint(pos),
      onPanEnd: () =>
          ref.read(sidecarProvider.notifier).finishStroke(),
      onUndo: () =>
          ref.read(sidecarProvider.notifier).undoLastStroke(),
      onTextTap: (pos) => _showSidecarTextDialog(pos),
      onTextRemove: (id) =>
          ref.read(sidecarProvider.notifier).removeTextAnnotation(id),
      onTextDrag: (id, delta) => _handleSidecarTextDrag(id, delta),
      onTextEdit: (a) => _editSidecarTextAnnotation(a),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Split view actions
  // ═══════════════════════════════════════════════════════════════

  void _handleToggleDualPdf() {
    // Close sidebars to prevent crash during rebuild/transition
    setState(() {
      _isReady = false; // Force UI to wait for new viewer reuse
      _showNavigationSidebar = false;
      _showSearchSidebar = false;
      _showAiSidebar = false;
    });

    final current = ref.read(splitViewProvider).mode;
    if (current == SplitViewMode.dualPdf) {
      ref.read(splitViewProvider.notifier).closeSplitView();
    } else {
      ref.read(splitViewProvider.notifier).toggleDualPdf();
    }
  }

  Future<void> _pickSecondaryFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      ref
          .read(splitViewProvider.notifier)
          .setSecondaryFile(result.files.single.path!);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PDF Text dialogs (existing)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _showTextInputDialog(
    int pageIndex,
    Offset normalizedPosition,
  ) async {
    final state = ref.read(drawingProvider);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TextInputDialog(
        initialColor: state.selectedColor,
      ),
    );
    if (result == null) return;

    final annotation = TextAnnotation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: result['text'] as String,
      position: normalizedPosition,
      color: result['color'] as Color,
      fontSize: result['fontSize'] as double,
    );
    ref
        .read(drawingProvider.notifier)
        .addTextAnnotation(pageIndex, annotation);
  }

  void _handleTextDrag(int pageIndex, String id, Offset normalizedDelta) {
    final annotations =
        ref.read(drawingProvider).textAnnotationsForPage(pageIndex);
    final annotation = annotations.firstWhere((a) => a.id == id);
    final newPos = Offset(
      (annotation.position.dx + normalizedDelta.dx).clamp(0.0, 1.0),
      (annotation.position.dy + normalizedDelta.dy).clamp(0.0, 1.0),
    );
    ref.read(drawingProvider.notifier).updateTextAnnotation(
          pageIndex,
          annotation.copyWith(position: newPos),
        );
  }

  Future<void> _editTextAnnotation(
    int pageIndex,
    TextAnnotation annotation,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TextInputDialog(
        initialText: annotation.text,
        initialFontSize: annotation.fontSize,
        initialColor: annotation.color,
      ),
    );
    if (result == null) return;

    ref.read(drawingProvider.notifier).updateTextAnnotation(
          pageIndex,
          annotation.copyWith(
            text: result['text'] as String,
            fontSize: result['fontSize'] as double,
            color: result['color'] as Color,
          ),
        );
  }

  // ═══════════════════════════════════════════════════════════════
  // Sidecar text dialogs
  // ═══════════════════════════════════════════════════════════════

  Future<void> _showSidecarTextDialog(Offset position) async {
    final state = ref.read(drawingProvider);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TextInputDialog(initialColor: state.selectedColor),
    );
    if (result == null) return;

    final annotation = TextAnnotation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: result['text'] as String,
      position: position,
      color: result['color'] as Color,
      fontSize: result['fontSize'] as double,
    );
    ref.read(sidecarProvider.notifier).addTextAnnotation(annotation);
  }

  void _handleSidecarTextDrag(String id, Offset delta) {
    final annotations = ref.read(sidecarProvider).textAnnotations;
    final annotation = annotations.firstWhere((a) => a.id == id);
    final newPos = Offset(
      (annotation.position.dx + delta.dx).clamp(0.0, 1.0),
      (annotation.position.dy + delta.dy).clamp(0.0, 1.0),
    );
    ref
        .read(sidecarProvider.notifier)
        .updateTextAnnotation(annotation.copyWith(position: newPos));
  }

  Future<void> _editSidecarTextAnnotation(TextAnnotation annotation) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TextInputDialog(
        initialText: annotation.text,
        initialFontSize: annotation.fontSize,
        initialColor: annotation.color,
      ),
    );
    if (result == null) return;

    ref.read(sidecarProvider.notifier).updateTextAnnotation(
          annotation.copyWith(
            text: result['text'] as String,
            fontSize: result['fontSize'] as double,
            color: result['color'] as Color,
          ),
        );
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  Color _indicatorColor(AnnotationMode mode) {
    return switch (mode) {
      AnnotationMode.pen => const Color(0xFFFF5252),
      AnnotationMode.text => const Color(0xFF448AFF),
      AnnotationMode.lasso => Colors.deepOrangeAccent,
      AnnotationMode.none => Colors.grey,
    };
  }

  IconData _indicatorIcon(AnnotationMode mode) {
    return switch (mode) {
      AnnotationMode.pen => Icons.edit_rounded,
      AnnotationMode.text => Icons.text_fields_rounded,
      AnnotationMode.lasso => Icons.gesture_rounded,
      AnnotationMode.none => Icons.visibility,
    };
  }

  String _indicatorLabel(AnnotationMode mode) {
    return switch (mode) {
      AnnotationMode.pen => 'Drawing',
      AnnotationMode.text => 'Text',
      AnnotationMode.lasso => 'Lasso',
      AnnotationMode.none => '',
    };
  }

  // ── Export ────────────────────────────────────────────────────

  Future<void> _exportAnnotatedPdf(BuildContext ctx) async {
    final drawingState = ref.read(drawingProvider);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(ctx);
    messenger.showSnackBar(
      const SnackBar(content: Text('Exporting annotated PDF…')),
    );

    final result = await PdfExportService.exportWithAnnotations(
      sourceFilePath: widget.document.filePath,
      drawingState: drawingState,
      totalPages: _totalPages,
      pageWidthPt: 612, // US Letter default
      pageHeightPt: 792,
    );

    if (!mounted) return;
    messenger.clearSnackBars();

    if (result != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Exported to: $result')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Export failed. Check logs for details.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
