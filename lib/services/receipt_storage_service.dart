import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class ReceiptStorageService {
  final FirebaseStorage _storage;

  ReceiptStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadReceipt({
    required String uid,
    required String transactionId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _fileExtension(fileName);
    final path = 'users/$uid/receipts/$transactionId/$timestamp$extension';
    final ref = _storage.ref().child(path);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'transactionId': transactionId,
        },
      ),
    );

    return ref.getDownloadURL();
  }

  Future<void> deleteReceipt(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Ignore if file not found or already deleted
    }
  }

  String _fileExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot);
  }
}
