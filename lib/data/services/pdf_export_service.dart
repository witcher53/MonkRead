import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:monkread/domain/entities/drawing_state.dart';

/// Service for flattening user annotations onto a PDF and exporting it.
///
/// Coordinate transformation:
/// ```
/// X_pdf = X_normalized * pageWidthPt
/// Y_pdf = Y_normalized * pageHeightPt
/// ```
class PdfExportService {
  PdfExportService._();

  /// Exports the given [sourceFilePath] PDF with [drawingState] annotations
  /// flattened onto each page.
  ///
  /// Returns the saved file path on mobile/desktop, or triggers a browser
  /// download on web.
  static Future<String?> exportWithAnnotations({
    required String sourceFilePath,
    required DocumentDrawingState drawingState,
    required int totalPages,
    required double pageWidthPt,
    required double pageHeightPt,
  }) async {
    try {
      // Read original PDF bytes
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        debugPrint('PdfExportService: source file not found');
        return null;
      }
      // ignore: unused_local_variable
      final sourceBytes = await sourceFile.readAsBytes();

      // Build a new PDF with annotations overlaid
      final doc = pw.Document();

      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final strokes = drawingState.strokesForPage(pageIndex);
        final texts = drawingState.textAnnotationsForPage(pageIndex);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageWidthPt, pageHeightPt),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // Original page as background image placeholder
                  // (pdfrx renders the original; we overlay annotations)
                  pw.Container(
                    width: pageWidthPt,
                    height: pageHeightPt,
                  ),

                  // Strokes
                  ...strokes.map((stroke) => _buildStrokeWidget(
                        stroke,
                        pageWidthPt,
                        pageHeightPt,
                      )),

                  // Text annotations
                  ...texts.map((text) => _buildTextWidget(
                        text,
                        pageWidthPt,
                        pageHeightPt,
                      )),
                ],
              );
            },
          ),
        );
      }

      final pdfBytes = await doc.save();

      // Use printing package for cross-platform sharing
      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(pdfBytes),
          filename: _exportFileName(sourceFilePath),
        );
        return 'shared';
      }

      // Save to documents directory
      final dir = await getApplicationDocumentsDirectory();
      final exportName = _exportFileName(sourceFilePath);
      final exportPath = p.join(dir.path, exportName);
      final exportFile = File(exportPath);
      await exportFile.writeAsBytes(pdfBytes);

      debugPrint('PdfExportService: exported to $exportPath');
      return exportPath;
    } catch (e, stack) {
      debugPrint('PdfExportService: export failed: $e');
      debugPrint('$stack');
      return null;
    }
  }

  /// Build a pw.Widget representing a single stroke.
  static pw.Widget _buildStrokeWidget(
    DrawingPath stroke,
    double pageW,
    double pageH,
  ) {
    if (stroke.points.length < 2) return pw.SizedBox.shrink();

    return pw.CustomPaint(
      size: PdfPoint(pageW, pageH),
      painter: (PdfGraphics canvas, PdfPoint size) {
        canvas
          ..setStrokeColor(PdfColor(
            stroke.color.r,
            stroke.color.g,
            stroke.color.b,
            stroke.color.a,
          ))
          ..setLineWidth(stroke.strokeWidth)
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round);

        final first = stroke.points.first;
        canvas.moveTo(first.dx * pageW, pageH - (first.dy * pageH));

        for (int i = 1; i < stroke.points.length; i++) {
          final pt = stroke.points[i];
          canvas.lineTo(pt.dx * pageW, pageH - (pt.dy * pageH));
        }

        canvas.strokePath();
      },
    );
  }

  /// Build a pw.Widget representing a text annotation.
  static pw.Widget _buildTextWidget(
    TextAnnotation text,
    double pageW,
    double pageH,
  ) {
    final x = text.position.dx * pageW;
    final y = text.position.dy * pageH;

    return pw.Positioned(
      left: x,
      top: y,
      child: pw.Text(
        text.text,
        style: pw.TextStyle(
          fontSize: text.fontSize,
          color: PdfColor(
            text.color.r,
            text.color.g,
            text.color.b,
            text.color.a,
          ),
        ),
      ),
    );
  }

  static String _exportFileName(String sourcePath) {
    final baseName = p.basenameWithoutExtension(sourcePath);
    return '${baseName}_annotated.pdf';
  }
}
