import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

class ReceiptScanService {
  final FlutterDocScanner _scanner = FlutterDocScanner();

  /// Scans a receipt using the device camera with document detection.
  /// Returns a [File] if successful, or null if cancelled/failed.
  /// Currently limited to 1 page.
  Future<File?> scanReceipt() async {
    try {
      // page: 1 limits the scan to 1 page
      final dynamic result = await _scanner.getScannedDocumentAsImages(page: 1);
      
      if (result is List && result.isNotEmpty) {
        // The result is a list of file paths (Strings)
        return File(result.first.toString());
      }
      return null;
    } on PlatformException catch (e) {
      // Handle known error codes if needed
      debugPrint('Scan failed or cancelled: $e');
      return null;
    } catch (e) {
      debugPrint('Error scanning receipt: $e');
      return null;
    }
  }
}
