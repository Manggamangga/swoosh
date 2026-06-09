import 'package:csv/csv.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/models/account.dart';

class CsvImportService {
  List<Map<String, dynamic>> parse({
    required String accountId,
    required String csvContent,
  }) {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) return [];

    final header = rows.first.map((e) => e.toString().toLowerCase()).toList();
    final dateIdx = _findColumn(header, ['date', 'transaction date', 'posted date']);
    final descIdx = _findColumn(header, ['description', 'memo', 'details', 'narrative']);
    final amountIdx = _findColumn(header, ['amount', 'value']);
    final debitIdx = _findColumn(header, ['debit', 'money out']);
    final creditIdx = _findColumn(header, ['credit', 'money in']);

    if (dateIdx == -1 || descIdx == -1) return [];

    final results = <Map<String, dynamic>>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final dateStr = row[dateIdx].toString();
      final description = row[descIdx].toString();
      final date = _parseDate(dateStr);
      if (date == null) continue;

      int amountPence;
      if (amountIdx != -1) {
        amountPence = Money.parseToPence(row[amountIdx].toString());
      } else {
        final debit = debitIdx != -1 ? Money.parseToPence(row[debitIdx].toString()) : 0;
        final credit = creditIdx != -1 ? Money.parseToPence(row[creditIdx].toString()) : 0;
        amountPence = credit > 0 ? credit : -debit;
      }

      if (amountPence == 0) continue;

      results.add({
        'account_id': accountId,
        'transaction_date': date.toIso8601String().split('T').first,
        'amount_pence': amountPence,
        'currency': 'GBP',
        'description': description,
        'merchant': description,
        'source': DataSource.csv.name,
        'dedupe_hash': buildDedupeHash(
          accountId: accountId,
          date: date,
          amountPence: amountPence,
          description: description,
        ),
        'exclude_from_analytics': false,
      });
    }

    return results;
  }

  int _findColumn(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = header.indexOf(candidate);
      if (idx != -1) return idx;
    }
    return -1;
  }

  DateTime? _parseDate(String input) {
    final formats = [
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
      RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'),
    ];

    for (final format in formats) {
      final match = format.firstMatch(input.trim());
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
    return DateTime.tryParse(input);
  }
}
