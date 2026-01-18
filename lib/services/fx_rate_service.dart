import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class FxRateException implements Exception {
  final String message;

  const FxRateException(this.message);

  @override
  String toString() => message;
}

class FxRateService {
  static const _baseUrl = 'https://api.frankfurter.app';

  Future<double> getRate({
    required DateTime date,
    required String from,
    required String to,
  }) async {
    if (from == to) return 1.0;
    final dateKey = _formatDate(date);
    final uri = Uri.parse('$_baseUrl/$dateKey?from=$from&to=$to');
    final response = await http.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 404) {
        throw const FxRateException('FX rate not available for this date or currency.');
      }
      throw FxRateException('FX request failed (${response.statusCode}).');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rates = payload['rates'] as Map<String, dynamic>?;
    final raw = rates?[to];
    if (raw is num) return raw.toDouble();
    throw FxRateException('FX rate not available for $from->$to on $dateKey.');
  }

  String _formatDate(DateTime date) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
