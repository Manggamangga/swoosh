import 'dart:typed_data';

import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_adapter.dart';

class WiseActivityCsvAdapter implements StatementAdapter {
  static const _requiredColumns = [
    'id',
    'direction',
    'created on',
    'source amount (after fees)',
    'source currency',
    'target amount (after fees)',
    'target currency',
  ];

  static bool matchesHeader(List<String> header) {
    return _requiredColumns.every(header.contains);
  }

  static String? extractProviderTxnId(String rawId) {
    final cleaned = rawId.replaceAll('"', '').trim();
    final match = RegExp(r'-(\d+)$').firstMatch(cleaned);
    return match?.group(1);
  }

  static bool _isOwnTopUp({
    required String direction,
    required String category,
    required String sourceName,
    required String targetName,
  }) {
    if (direction != 'IN') return false;
    final cat = category.toLowerCase();
    if (cat == 'money added') return true;
    if (sourceName.toLowerCase() == targetName.toLowerCase() &&
        sourceName.isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  Future<ParsedStatement> parse(Uint8List bytes, String filename) async {
    final rows = parseCsvRows(bytes);
    if (rows.isEmpty) {
      return const ParsedStatement(institution: 'Wise', transactions: []);
    }

    final dataStartIndex = rows.indexWhere((row) {
      final header = normalizeHeader(row);
      return matchesHeader(header);
    });
    if (dataStartIndex == -1) {
      return const ParsedStatement(institution: 'Wise', transactions: []);
    }

    final header = normalizeHeader(rows[dataStartIndex]);
    final idIdx = findColumn(header, ['id']);
    final directionIdx = findColumn(header, ['direction']);
    final createdIdx = findColumn(header, ['created on']);
    final sourceNameIdx = findColumn(header, ['source name']);
    final sourceAmountIdx = findColumn(header, ['source amount (after fees)']);
    final sourceCurrencyIdx = findColumn(header, ['source currency']);
    final targetNameIdx = findColumn(header, ['target name']);
    final targetAmountIdx = findColumn(header, ['target amount (after fees)']);
    final targetCurrencyIdx = findColumn(header, ['target currency']);
    final exchangeRateIdx = findColumn(header, ['exchange rate']);
    final referenceIdx = findColumn(header, ['reference']);
    final categoryIdx = findColumn(header, ['category']);
    final noteIdx = findColumn(header, ['note']);

    final transactions = <ParsedTransaction>[];

    for (var i = dataStartIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final rawId = row[idIdx].toString().trim();
      final direction = row[directionIdx].toString().trim().toUpperCase();
      if (direction == 'NEUTRAL') continue;

      final date = parseFlexibleDate(row[createdIdx].toString());
      if (date == null) continue;

      final sourceName = sourceNameIdx != -1
          ? row[sourceNameIdx].toString().trim()
          : '';
      final targetName = targetNameIdx != -1
          ? row[targetNameIdx].toString().trim()
          : '';
      final category =
          categoryIdx != -1 ? row[categoryIdx].toString().trim() : '';
      final reference =
          referenceIdx != -1 ? row[referenceIdx].toString().trim() : '';
      final note = noteIdx != -1 ? row[noteIdx].toString().trim() : '';

      final isIncoming = direction == 'IN';
      final amountIdx = isIncoming ? targetAmountIdx : sourceAmountIdx;
      final currencyIdx = isIncoming ? targetCurrencyIdx : sourceCurrencyIdx;
      final counterparty = isIncoming ? sourceName : targetName;

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

      final signedAmount = isIncoming ? rawAmountPence : -rawAmountPence;

      var description = note.isNotEmpty
          ? note
          : reference.isNotEmpty
              ? '$counterparty — $reference'
              : counterparty;
      if (description.isEmpty && category.isNotEmpty) {
        description = category;
      }
      if (description.isEmpty) {
        description = rawId;
      }

      var excludeFromAnalytics = false;
      var amountPence = signedAmount;
      var txCurrency = currency;

      if (currency != 'GBP') {
        final exchangeRate = exchangeRateIdx != -1
            ? Money.parseExchangeRate(row[exchangeRateIdx].toString())
            : null;
        final sourceCurrency = sourceCurrencyIdx != -1
            ? row[sourceCurrencyIdx].toString().trim().toUpperCase()
            : '';
        final targetCurrency = targetCurrencyIdx != -1
            ? row[targetCurrencyIdx].toString().trim().toUpperCase()
            : '';

        if (sourceCurrency == 'GBP' || targetCurrency == 'GBP') {
          amountPence = Money.convertForeignToGbpPence(
            foreignAmountPence: signedAmount,
            currency: currency,
            exchangeFrom: sourceCurrency.isEmpty ? currency : sourceCurrency,
            exchangeTo: targetCurrency.isEmpty ? 'GBP' : targetCurrency,
            exchangeRate: exchangeRate,
          );
          txCurrency = 'GBP';
          if (amountPence != signedAmount) {
            description =
                '$description [${Money.format(signedAmount.abs(), currency: currency)} → GBP]';
          }
        } else {
          description = '$description [$currency]';
          excludeFromAnalytics = true;
        }
      }

      if (_isOwnTopUp(
        direction: direction,
        category: category,
        sourceName: sourceName,
        targetName: targetName,
      )) {
        excludeFromAnalytics = true;
      }

      transactions.add(
        ParsedTransaction(
          date: date,
          amountPence: amountPence,
          description: description,
          merchant: counterparty.isNotEmpty ? counterparty : description,
          excludeFromAnalytics: excludeFromAnalytics,
          providerTxnId: extractProviderTxnId(rawId),
          currency: txCurrency,
          metadata: {
            'wise_id': rawId,
            'direction': direction,
            if (category.isNotEmpty) 'category': category,
          },
        ),
      );
    }

    return ParsedStatement(
      institution: 'Wise',
      transactions: transactions,
      currency: 'GBP',
    );
  }
}
