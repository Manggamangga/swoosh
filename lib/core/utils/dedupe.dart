import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:swoosh/data/import/parsed_statement.dart';

String buildDedupeHash({
  required String accountId,
  required DateTime date,
  required int amountPence,
  required String description,
  String? providerTxnId,
  int ordinal = 0,
}) {
  if (providerTxnId != null && providerTxnId.isNotEmpty) {
    final payload = '$accountId|$providerTxnId';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  final normalized =
      description.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final payload =
      '$accountId|${date.toIso8601String().split('T').first}|$amountPence|$normalized|$ordinal';
  return sha256.convert(utf8.encode(payload)).toString();
}

Map<ParsedTransaction, int> computeOrdinalMap(List<ParsedTransaction> txs) {
  final counts = <String, int>{};
  final ordinals = <ParsedTransaction, int>{};

  for (final tx in txs) {
    if (tx.providerTxnId != null && tx.providerTxnId!.isNotEmpty) continue;
    final normalized =
        tx.description.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    final key =
        '${tx.date.toIso8601String().split('T').first}|${tx.amountPence}|$normalized';
    final ordinal = counts[key] ?? 0;
    counts[key] = ordinal + 1;
    ordinals[tx] = ordinal;
  }

  return ordinals;
}
