import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:swoosh/core/utils/money.dart';

List<List<dynamic>> parseCsvRows(Uint8List bytes) {
  final content = String.fromCharCodes(bytes)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  return const CsvToListConverter(eol: '\n').convert(content);
}

int findDataStartIndex(List<List<dynamic>> rows) {
  for (var i = 0; i < rows.length; i++) {
    final header = normalizeHeader(rows[i]);
    final dateIdx = findColumn(header, ['date', 'transaction date', 'posted date']);
    final descIdx = findColumn(header, [
      'description',
      'memo',
      'details',
      'narrative',
    ]);
    if (dateIdx != -1 && descIdx != -1) return i;
  }
  return 0;
}

List<String> normalizeHeader(List<dynamic> row) {
  return row.map((cell) => cell.toString().toLowerCase().trim()).toList();
}

int findColumn(List<String> header, List<String> candidates) {
  for (final candidate in candidates) {
    final idx = header.indexOf(candidate);
    if (idx != -1) return idx;
  }
  return -1;
}

DateTime? parseFlexibleDate(String input) {
  final trimmed = input.trim();
  final formats = [
    RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
    RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
    RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'),
  ];

  for (final format in formats) {
    final match = format.firstMatch(trimmed);
    if (match == null) continue;
    if (format == formats[0]) {
      return DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
    }
    if (format == formats[1]) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
    if (format == formats[2]) {
      return DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
    }
  }
  return DateTime.tryParse(trimmed);
}

int parseAmountPence({
  required List<dynamic> row,
  required int amountIdx,
  required int debitIdx,
  required int creditIdx,
}) {
  if (amountIdx != -1) {
    return Money.parseToPence(row[amountIdx].toString());
  }

  final debit = debitIdx != -1 ? Money.parseToPence(row[debitIdx].toString()) : 0;
  final credit = creditIdx != -1 ? Money.parseToPence(row[creditIdx].toString()) : 0;
  return credit > 0 ? credit : -debit;
}

int? parseClosingBalancePence({
  required List<List<dynamic>> rows,
  required int dataStartIndex,
  required List<String> header,
  required int balanceIdx,
}) {
  if (balanceIdx == -1) return null;

  DateTime? latestDate;
  int? closingBalancePence;

  for (var i = dataStartIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.isEmpty) continue;

    final dateIdx = findColumn(header, ['date', 'transaction date', 'posted date']);
    if (dateIdx == -1 || dateIdx >= row.length) continue;

    final date = parseFlexibleDate(row[dateIdx].toString());
    if (date == null || balanceIdx >= row.length) continue;

    final balancePence = Money.parseToPence(row[balanceIdx].toString());
    if (latestDate == null || !date.isBefore(latestDate)) {
      latestDate = date;
      closingBalancePence = balancePence;
    }
  }

  return closingBalancePence;
}

String normalizeAccountIdentifier(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String? inferInstitutionFromContent(String content, String filename) {
  final haystack = '$filename\n$content'.toLowerCase();
  const patterns = {
    'Barclays': ['barclays'],
    'Amex': ['amex', 'american express'],
    'Wise': ['wise', 'transferwise'],
    'Moneybox': ['moneybox'],
    'HSBC': ['hsbc'],
  };

  for (final entry in patterns.entries) {
    if (entry.value.any(haystack.contains)) {
      return entry.key;
    }
  }
  return null;
}
