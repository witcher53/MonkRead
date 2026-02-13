

import 'package:flutter/material.dart';

/// Paints semi-transparent yellow rectangles over matched search results
/// on a PDF page overlay.
class SearchHighlightPainter extends CustomPainter {
  /// Normalized bounding rects (0–1) of the current match on this page.
  final List<Rect> matchBounds;

  /// Whether this page's match is the currently focused result.
  final bool isCurrentMatch;

  SearchHighlightPainter({
    required this.matchBounds,
    this.isCurrentMatch = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (matchBounds.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isCurrentMatch
          ? const Color(0x80FFC107) // amber highlight for current match
          : const Color(0x40FFEB3B); // light yellow for other matches

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isCurrentMatch
          ? const Color(0xCCFF8F00) // orange border for current
          : const Color(0x66FBC02D); // subtle border for others

    for (final rect in matchBounds) {
      final scaledRect = Rect.fromLTRB(
        rect.left * size.width,
        rect.top * size.height,
        rect.right * size.width,
        rect.bottom * size.height,
      );

      final rrect = RRect.fromRectAndRadius(scaledRect, const Radius.circular(2));
      canvas.drawRRect(rrect, paint);
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SearchHighlightPainter old) {
    return old.matchBounds != matchBounds ||
        old.isCurrentMatch != isCurrentMatch;
  }
}
