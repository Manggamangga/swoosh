import 'dart:typed_data';

import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_adapter.dart';

class GenericCsvPreview {
  const GenericCsvPreview({
    required this.statement,
    required this.columnMapping,
    required this.totalDataRows,
    this.balanceFieldName,
    this.errorMessage,
  });

  final ParsedStatement statement;
  final Map<String, String?> columnMapping;
  final int totalDataRows;
  final String? balanceFieldName;
  final String? errorMessage;

  bool get hasRequiredColumns => errorMessage == null;
  List<ParsedTransaction> get sampleTransactions =>
      statement.transactions.take(3).toList();

  String get accountName {
    if (statement.accountIdentifier != null) {
      return '${statement.institution} · ${statement.accountIdentifier}';
    }
    return statement.institution;
  }
}

class GenericCsvAdapter implements StatementAdapter {
  @override
  Future<ParsedStatement> parse(Uint8List bytes, String filename) async {
    return preview(bytes, filename).statement;
  }

  GenericCsvPreview preview(Uint8List bytes, String filename) {
    final content = String.fromCharCodes(bytes);
    final rows = parseCsvRows(bytes);
    final institution =
        inferInstitutionFromContent(content, filename) ?? 'Unknown';

    if (rows.isEmpty) {
      return GenericCsvPreview(
        statement: ParsedStatement(
          institution: institution,
          transactions: const [],
        ),
        columnMapping: const {},
        totalDataRows: 0,
        errorMessage: 'Could not read any rows from this file.',
      );
    }

    final dataStartIndex = findDataStartIndex(rows);
    if (dataStartIndex >= rows.length) {
      return GenericCsvPreview(
        statement: ParsedStatement(
          institution: institution,
          transactions: const [],
        ),
        columnMapping: const {},
        totalDataRows: 0,
        errorMessage: 'Could not find a transaction table in this file.',
      );
    }

    final header = normalizeHeader(rows[dataStartIndex]);
    final rawHeader = rows[dataStartIndex].map((cell) => cell.toString()).toList();
    final dateIdx = findColumn(header, ['date', 'transaction date', 'posted date']);
    final descIdx = findColumn(header, [
      'description',
      'memo',
      'details',
      'narrative',
    ]);
    final amountIdx = findColumn(header, ['amount', 'value']);
    final debitIdx = findColumn(header, ['debit', 'money out']);
    final creditIdx = findColumn(header, ['credit', 'money in']);
    final balanceIdx = findColumn(header, [
      'balance',
      'running balance',
      'available balance',
      'closing balance',
    ]);

    final columnMapping = <String, String?>{
      'Date': dateIdx == -1 ? null : rawHeader[dateIdx],
      'Description': descIdx == -1 ? null : rawHeader[descIdx],
      if (amountIdx != -1) 'Amount': rawHeader[amountIdx],
      if (debitIdx != -1) 'Debit': rawHeader[debitIdx],
      if (creditIdx != -1) 'Credit': rawHeader[creditIdx],
      if (balanceIdx != -1) 'Balance': rawHeader[balanceIdx],
    };

    if (dateIdx == -1 || descIdx == -1) {
      return GenericCsvPreview(
        statement: ParsedStatement(
          institution: institution,
          transactions: const [],
        ),
        columnMapping: columnMapping,
        totalDataRows: rows.length - dataStartIndex - 1,
        balanceFieldName: balanceIdx == -1 ? null : rawHeader[balanceIdx],
        errorMessage:
            'Required columns not found. Need Date and Description columns.',
      );
    }

    if (amountIdx == -1 && debitIdx == -1 && creditIdx == -1) {
      return GenericCsvPreview(
        statement: ParsedStatement(
          institution: institution,
          transactions: const [],
        ),
        columnMapping: columnMapping,
        totalDataRows: rows.length - dataStartIndex - 1,
        balanceFieldName: balanceIdx == -1 ? null : rawHeader[balanceIdx],
        errorMessage:
            'Required amount columns not found. Need Amount or Debit/Credit.',
      );
    }

    final transactions = <ParsedTransaction>[];

    for (var i = dataStartIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final date = parseFlexibleDate(row[dateIdx].toString());
      if (date == null) continue;

      final description = row[descIdx].toString().trim();
      if (description.isEmpty) continue;

      final amountPence = parseAmountPence(
        row: row,
        amountIdx: amountIdx,
        debitIdx: debitIdx,
        creditIdx: creditIdx,
      );
      if (amountPence == 0) continue;

      transactions.add(
        ParsedTransaction(
          date: date,
          amountPence: amountPence,
          description: description,
          merchant: description,
        ),
      );
    }

    final closingBalancePence = parseClosingBalancePence(
      rows: rows,
      dataStartIndex: dataStartIndex,
      header: header,
      balanceIdx: balanceIdx,
    );

    return GenericCsvPreview(
      statement: ParsedStatement(
        institution: institution,
        transactions: transactions,
        closingBalancePence: closingBalancePence,
        currency: 'GBP',
      ),
      columnMapping: columnMapping,
      totalDataRows: rows.length - dataStartIndex - 1,
      balanceFieldName: balanceIdx == -1 ? null : rawHeader[balanceIdx],
    );
  }
}
