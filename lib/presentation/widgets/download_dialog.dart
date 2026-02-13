import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monkread/presentation/providers/download_provider.dart';

class DownloadDialog extends ConsumerStatefulWidget {
  const DownloadDialog({super.key});

  @override
  ConsumerState<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<DownloadDialog> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadProvider);

    // Listen for success/error
    ref.listen(downloadProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      } else if (next.successMessage != null && prev?.successMessage == null) {
        Navigator.of(context).pop(); // Close dialog on success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(downloadProvider.notifier).clearMessage();
      }
    });

    return AlertDialog(
      title: const Text('Download PDF'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com/document.pdf',
              border: OutlineInputBorder(),
            ),
            enabled: !state.isDownloading,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'File Name (Optional)',
              hintText: 'My Document',
              border: OutlineInputBorder(),
            ),
            enabled: !state.isDownloading,
          ),
          if (state.isDownloading) ...[
            const SizedBox(height: 24),
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 8),
            Text('${(state.progress * 100).toStringAsFixed(1)}%'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: state.isDownloading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isDownloading ? null : _download,
          child: const Text('Download'),
        ),
      ],
    );
  }

  void _download() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final name = _nameController.text.trim();
    ref.read(downloadProvider.notifier).downloadFile(
          url,
          customFileName: name.isNotEmpty ? name : null,
        );
  }
}
