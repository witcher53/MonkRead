import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:monkread/domain/entities/drawing_state.dart';
import 'package:pdfrx/pdfrx.dart';

/// An expandable floating dock for annotation tools + zoom + split view.
///
/// **Responsive Layout:**
/// - **Mobile (< 600px):** Horizontal scrollable row at bottom center.
/// - **Desktop:** Floating vertical panel + dedicated Zoom/Split islands.
class DrawingToolbar extends StatefulWidget {
  final AnnotationMode annotationMode;
  final bool canUndo;
  final Color selectedColor;
  final double selectedStrokeWidth;
  final PdfViewerController pdfController;
  final VoidCallback onTogglePen;
  final VoidCallback onToggleText;
  final VoidCallback onToggleLasso;
  final VoidCallback onHandMode;
  final VoidCallback onUndo;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final SplitViewMode splitViewMode;
  final VoidCallback onToggleDualPdf;
  final VoidCallback onToggleSidecar;
  // New callbacks for deletion
  final VoidCallback? onDeleteSelection;
  final VoidCallback? onClearPage;
  // Visibility toggle
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  const DrawingToolbar({
    super.key,
    required this.annotationMode,
    required this.canUndo,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.pdfController,
    required this.onTogglePen,
    required this.onToggleText,
    required this.onToggleLasso,
    required this.onHandMode,
    required this.onUndo,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.splitViewMode,
    required this.onToggleDualPdf,
    required this.onToggleSidecar,
    this.onDeleteSelection,
    this.onClearPage,
    this.isVisible = true,
    this.onToggleVisibility,
  });

  @override
  State<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends State<DrawingToolbar>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    if (isMobile) {
      return _buildMobileLayout(context);
    } else {
      return _buildDesktopLayout(context);
    }
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isNone = widget.annotationMode == AnnotationMode.none;
    final isPen = widget.annotationMode == AnnotationMode.pen;
    final isText = widget.annotationMode == AnnotationMode.text;
    final isLasso = widget.annotationMode == AnnotationMode.lasso;

    // Consolidate all tools into one horizontal list
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Core Tools
              _DockItem(
                icon: Icons.pan_tool_alt_rounded,
                label: 'Hand',
                isActive: isNone,
                activeColor: Colors.blueGrey,
                onTap: widget.onHandMode,
              ),
              _DockItem(
                icon: Icons.edit_rounded,
                label: 'Pen',
                isActive: isPen,
                activeColor: theme.colorScheme.primary,
                onTap: widget.onTogglePen,
              ),
              _DockItem(
                icon: Icons.text_fields_rounded,
                label: 'Text',
                isActive: isText,
                activeColor: theme.colorScheme.tertiary,
                onTap: widget.onToggleText,
              ),
              _DockItem(
                icon: Icons.gesture_rounded,
                label: 'Lasso',
                isActive: isLasso,
                activeColor: Colors.deepOrangeAccent,
                onTap: widget.onToggleLasso,
              ),
              
              const _DockDivider(isVertical: false),

              // 2. Properties (Color/Stroke) - Only if relevant
              if (isPen || isText)
                _DockItem(
                  icon: Icons.palette_rounded,
                  label: 'Color',
                  iconColor: widget.selectedColor,
                  onTap: () => _showColorPicker(context),
                ),
              if (isPen)
                _StrokeDot(
                  width: widget.selectedStrokeWidth,
                  color: widget.selectedColor,
                  onTap: () => _showStrokeWidthPicker(context),
                ),
              
              if (isPen || isText) const _DockDivider(isVertical: false),

