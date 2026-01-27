import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api_key.dart';
import '../utils/isolate_json.dart';

class VisionOcrService {
  VisionOcrService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Uses the key from lib/api_key.dart (which is git-ignored)
  static final String _apiKey = visionApiKey.trim();

  Future<String> detectReceiptText({
    required Uint8List bytes,
    List<String> languageHints = const ['en', 'he'],
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'PASTE_YOUR_KEY_HERE') {
      throw StateError(
        'Missing Google Vision API key. '
        'Please open lib/api_key.dart and paste your key there.',
      );
    }

    final uri = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey',
    );

    final body = await Isolate.run(() {
      return jsonEncode({
        'requests': [
          {
            'image': {'content': base64Encode(bytes)},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION'}
            ],
            'imageContext': {
              'languageHints': languageHints,
            },
          }
        ],
      });
    });

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw StateError(
        'Vision API error (${response.statusCode}): ${response.body}',
      );
    }

    final payload = await parseJsonInIsolate<Map<String, dynamic>>(
      response.body,
      (json) => json as Map<String, dynamic>,
    );
    final responses = payload['responses'] as List<dynamic>? ?? const [];
    if (responses.isEmpty) return '';

    final first = responses.first as Map<String, dynamic>;
    final annotations = first['textAnnotations'] as List<dynamic>? ?? const [];
    if (annotations.isEmpty) return '';

    final firstAnnotation = annotations.first as Map<String, dynamic>;
    final description = firstAnnotation['description'] as String?;
    return description?.trim() ?? '';
  }
}
