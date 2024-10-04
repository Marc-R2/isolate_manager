import 'dart:convert';

/// This [IsolateException] mainly use to transfer an [Exception] between an `Isolate` and
/// the main app.
class IsolateException implements Exception {
  /// This [IsolateException] mainly use to transfer an [Exception] between an `Isolate` and
  /// the main app.
  const IsolateException(this.id, this.error, [this.stack = StackTrace.empty]);

  /// Convert from JSON.
  factory IsolateException.fromJson(dynamic json) {
    assert(
      isValidObject(json),
      'json should be checked by `isValidObject` before using',
    );

    final decoded = jsonDecode(json.toString());
    final values = decoded[r'$IsolateException'] as Map;

    return IsolateException(
      values['id'] as int,
      values['error'] as Object,
      StackTrace.fromString(values['stack'] as String),
    );
  }

  final int id;

  /// Error object.
  final Object error;

  /// StackTrace.
  final StackTrace stack;

  /// Convert to JSON.
  String toJson() => jsonEncode({
        r'$IsolateException': {
          'id': id,
          'error': error.toString(),
          'stack': stack.toString(),
        },
      });

  /// Check if the [json] is a valid [IsolateException].
  static bool isValidObject(dynamic json) {
    try {
      final decoded = jsonDecode(json.toString()) as Map;
      return decoded.containsKey(r'$IsolateException');
    } catch (_) {}
    return false;
  }

  @override
  String toString() {
    return 'IsolateException{id: $id, error: $error}';
  }
}
