/// Wraps an async call, returning [fallback] on any exception.
Future<T> safeCall<T>(Future<T> Function() fn, T fallback, {String? tag}) async {
  try {
    return await fn();
  } catch (e) {
    if (tag != null) print('[$tag] Error: $e');
    return fallback;
  }
}
