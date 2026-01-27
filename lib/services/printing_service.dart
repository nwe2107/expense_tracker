import 'dart:typed_data';
import 'package:printing/printing.dart';

class PrintingService {
  /// Print precomputed bytes. Avoid heavy work inside `onLayout`.
  static Future<void> printPrecomputedBytes(Uint8List bytes, {String jobName = 'Document'}) async {
    // The `onLayout` still needs to return bytes, but we return immediately with precomputed data.
    await Printing.layoutPdf(
      name: jobName,
      onLayout: (_) async => bytes,
    );
  }

  /// Share precomputed bytes.
  static Future<void> sharePrecomputedBytes(Uint8List bytes, {required String filename}) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
