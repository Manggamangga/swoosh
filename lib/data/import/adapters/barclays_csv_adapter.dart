import 'dart:typed_data';

import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_adapter.dart';

class BarclaysCsvAdapter implements StatementAdapter {
  static const _requiredColumns = [
    'number',
    'date',
    'account',
    'amount',
    'memo',
  ];

  static bool matchesHeader(List<String> header) {
    return _requiredColumns.every(header.contains);
  }

  @override
  Future<ParsedStatement> parse(Uint8List bytes, String filename) async {
    final rows = parseCsvRows(bytes);
    if (rows.isEmpty) {
      return const ParsedStatement(
        institution: 'Barclays',
        transactions: [],
      );
    }

    final dataStartIndex = findDataStartIndex(rows);
    if (dataStartIndex >= rows.length) {
      return const ParsedStatement(
        institution: 'Barclays',
        transactions: [],
      );
    }

    final header = normalizeHeader(rows[dataStartIndex]);
    final dateIdx = findColumn(header, ['date']);
    final accountIdx = findColumn(header, ['account']);
    final amountIdx = findColumn(header, ['amount']);
    final memoIdx = findColumn(header, ['memo']);
    final subcategoryIdx = findColumn(header, ['subcategory']);

    String? accountIdentifier;
    final transactions = <ParsedTransaction>[];

    for (var i = dataStartIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final dateStr = row[dateIdx].toString();
      final date = parseFlexibleDate(dateStr);
      if (date == null) continue;

      final amountPence = parseAmountPence(
        row: row,
        amountIdx: amountIdx,
        debitIdx: -1,
        creditIdx: -1,
      );
      if (amountPence == 0) continue;

      final description = memoIdx != -1 ? row[memoIdx].toString().trim() : '';
      if (description.isEmpty) continue;

      if (accountIdx != -1 && accountIdentifier == null) {
        final rawAccount = row[accountIdx].toString().trim();
        if (rawAccount.isNotEmpty) {
          accountIdentifier = normalizeAccountIdentifier(rawAccount);
        }
      }

      final subcategory =
          subcategoryIdx != -1 ? row[subcategoryIdx].toString().trim() : null;

      transactions.add(
        ParsedTransaction(
          date: date,
          amountPence: amountPence,
          description: description,
          merchant: subcategory?.isNotEmpty == true ? subcategory : description,
          subcategory: subcategory,
        ),
      );
    }

    return ParsedStatement(
      institution: 'Barclays',
      accountIdentifier: accountIdentifier,
      transactions: transactions,
      currency: 'GBP',
    );
  }
}
