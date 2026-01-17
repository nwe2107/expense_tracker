import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class VisionOcrService {
  VisionOcrService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiKey = String.fromEnvironment('VISION_API_KEY');

  Future<String> detectReceiptText({
    required Uint8List bytes,
    List<String> languageHints = const ['en', 'he'],
  }) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Missing Google Vision API key. '
        'Run with --dart-define=VISION_API_KEY=YOUR_KEY.',
      );
    }

    final uri = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey',
    );
    final body = jsonEncode({
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

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
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
