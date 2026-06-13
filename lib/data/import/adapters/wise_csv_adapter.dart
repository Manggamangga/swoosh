import 'dart:typed_data';

import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/data/import/adapters/wise_activity_csv_adapter.dart';
import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_adapter.dart';

class WiseCsvAdapter implements StatementAdapter {
  static const _requiredColumns = [
    'transferwise id',
    'date',
    'amount',
    'currency',
    'description',
    'running balance',
    'transaction details type',
  ];

  static bool matchesHeader(List<String> header) {
    return _requiredColumns.every(header.contains);
  }

  @override
  Future<ParsedStatement> parse(Uint8List bytes, String filename) async {
    final rows = parseCsvRows(bytes);
    if (rows.isEmpty) {
      return const ParsedStatement(
        institution: 'Wise',
        transactions: [],
      );
    }

    final dataStartIndex = findDataStartIndex(rows);
    if (dataStartIndex >= rows.length) {
      return const ParsedStatement(
        institution: 'Wise',
        transactions: [],
      );
    }

    final header = normalizeHeader(rows[dataStartIndex]);
    final dateIdx = findColumn(header, ['date']);
    final amountIdx = findColumn(header, ['amount']);
    final currencyIdx = findColumn(header, ['currency']);
    final descIdx = findColumn(header, ['description']);
    final balanceIdx = findColumn(header, ['running balance']);
    final exchangeFromIdx = findColumn(header, ['exchange from']);
    final exchangeToIdx = findColumn(header, ['exchange to']);
    final exchangeRateIdx = findColumn(header, ['exchange rate']);
    final transactionTypeIdx = findColumn(header, ['transaction type']);
    final detailsTypeIdx = findColumn(header, ['transaction details type']);
    final transferwiseIdIdx = findColumn(header, ['transferwise id']);

    final transactions = <ParsedTransaction>[];

    for (var i = dataStartIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final date = parseFlexibleDate(row[dateIdx].toString());
      if (date == null) continue;

      final rawDescription = row[descIdx].toString().trim();
      if (rawDescription.isEmpty) continue;

      final currency = currencyIdx != -1
          ? row[currencyIdx].toString().trim().toUpperCase()
          : 'GBP';
      final rawAmountPence = parseAmountPence(
        row: row,
        amountIdx: amountIdx,
        debitIdx: -1,
        creditIdx: -1,
      );
      if (rawAmountPence == 0) continue;

      final exchangeFrom = exchangeFromIdx != -1
          ? row[exchangeFromIdx].toString().trim().toUpperCase()
          : '';
      final exchangeTo = exchangeToIdx != -1
          ? row[exchangeToIdx].toString().trim().toUpperCase()
          : '';
      final exchangeRate = exchangeRateIdx != -1
          ? Money.parseExchangeRate(row[exchangeRateIdx].toString())
          : null;

      final amountPence = Money.convertForeignToGbpPence(
        foreignAmountPence: rawAmountPence,
        currency: currency,
        exchangeFrom: exchangeFrom.isEmpty ? currency : exchangeFrom,
        exchangeTo: exchangeTo.isEmpty ? 'GBP' : exchangeTo,
        exchangeRate: exchangeRate,
      );

      var description = rawDescription;
      if (currency != 'GBP' && amountPence != rawAmountPence) {
        description =
            '$rawDescription [${Money.format(rawAmountPence.abs(), currency: currency)} → GBP]';
      } else if (currency != 'GBP') {
        description = '$rawDescription [$currency]';
      }

      final transactionType = transactionTypeIdx != -1
          ? row[transactionTypeIdx].toString().trim()
          : '';
      final detailsType = detailsTypeIdx != -1
          ? row[detailsTypeIdx].toString().trim()
          : '';
      final transferwiseId = transferwiseIdIdx != -1
          ? row[transferwiseIdIdx].toString().trim()
          : '';

      transactions.add(
        ParsedTransaction(
          date: date,
          amountPence: amountPence,
          description: description,
          merchant: rawDescription,
          providerTxnId: transferwiseId.isNotEmpty
              ? WiseActivityCsvAdapter.extractProviderTxnId(transferwiseId)
              : null,
          metadata: {
            if (transactionType.isNotEmpty)
              'transaction_type': transactionType,
            if (detailsType.isNotEmpty)
              'transaction_details_type': detailsType,
            if (transferwiseId.isNotEmpty) 'transferwise_id': transferwiseId,
            if (currency.isNotEmpty) 'currency': currency,
            if (exchangeRate != null) 'exchange_rate': exchangeRate.toString(),
          },
        ),
      );
    }

    final closingBalancePence = parseClosingBalancePence(
      rows: rows,
      dataStartIndex: dataStartIndex,
      header: header,
      balanceIdx: balanceIdx,
    );

    return ParsedStatement(
      institution: 'Wise',
      transactions: transactions,
      closingBalancePence: closingBalancePence,
      currency: 'GBP',
    );
  }
}
