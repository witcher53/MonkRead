import 'package:flutter/material.dart';

/// Draggable vertical divider for split-screen layout.
///
/// Reports drag start, per-frame delta, and drag end separately
/// so the parent can implement a "ghost divider" pattern —
/// only committing the layout change on release.
class SplitHandle extends StatelessWidget {
  final VoidCallback? onDragStart;
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;

  const SplitHandle({
    super.key,
    this.onDragStart,
    required this.onDrag,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => onDragStart?.call(),
      onPanUpdate: (details) => onDrag(details.delta.dx),
      onPanEnd: (_) => onDragEnd?.call(),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 24,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
