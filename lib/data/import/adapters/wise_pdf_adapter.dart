import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_adapter.dart';

class WisePdfAdapter implements StatementAdapter {
  WisePdfAdapter({String Function(Uint8List bytes)? textExtractor})
      : _textExtractor = textExtractor ?? _defaultExtractText;

  final String Function(Uint8List bytes) _textExtractor;

  static final _accountNumberPattern = RegExp(
    r'account\s*number\s*(\d+)',
    caseSensitive: false,
  );
  static final _dateOnlyPattern = RegExp(
    r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$',
  );
  static final _transactionLinePattern = RegExp(
    r'^Transaction:\s+(\S+)$',
    caseSensitive: false,
  );
  static final _referenceLinePattern = RegExp(
    r'^Reference:\s*(.+)$',
    caseSensitive: false,
  );
  static final _amountOnlyPattern = RegExp(r'^(-?[\d,]+\.\d{2})$');

  static const _monthNames = {
    'january': 1,
    'february': 2,
    'march': 3,
    'april': 4,
    'may': 5,
    'june': 6,
    'july': 7,
    'august': 8,
    'september': 9,
    'october': 10,
    'november': 11,
    'december': 12,
  };

  String extractText(Uint8List bytes) => _textExtractor(bytes);

  static bool matchesContent(String text) {
    final lower = text.toLowerCase();
    return lower.contains('wise') &&
        (lower.contains('statement') ||
            lower.contains('iban') ||
            lower.contains('trwi'));
  }

  static String? extractProviderTxnId(String txnRef) {
    final match = RegExp(r'-(\d+)$').firstMatch(txnRef.trim());
    return match?.group(1);
  }

  @override
  Future<ParsedStatement> parse(Uint8List bytes, String filename) async {
    return parseText(extractText(bytes));
  }

  ParsedStatement parseText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final accountIdentifier = _extractAccountIdentifier(normalized);
    final closingBalancePence = _extractClosingBalancePence(normalized);
    final transactions = _parseTransactions(normalized);

    return ParsedStatement(
      institution: 'Wise',
      accountIdentifier: accountIdentifier,
      transactions: transactions,
      closingBalancePence: closingBalancePence,
      currency: 'GBP',
    );
  }

  static String _defaultExtractText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  String? _extractAccountIdentifier(String text) {
    final match = _accountNumberPattern.firstMatch(text);
    if (match == null) return null;
    return normalizeAccountIdentifier(match.group(1)!);
  }

  int? _extractClosingBalancePence(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    for (var i = 0; i < lines.length - 1; i++) {
      if (lines[i].toLowerCase().startsWith('gbp on ') &&
          RegExp(r'^[\d,]+\.\d{2}\s+GBP$', caseSensitive: false)
              .hasMatch(lines[i + 1])) {
        return Money.parseToPence(lines[i + 1].split(' ').first);
      }
    }
    return null;
  }

  List<ParsedTransaction> _parseTransactions(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final transactions = <ParsedTransaction>[];
    String? pendingDescription;
    DateTime? pendingDate;
    String? pendingTxnRef;
    String? pendingReference;
    int? pendingAmountPence;

    void emitTransaction() {
      if (pendingDate == null ||
          pendingAmountPence == null ||
          pendingAmountPence == 0) {
        return;
      }

      var description = pendingDescription ?? pendingTxnRef ?? 'Wise transaction';
      if (pendingReference != null && pendingReference!.isNotEmpty) {
        description = '$description — $pendingReference';
      }

      transactions.add(
        ParsedTransaction(
          date: pendingDate!,
          amountPence: pendingAmountPence!,
          description: description,
          merchant: description,
          providerTxnId: pendingTxnRef != null
              ? extractProviderTxnId(pendingTxnRef!)
              : null,
          currency: 'GBP',
          metadata: {
            if (pendingTxnRef != null) 'wise_txn_ref': pendingTxnRef!,
          },
        ),
      );

      pendingDescription = null;
      pendingDate = null;
      pendingTxnRef = null;
      pendingReference = null;
      pendingAmountPence = null;
    }

    for (final line in lines) {
      final lower = line.toLowerCase();

      if (lower.startsWith('description incoming') ||
          lower.contains('wise payments') ||
          lower.startsWith('ref:') ||
          lower == 'incoming' ||
          lower == 'outgoing' ||
          lower == 'amount' ||
          lower.startsWith('asset') ||
          lower.startsWith('investment firm') ||
          lower.startsWith('fund manager') ||
          lower.startsWith('need help') ||
          RegExp(r'^\d+$').hasMatch(line) ||
          line == '/') {
        continue;
      }

      final dateMatch = _dateOnlyPattern.firstMatch(line);
      if (dateMatch != null) {
        pendingDate = _parseMonthDate(
          int.parse(dateMatch.group(1)!),
          dateMatch.group(2)!,
          int.parse(dateMatch.group(3)!),
        );
        continue;
      }

      final txnMatch = _transactionLinePattern.firstMatch(line);
      if (txnMatch != null) {
        pendingTxnRef = txnMatch.group(1);
        continue;
      }

      final refMatch = _referenceLinePattern.firstMatch(line);
      if (refMatch != null) {
        pendingReference = refMatch.group(1)?.trim();
        continue;
      }

      if (lower.contains('units ') ||
          lower.contains('asset 1') ||
          lower.startsWith('card ending in')) {
        continue;
      }

      final amountMatch = _amountOnlyPattern.firstMatch(line);
      if (amountMatch != null) {
        final amountPence = Money.parseToPence(amountMatch.group(1)!);
        if (pendingAmountPence == null) {
          pendingAmountPence = amountPence;
        } else {
          emitTransaction();
        }
        continue;
      }

      if (pendingDate == null &&
          !lower.startsWith('gbp on ') &&
          !lower.startsWith('generated on') &&
          !lower.startsWith('account ') &&
          !lower.startsWith('iban') &&
          !lower.startsWith('uk sort') &&
          !lower.startsWith('swift') &&
          !lower.startsWith('returns since') &&
          !lower.contains('tax return') &&
          line != 'Sean Kit' &&
          line != 'Sean Loh') {
        pendingDescription = line;
      }
    }

    return transactions;
  }

  DateTime _parseMonthDate(int day, String monthName, int year) {
    final monthKey = monthName.toLowerCase();
    final month = _monthNames[monthKey] ??
        _monthNames[monthKey.substring(0, 3)] ??
        1;
    return DateTime(year, month, day);
  }
}