               // 3. Actions (Undo, Delete, Clear)
              if (isPen && widget.canUndo)
                _DockItem(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onTap: widget.onUndo,
                ),
               if (widget.onDeleteSelection != null)
                _DockItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  iconColor: Colors.red,
                  onTap: widget.onDeleteSelection!,
                ),
               if (widget.onClearPage != null)
                 _DockItem(
                  icon: Icons.layers_clear_rounded,
                  label: 'Clear',
                  iconColor: Colors.redAccent,
                  onTap: () => _confirmClearPage(context),
                ),

              const _DockDivider(isVertical: false),

              // 4. View Controls (Zoom, Split)
              _DockItem(
                icon: Icons.zoom_in_rounded,
                label: 'Zoom In',
                onTap: () => widget.pdfController.zoomUp(),
              ),
              _DockItem(
                icon: Icons.zoom_out_rounded,
                label: 'Zoom Out',
                onTap: () => widget.pdfController.zoomDown(),
              ),
              _DockItem(
                icon: Icons.auto_stories_rounded,
                label: 'Dual PDF',
                isActive: widget.splitViewMode == SplitViewMode.dualPdf,
                activeColor: const Color(0xFF6750A4),
                onTap: widget.onToggleDualPdf,
              ),
               _DockItem(
                icon: Icons.note_alt_rounded,
                label: 'Notes',
                isActive: widget.splitViewMode == SplitViewMode.sidecar,
                activeColor: const Color(0xFF2E7D32),
                onTap: widget.onToggleSidecar,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final isNone = widget.annotationMode == AnnotationMode.none;
    final isPen = widget.annotationMode == AnnotationMode.pen;
    final isText = widget.annotationMode == AnnotationMode.text;
    final isLasso = widget.annotationMode == AnnotationMode.lasso;
    final isAnnotating = widget.annotationMode != AnnotationMode.none;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      right: widget.isVisible ? 12 : -80,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Expandable tool panel ─────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: 1.0,
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Delete Selection (only if provided)
                  if (widget.onDeleteSelection != null)
                    _DockItem(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      iconColor: Colors.red,
                      onTap: widget.onDeleteSelection!,
                    ),
                  
                  // Clear Page (only if provided)
                  if (widget.onClearPage != null)
                     _DockItem(
                      icon: Icons.layers_clear_rounded,
                      label: 'Clear',
                      iconColor: Colors.redAccent,
                      onTap: () => _confirmClearPage(context),
                    ),

                   if (widget.onDeleteSelection != null || widget.onClearPage != null)
                    const _DockDivider(),

                  // Hand (View/Navigate)
                  _DockItem(
                    icon: Icons.pan_tool_alt_rounded,
                    label: 'Hand',
                    isActive: isNone,
                    activeColor: Colors.blueGrey,
                    onTap: widget.onHandMode,
                  ),
                  // Pen
                  _DockItem(
                    icon: Icons.edit_rounded,
                    label: 'Pen',
                    isActive: isPen,
                    activeColor: theme.colorScheme.primary,
                    onTap: widget.onTogglePen,
                  ),
                  // Text
                  _DockItem(
                    icon: Icons.text_fields_rounded,
                    label: 'Text',
                    isActive: isText,
                    activeColor: theme.colorScheme.tertiary,
                    onTap: widget.onToggleText,
                  ),
                  // Lasso
                  _DockItem(
                    icon: Icons.gesture_rounded,
                    label: 'Lasso',
                    isActive: isLasso,
                    activeColor: Colors.deepOrangeAccent,
                    onTap: widget.onToggleLasso,
                  ),
                  const _DockDivider(),
                  // Color (only in pen/text modes)
                  if (isPen || isText)
                    _DockItem(
                      icon: Icons.palette_rounded,
                      label: 'Color',
                      iconColor: widget.selectedColor,
                      onTap: () => _showColorPicker(context),
                    ),
                  // Stroke width (pen mode)
                  if (isPen)
                    _StrokeDot(
                      width: widget.selectedStrokeWidth,
                      color: widget.selectedColor,
                      onTap: () => _showStrokeWidthPicker(context),
                    ),
                  // Undo (pen mode only)
                  if (isPen && widget.canUndo) ...[
                    const _DockDivider(),
                    _DockItem(
                      icon: Icons.undo_rounded,
                      label: 'Undo',
                      onTap: widget.onUndo,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Zoom ± (always visible) ───────────────
          Container(
            width: 52,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DockItem(
                  icon: Icons.zoom_in_rounded,
                  label: 'Zoom In',
                  onTap: () => widget.pdfController.zoomUp(),
                ),
                _DockItem(
                  icon: Icons.zoom_out_rounded,
                  label: 'Zoom Out',
                  onTap: () => widget.pdfController.zoomDown(),
                ),
              ],
            ),
          ),

          // ── Split view buttons (always visible) ───
          Container(
            width: 52,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DockItem(
                  icon: Icons.auto_stories_rounded,
                  label: 'Dual PDF',
                  isActive: widget.splitViewMode == SplitViewMode.dualPdf,
                  activeColor: const Color(0xFF6750A4),
                  onTap: widget.onToggleDualPdf,
                ),
                _DockItem(
                  icon: Icons.note_alt_rounded,
                  label: 'Notes',
                  isActive: widget.splitViewMode == SplitViewMode.sidecar,
                  activeColor: const Color(0xFF2E7D32),
                  onTap: widget.onToggleSidecar,
                ),
              ],
            ),
          ),

          // ── Main Tools FAB ────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hide button (only when expanded)
              if (_expanded && widget.onToggleVisibility != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FloatingActionButton.small(
                    heroTag: 'hide_toolbar_fab',
                    onPressed: () {
                      if (_expanded) _toggle();
                      widget.onToggleVisibility!();
                    },
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurface,
                    elevation: 2,
                    child: const Icon(Icons.chevron_right_rounded, size: 20),
                  ),
                ),
              FloatingActionButton(
                heroTag: 'tools_fab',
                onPressed: _toggle,
                backgroundColor: _expanded
                    ? theme.colorScheme.primaryContainer
                    : isAnnotating
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                foregroundColor: _expanded
                    ? theme.colorScheme.onPrimaryContainer
                    : isAnnotating
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                elevation: _expanded ? 8 : 3,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _expanded ? Icons.close_rounded : Icons.construction_rounded,
                    key: ValueKey(_expanded),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────

  void _confirmClearPage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Page?'),
        content: const Text(
          'This will remove all drawings and text from the current page. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onClearPage?.call();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    Color tempColor = widget.selectedColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: widget.selectedColor,
            onColorChanged: (c) => tempColor = c,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.onColorChanged(tempColor);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showStrokeWidthPicker(BuildContext context) {
    double tempWidth = widget.selectedStrokeWidth;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Stroke Width'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  painter: _StrokePreviewPainter(
                    color: widget.selectedColor,
                    strokeWidth: tempWidth,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('${tempWidth.toStringAsFixed(1)} px'),
                  Expanded(
                    child: Slider(
                      value: tempWidth,
                      min: 1.0,
                      max: 20.0,
                      divisions: 38,
                      onChanged: (v) => setDialogState(() => tempWidth = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                widget.onStrokeWidthChanged(tempWidth);
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Dock helper widgets
// ─────────────────────────────────────────────────────────────────

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _DockItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.activeColor,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? (activeColor ?? theme.colorScheme.primary)
        : iconColor ?? theme.colorScheme.onSurface;

    return SizedBox(
      width: 48,
      height: 48, // Increased to 48 for mobile touch target
      child: Material(
        color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Icon(icon, size: 24, color: color), // Increased icon size slightly
        ),
      ),
    );
  }
}

class _DockDivider extends StatelessWidget {
  final bool isVertical;
  const _DockDivider({this.isVertical = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: isVertical
          ? Divider(height: 1, thickness: 1, color: Colors.grey.shade300)
          : VerticalDivider(width: 1, thickness: 1, color: Colors.grey.shade300),
    );
  }
}

class _StrokeDot extends StatelessWidget {
  final double width;
  final Color color;
  final VoidCallback onTap;

  const _StrokeDot({
    required this.width,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Container(
            width: width.clamp(4.0, 22.0),
            height: width.clamp(4.0, 22.0),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _StrokePreviewPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _StrokePreviewPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final path = Path();
    final cy = size.height / 2;
    path.moveTo(16, cy);
    path.quadraticBezierTo(size.width * 0.3, cy - 20, size.width * 0.5, cy);
    path.quadraticBezierTo(size.width * 0.7, cy + 20, size.width - 16, cy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePreviewPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
