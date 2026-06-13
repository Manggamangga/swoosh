import 'dart:typed_data';

import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_adapter.dart';
import 'package:swoosh/models/account.dart';

class AmexCsvAdapter implements StatementAdapter {
  static const _requiredColumns = ['date', 'description', 'amount'];

  static bool matchesHeader(List<String> header) {
    if (!_requiredColumns.every(header.contains)) return false;
    if (header.contains('account')) return false;
    return true;
  }

  static bool isPaymentReceived(String description) {
    return description.toUpperCase().contains('PAYMENT RECEIVED');
  }

  @override
  Future<ParsedStatement> parse(Uint8List bytes, String filename) async {
    final rows = parseCsvRows(bytes);
    if (rows.isEmpty) {
      return const ParsedStatement(
        institution: 'Amex',
        accountType: AccountType.credit,
        transactions: [],
      );
    }

    final dataStartIndex = findDataStartIndex(rows);
    if (dataStartIndex >= rows.length) {
      return const ParsedStatement(
        institution: 'Amex',
        accountType: AccountType.credit,
        transactions: [],
      );
    }

    final header = normalizeHeader(rows[dataStartIndex]);
    final dateIdx = findColumn(header, ['date']);
    final descIdx = findColumn(header, ['description']);
    final amountIdx = findColumn(header, ['amount']);

    final transactions = <ParsedTransaction>[];

    for (var i = dataStartIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final date = parseFlexibleDate(row[dateIdx].toString());
      if (date == null) continue;

      final description = row[descIdx].toString().trim();
      if (description.isEmpty) continue;

      final rawPence = parseAmountPence(
        row: row,
        amountIdx: amountIdx,
        debitIdx: -1,
        creditIdx: -1,
      );
      if (rawPence == 0) continue;

      final amountPence = -rawPence;

      transactions.add(
        ParsedTransaction(
          date: date,
          amountPence: amountPence,
          description: description,
          merchant: description,
          excludeFromAnalytics: isPaymentReceived(description),
        ),
      );
    }

    return ParsedStatement(
      institution: 'Amex',
      accountType: AccountType.credit,
      transactions: transactions,
      currency: 'GBP',
    );
  }
}
