import 'dart:convert';
import 'package:crypto/crypto.dart';

String buildDedupeHash({
  required String accountId,
  required DateTime date,
  required int amountPence,
  required String description,
}) {
  final normalized = description.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final payload = '$accountId|${date.toIso8601String().split('T').first}|$amountPence|$normalized';
  return sha256.convert(utf8.encode(payload)).toString();
}
