import 'package:csv/csv.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/data/csv_statement_parse_result.dart';
import 'package:swoosh/models/account.dart';

class CsvImportService {
  CsvStatementParseResult parseStatement({
    required String accountId,
    required String csvContent,
    String? fileName,
  }) {
    final normalized = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    if (rows.isEmpty) {
      return const CsvStatementParseResult(rows: []);
    }

    final institution = _inferInstitution(csvContent, fileName);
    final dataStartIndex = _dataStartIndex(rows);
    if (dataStartIndex >= rows.length) {
      return CsvStatementParseResult(rows: const [], institution: institution);
    }

    final header = rows[dataStartIndex]
        .map((e) => e.toString().toLowerCase().trim())
        .toList();
    final dateIdx = _findColumn(header, ['date', 'transaction date', 'posted date']);
    final descIdx = _findColumn(header, ['description', 'memo', 'details', 'narrative']);
    final amountIdx = _findColumn(header, ['amount', 'value']);
    final debitIdx = _findColumn(header, ['debit', 'money out']);
    final creditIdx = _findColumn(header, ['credit', 'money in']);
    final balanceIdx = _findColumn(header, [
      'balance',
      'running balance',
      'available balance',
      'closing balance',
    ]);

    if (dateIdx == -1 || descIdx == -1) {
      return CsvStatementParseResult(rows: const [], institution: institution);
    }

    final results = <Map<String, dynamic>>[];
    DateTime? latestDate;
    int? closingBalancePence;

    for (var i = dataStartIndex + 1; i < rows.length; i++) {
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

      if (balanceIdx != -1) {
        final balancePence = Money.parseToPence(row[balanceIdx].toString());
        if (latestDate == null || !date.isBefore(latestDate)) {
          latestDate = date;
          closingBalancePence = balancePence;
        }
      }
    }

    return CsvStatementParseResult(
      rows: results,
      institution: institution,
      closingBalancePence: closingBalancePence,
    );
  }

  List<Map<String, dynamic>> parse({
    required String accountId,
    required String csvContent,
  }) {
    return parseStatement(accountId: accountId, csvContent: csvContent).rows;
  }

  String? _inferInstitution(String csvContent, String? fileName) {
    final haystack = '${fileName ?? ''}\n$csvContent'.toLowerCase();
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

  int _dataStartIndex(List<List<dynamic>> rows) {
    for (var i = 0; i < rows.length; i++) {
      final header = rows[i].map((e) => e.toString().toLowerCase().trim()).toList();
      final dateIdx = _findColumn(header, ['date', 'transaction date', 'posted date']);
      final descIdx = _findColumn(header, ['description', 'memo', 'details', 'narrative']);
      if (dateIdx != -1 && descIdx != -1) return i;
    }
    return 0;
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
