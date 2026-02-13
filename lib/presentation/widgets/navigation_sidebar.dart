import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:monkread/presentation/widgets/thumbnail_view.dart';
import 'package:monkread/presentation/widgets/outline_view.dart';
import 'package:monkread/presentation/providers/bookmark_provider.dart';

class NavigationSidebar extends ConsumerWidget {
  final PdfViewerController controller;
  final PdfDocument document;
  final String filePath;
  final VoidCallback onClose;

  const NavigationSidebar({
    super.key,
    required this.controller,
    required this.document,
    required this.filePath,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider(filePath));

    return DefaultTabController(
      length: 3,
      child: Container(
        width: 320,
        color: Theme.of(context).cardColor,
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(context),
            Expanded(
              child: TabBarView(
                children: [
                  // Thumbnails
                  ThumbnailView(
                    controller: controller,
                    document: document,
                  ),
                  // Outline
                  OutlineView(
                    controller: controller,
                    document: document,
                    onLinkTap: () {
                      // Optional: close sidebar on mobile
                    },
                  ),
                  // Bookmarks
                  _buildBookmarksList(context, ref, bookmarks),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Navigation',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return TabBar(
      tabs: const [
        Tab(icon: Icon(Icons.grid_view), text: 'Thumbnails'),
        Tab(icon: Icon(Icons.list), text: 'Outline'),
        Tab(icon: Icon(Icons.bookmark), text: 'Bookmarks'),
      ],
      labelColor: Theme.of(context).primaryColor,
      unselectedLabelColor: Colors.grey,
      indicatorColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildBookmarksList(BuildContext context, WidgetRef ref, List<dynamic> bookmarks) {
    if (bookmarks.isEmpty) {
      return const Center(child: Text('No bookmarks yet.'));
    }

    return ListView.builder(
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        return ListTile(
          leading: const Icon(Icons.bookmark, color: Colors.amber),
          title: Text(bookmark.title),
          subtitle: Text('Page ${bookmark.pageIndex + 1}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              ref.read(bookmarkProvider(filePath).notifier).removeBookmark(bookmark.id);
            },
          ),
          onTap: () {
            controller.goToPage(pageNumber: bookmark.pageIndex + 1);
          },
        );
      },
    );
  }
}
