import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monkread/core/constants/app_constants.dart';
import 'package:monkread/domain/entities/book_entity.dart';
import 'package:monkread/domain/entities/pdf_document.dart';
import 'package:monkread/presentation/providers/file_provider.dart';
import 'package:monkread/presentation/providers/library_provider.dart';
import 'package:monkread/presentation/widgets/book_card.dart';
import 'package:monkread/presentation/widgets/download_dialog.dart';
import 'package:monkread/presentation/widgets/error_dialog.dart';

/// The app's landing screen.
///
/// Shows a bookshelf grid of recently opened PDFs, or an empty-state prompt
/// when the library is empty. A FAB opens a new PDF via the file picker.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to pdf pick state changes for navigation / errors
    ref.listen<PdfPickState>(pdfPickProvider, (previous, next) {
      if (next is PdfPickSuccess) {
        final doc = next.document;

        // Save to library
        ref.read(libraryProvider.notifier).addBook(BookEntity(
              filePath: doc.filePath,
              fileName: doc.fileName,
              lastOpened: DateTime.now(),
            ));

        // Navigate to the reader and reset the pick state
        context.push(AppConstants.readerRoute, extra: doc);
        ref.read(pdfPickProvider.notifier).reset();
      } else if (next is PdfPickError) {
        showErrorDialog(context, next.failure.message);
      }
    });

    final pickState = ref.watch(pdfPickProvider);
    final libraryState = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_rounded),
            tooltip: 'Download from URL',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const DownloadDialog(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: libraryState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load library: $e')),
        data: (books) =>
            books.isEmpty ? _buildEmptyState(context, ref) : _buildBookshelf(context, ref, books),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: pickState is PdfPickLoading
            ? null
            : () => ref.read(pdfPickProvider.notifier).pickPdf(),
        icon: pickState is PdfPickLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_rounded),
        label: Text(
          pickState is PdfPickLoading ? 'Opening…' : 'Open PDF',
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to MonkRead',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the button below to open a PDF file\nand start reading.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                // Open file
                FilledButton.icon(
                  onPressed: () => ref.read(pdfPickProvider.notifier).pickPdf(),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Open File'),
                ),
                // Download
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const DownloadDialog(),
                    );
                  },
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: const Text('Download URL'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookshelf(
    BuildContext context,
    WidgetRef ref,
    List<BookEntity> books,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Library',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  onTap: () {
                    // Update last opened time
                    ref.read(libraryProvider.notifier).addBook(
                          book.copyWith(lastOpened: DateTime.now()),
                        );

                    // Navigate to reader
                    context.push(
                      AppConstants.readerRoute,
                      extra: PdfDocument(
                        filePath: book.filePath,
                        fileName: book.fileName,
                        lastPage: book.lastPage,
                      ),
                    );
                  },
                  onLongPress: () {
                    _showDeleteDialog(context, ref, book);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    BookEntity book,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from library?'),
        content: Text(
          'Remove "${book.fileName}" from your bookshelf?\n'
          'The file itself will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(libraryProvider.notifier).removeBook(book.filePath);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
