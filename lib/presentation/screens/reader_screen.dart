import 'dart:async';
// import 'dart:io'; // Removed for web compatibility
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:monkread/domain/entities/pdf_document.dart' as monk;
import 'package:monkread/presentation/providers/bookmark_provider.dart';
import 'package:monkread/data/services/pdf_export_service.dart';
import 'package:monkread/domain/entities/drawing_state.dart';
import 'package:monkread/presentation/providers/drawing_provider.dart';
import 'package:monkread/presentation/providers/library_provider.dart';
import 'package:monkread/presentation/providers/sidecar_provider.dart';
import 'package:monkread/presentation/providers/split_view_provider.dart';
import 'package:monkread/presentation/widgets/ai_sidebar.dart';
import 'package:monkread/presentation/widgets/drawing_canvas.dart';
import 'package:monkread/presentation/widgets/drawing_toolbar.dart';
import 'package:monkread/presentation/widgets/navigation_sidebar.dart';
import 'package:monkread/presentation/widgets/sidecar_canvas.dart';
import 'package:monkread/presentation/widgets/split_handle.dart';
import 'package:monkread/presentation/widgets/text_input_dialog.dart';

/// Renders a PDF with per-page drawing/text overlays, optional dual PDF
/// view, and sidecar infinite whiteboard.
class ReaderScreen extends ConsumerStatefulWidget {
  final monk.PdfDocument document;

  const ReaderScreen({super.key, required this.document});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  bool _showAiSidebar = false;
  bool _showSidenav = false;
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
          leading: IconButton(
            icon: const Icon(Icons.menu_open),
            tooltip: 'Navigation',
            onPressed: () => setState(() => _showSidenav = !_showSidenav),
          ),
          title: Text(
            widget.document.fileName,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
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
                      color: _indicatorColor(mode).withOpacity(0.15),
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
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15),
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
            
            // ── Bookmark Button ───────────────────────
            Consumer(
              builder: (context, ref, _) {
                final bookmarks = ref.watch(bookmarkProvider(widget.document.filePath));
                final isBookmarked = bookmarks.any((b) => b.pageIndex == _currentPage);
                return IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? Theme.of(context).colorScheme.primary : null,
                  ),
                  tooltip: isBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
                  onPressed: () {
                    ref.read(bookmarkProvider(widget.document.filePath).notifier)
                       .toggleBookmark(_currentPage);
                  },
                );
              },
            ),

            // ── Export Button ─────────────────────────
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export PDF with Annotations',
              onPressed: _handleExport,
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
          ],
        ),
        // Mobile Drawer
        drawer: MediaQuery.of(context).size.width < 900
            ? NavigationSidebar(
                controller: _pdfController,
                document: _pdfController.document!,
                filePath: widget.document.filePath,
                onClose: () => Navigator.pop(context),
              )
            : null,
        body: Row(
          children: [
            // Desktop Sidebar (Animated)
            if (MediaQuery.of(context).size.width >= 900)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: _showSidenav ? 320 : 0,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 320,
                    maxWidth: 320,
                    alignment: Alignment.topLeft,
                    child: _isReady && _pdfController.document != null
                        ? NavigationSidebar(
                            controller: _pdfController,
                            document: _pdfController.document!,
                            filePath: widget.document.filePath,
                            onClose: () => setState(() => _showSidenav = false),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

            // Main Content Area
            Expanded(
              child: Stack(
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
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
                    onStrokeWidthChanged: (width) => ref
                        .read(drawingProvider.notifier)
                        .setStrokeWidth(width),
                    onToggleDualPdf: _handleToggleDualPdf,
                    onToggleSidecar: () =>
                        ref.read(splitViewProvider.notifier).toggleSidecar(),
                    onDeleteSelection:
                        (drawingState.lassoSelection?.isEmpty ?? true)
                            ? null
                            : () => ref
                                .read(drawingProvider.notifier)
                                .deleteSelection(),
                    onClearPage: () => ref
                        .read(drawingProvider.notifier)
                        .clearCurrentPage(),
                  ),

                  // ── AI Sidebar ─────────────────────────────
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
                ],
              ),
            ),
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

  Future<void> _handleExport() async {
    // Basic dialog to confirm export
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export PDF'),
        content: const Text(
            'This will export a copy of the PDF with all your annotations embedded.\nContinue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF with annotations...')),
    );

    try {
      final doc = _pdfController.document;
      if (doc == null || doc.pages.isEmpty) {
        throw Exception('PDF document not loaded');
      }

      // Use the first page size for export (simplification)
      // Ideally we'd handle mixed page sizes, but the service enforces one.
      final firstPage = doc.pages.first;
      
      final outputPath = await PdfExportService.exportWithAnnotations(
        sourceFileName: widget.document.fileName,
        drawingState: ref.read(drawingProvider),
        totalPages: doc.pages.length,
        pageWidthPt: firstPage.width,
        pageHeightPt: firstPage.height,
      );

      if (outputPath != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: $outputPath'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                // TODO: Open file logic
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Layout builders
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPrimaryPdf(AnnotationMode mode, bool isAnnotating) {
    final params = PdfViewerParams(
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
    );

    if (kIsWeb && widget.document.bytes != null) {
      return PdfViewer.data(
        widget.document.bytes!,
        controller: _pdfController,
        initialPageNumber: widget.document.lastPage + 1,
        params: params,
        sourceName: widget.document.fileName,
      );
    }

    return PdfViewer.file(
      widget.document.filePath,
      controller: _pdfController,
      initialPageNumber: widget.document.lastPage + 1,
      params: params,
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

    return [
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
    
    // Prevent gray screen by waiting for file availability/build cycle
    return FutureBuilder<bool>(
      future: Future.delayed(const Duration(milliseconds: 100), () async {
        // Simulating check to allow build cycle to pass
        return true; 
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return PdfViewer.file(
          filePath,
          key: ValueKey(filePath), // Force rebuild if file changes
          controller: _secondaryPdfController,
          params: PdfViewerParams(
            maxScale: 8.0,
            scrollByMouseWheel: 1.5,
            errorBannerBuilder: (context, error, stackTrace, documentRef) {
              return Center(child: Text('Error loading PDF: $error'));
            },
          ),
        );
      },
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
}
