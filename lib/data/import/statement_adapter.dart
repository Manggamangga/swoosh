import 'dart:typed_data';

import 'package:swoosh/data/import/parsed_statement.dart';

abstract interface class StatementAdapter {
  Future<ParsedStatement> parse(Uint8List bytes, String filename);
}
