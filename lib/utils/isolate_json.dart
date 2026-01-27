import 'dart:convert';
import 'dart:isolate';

Future<T> parseJsonInIsolate<T>(String source, T Function(dynamic) mapper) async {
  return Isolate.run<T>(() {
    final decoded = jsonDecode(source);
    return mapper(decoded);
  });
}
