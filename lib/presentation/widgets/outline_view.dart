import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class OutlineView extends StatelessWidget {
  final PdfViewerController controller;
  final PdfDocument document;
  final VoidCallback? onLinkTap;

  const OutlineView({
    super.key,
    required this.controller,
    required this.document,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    // loadOutline is async in pdfrx
    return FutureBuilder<List<PdfOutlineNode>>(
      future: document.loadOutline(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading outline: ${snapshot.error}'));
        }
        final outline = snapshot.data;
        if (outline == null || outline.isEmpty) {
          return const Center(child: Text('No outline available.'));
        }

        return ListView(
          children: outline.map((node) => _buildNode(node)).toList(),
        );
      },
    );
  }

  Widget _buildNode(PdfOutlineNode node) {
    if (node.children.isEmpty) {
      return ListTile(
        title: Text(node.title),
        onTap: () {
          _handleLink(node);
        },
        dense: true,
      );
    }

    return ExpansionTile(
      title: Text(node.title),
      childrenPadding: const EdgeInsets.only(left: 16.0),
      children: node.children.map((child) => _buildNode(child)).toList(),
    );
  }

  void _handleLink(PdfOutlineNode node) {
    if (node.dest != null) {
      controller.goToDest(node.dest);
      onLinkTap?.call();
    }
  }
}
