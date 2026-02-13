import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ThumbnailView extends StatelessWidget {
  final PdfViewerController controller;
  final PdfDocument document;

  const ThumbnailView({
    super.key,
    required this.controller,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: document.pages.length,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        // Check if this is the current page (approximate for simplicity)
        // Ideally we'd listen to controller.pageNumber, but here we keep it simple or pass it in.
        // For better UX, we'd wrap in Consumer/ValueListenableBuilder.
        // Let's rely on simple navigation for now.

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => controller.goToPage(pageNumber: pageNumber),
                child: Container(
                  height: 200, // Fixed height for consistency
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PdfPageView(
                    document: document,
                    pageNumber: pageNumber,
                    // Disable interaction allows it to act as a static image
                    decorationBuilder: null, 
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Page $pageNumber',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
