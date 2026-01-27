import 'dart:typed_data';
import 'dart:isolate';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  // Example data model; replace with your own as needed.
  // Keep the API generic so we can reuse this in multiple flows.
  static Future<Uint8List> generateSamplePdf({
    required String title,
    required List<String> lines,
  }) async {
    // Run heavy PDF creation off the UI isolate.
    return Isolate.run<Uint8List>(() {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(level: 0, child: pw.Text(title)),
            ...lines.map((e) => pw.Paragraph(text: e)),
          ],
        ),
      );
      return doc.save();
    });
  }
}
