import 'package:flutter/material.dart';

/// Dialog for creating or editing a text annotation.
///
/// Returns a map with `text`, `fontSize`, and `color` if confirmed, or null.
class TextInputDialog extends StatefulWidget {
  final String initialText;
  final double initialFontSize;
  final Color initialColor;

  const TextInputDialog({
    super.key,
    this.initialText = '',
    this.initialFontSize = 16.0,
    this.initialColor = const Color(0xFF000000),
  });

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  late final TextEditingController _controller;
  late double _fontSize;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _fontSize = widget.initialFontSize;
    _color = widget.initialColor;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Text'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Text field ────────────────────────────
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type your annotation…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Font size slider ─────────────────────
            Row(
              children: [
                const Icon(Icons.format_size, size: 18),
                const SizedBox(width: 8),
                Text('Size: ${_fontSize.round()}',
                    style: theme.textTheme.bodySmall),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 10,
                    max: 48,
                    divisions: 38,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
              ],
            ),

            // ── Preview ──────────────────────────────
            if (_controller.text.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _controller.text,
                  style: TextStyle(
                    fontSize: _fontSize,
                    color: _color,
                  ),
                ),
              ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'text': _controller.text.trim(),
              'fontSize': _fontSize,
              'color': _color,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
