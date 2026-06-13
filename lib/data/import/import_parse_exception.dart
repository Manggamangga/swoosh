class ImportParseException implements Exception {
  ImportParseException(this.message);

  final String message;

  @override
  String toString() => message;
}
