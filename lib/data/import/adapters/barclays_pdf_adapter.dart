import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/data/import/csv_parse_utils.dart';
import 'package:swoosh/data/import/parsed_statement.dart';
import 'package:swoosh/data/import/statement_adapter.dart';

class BarclaysPdfAdapter implements StatementAdapter {
  BarclaysPdfAdapter({String Function(Uint8List bytes)? textExtractor})
      : _textExtractor = textExtractor ?? _defaultExtractText;

  final String Function(Uint8List bytes) _textExtractor;

  static bool isPdfFile(String filename, Uint8List bytes) {
    if (filename.toLowerCase().endsWith('.pdf')) return true;
    return bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  String extractText(Uint8List bytes) => _textExtractor(bytes);
  static final _sortCodePattern = RegExp(
    r'sort\s*code\s*([\d-]+)\s*(?:account\s*(?:no\.?|number)\s*)?(\d+)',
    caseSensitive: false,
  );
  static final _startBalancePattern = RegExp(
    r'start\s*balance\s*[£]?\s*([\d,]+\.\d{2})',
    caseSensitive: false,
  );
  static final _endBalancePattern = RegExp(
    r'end\s*balance\s*[£]?\s*([\d,]+\.\d{2})',
    caseSensitive: false,
  );
  static final _statementPeriodPattern = RegExp(
    r'statement\s*period\s*.+?(\d{4})',
    caseSensitive: false,
  );
  static final _shortDatePattern = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\b');
  static final _slashDatePattern = RegExp(r'^(\d{2})/(\d{2})/(\d{4})');
  static final _amountPattern = RegExp(r'([\d,]+\.\d{2})');
  static final _refLinePattern = RegExp(r'^ref:\s*', caseSensitive: false);

  static const _monthNames = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static bool matchesContent(String text) {
    final lower = text.toLowerCase();
    return lower.contains('barclays') &&
        (lower.contains('money out') ||
            lower.contains('sort code') ||
            lower.contains('statement period'));
  }

  @override
  Future<ParsedStatement> parse(Uint8List bytes, String filename) async {
    return parseText(extractText(bytes));
  }

  ParsedStatement parseText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final accountIdentifier = _extractAccountIdentifier(normalized);
    final closingBalancePence = _extractEndBalancePence(normalized);
    final startBalancePence = _extractStartBalancePence(normalized);
    final statementYear = _extractStatementYear(normalized);
    final transactions = _parseTransactions(
      normalized,
      statementYear,
      startBalancePence: startBalancePence,
    );

    return ParsedStatement(
      institution: 'Barclays',
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
    final match = _sortCodePattern.firstMatch(text);
    if (match == null) return null;
    return normalizeAccountIdentifier('${match.group(1)} ${match.group(2)}');
  }

  int? _extractEndBalancePence(String text) {
    final match = _endBalancePattern.firstMatch(text);
    if (match == null) return null;
    return Money.parseToPence(match.group(1)!);
  }

  int? _extractStartBalancePence(String text) {
    final match = _startBalancePattern.firstMatch(text);
    if (match == null) return null;
    return Money.parseToPence(match.group(1)!);
  }

  int _extractStatementYear(String text) {
    final match = _statementPeriodPattern.firstMatch(text);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return DateTime.now().year;
  }

  List<ParsedTransaction> _parseTransactions(
    String text,
    int statementYear, {
    int? startBalancePence,
  }) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final startIndex = lines.indexWhere(
      (line) =>
          line.toLowerCase().contains('date') &&
          line.toLowerCase().contains('description') &&
          line.toLowerCase().contains('money'),
    );
    if (startIndex == -1) return const [];

    final transactions = <ParsedTransaction>[];
    var index = startIndex + 1;
    String? pendingDescription;
    DateTime? pendingDate;
    int? pendingAmountPence;
    int? previousBalancePence = startBalancePence;

    while (index < lines.length) {
      final line = lines[index];
      final date = _parseLeadingDate(line, statementYear);

      if (date != null) {
        if (pendingDate != null &&
            pendingAmountPence != null &&
            pendingDescription != null &&
            pendingDescription.isNotEmpty) {
          transactions.add(
            ParsedTransaction(
              date: pendingDate,
              amountPence: pendingAmountPence,
              description: pendingDescription,
              merchant: pendingDescription,
            ),
          );
        }

        final parsedLine = _parseTransactionLine(
          line,
          statementYear,
          previousBalancePence: previousBalancePence,
        );
        if (parsedLine != null) {
          pendingDate = parsedLine.date;
          pendingAmountPence = parsedLine.amountPence;
          pendingDescription = parsedLine.description;
          if (parsedLine.balancePence != null) {
            previousBalancePence = parsedLine.balancePence;
          }
        } else {
          pendingDate = null;
          pendingAmountPence = null;
          pendingDescription = null;
        }
      } else if (pendingDescription != null) {
        if (_refLinePattern.hasMatch(line)) {
          pendingDescription = '$pendingDescription ${line.trim()}';
        } else if (!_isMetadataLine(line)) {
          pendingDescription = '$pendingDescription ${line.trim()}';
        }
      }

      index++;
    }

    if (pendingDate != null &&
        pendingAmountPence != null &&
        pendingDescription != null &&
        pendingDescription.isNotEmpty) {
      transactions.add(
        ParsedTransaction(
          date: pendingDate,
          amountPence: pendingAmountPence,
          description: pendingDescription,
          merchant: pendingDescription,
        ),
      );
    }

    return transactions;
  }

  _ParsedLine? _parseTransactionLine(
    String line,
    int statementYear, {
    int? previousBalancePence,
  }) {
    final date = _parseLeadingDate(line, statementYear);
    if (date == null) return null;

    final remainder = line.substring(_leadingDateLength(line)).trim();
    if (remainder.isEmpty) return null;

    final amounts = _amountPattern
        .allMatches(remainder)
        .map((match) => Money.parseToPence(match.group(1)!))
        .toList();
    if (amounts.isEmpty) return null;

    final amountPence = _resolveAmountPence(
      amounts,
      previousBalancePence: previousBalancePence,
    );
    if (amountPence == 0) return null;

    final descriptionEnd = remainder.lastIndexOf(
      _amountPattern.firstMatch(remainder)!.group(0)!,
    );
    final description = remainder.substring(0, descriptionEnd).trim();
    if (description.isEmpty) return null;

    return _ParsedLine(
      date: date,
      amountPence: amountPence,
      description: description,
      balancePence: amounts.length >= 2 ? amounts.last : null,
    );
  }

  int _resolveAmountPence(
    List<int> amounts, {
    int? previousBalancePence,
  }) {
    if (amounts.length >= 2 && previousBalancePence != null) {
      return amounts.last - previousBalancePence;
    }

    if (amounts.length >= 3) {
      final moneyOut = amounts[amounts.length - 3];
      final moneyIn = amounts[amounts.length - 2];
      if (moneyIn > 0) return moneyIn;
      if (moneyOut > 0) return -moneyOut;
      return 0;
    }

    if (amounts.length == 2) {
      return amounts.first;
    }

    return amounts.single;
  }

  DateTime? _parseLeadingDate(String line, int statementYear) {
    final slashMatch = _slashDatePattern.firstMatch(line);
    if (slashMatch != null) {
      return DateTime(
        int.parse(slashMatch.group(3)!),
        int.parse(slashMatch.group(2)!),
        int.parse(slashMatch.group(1)!),
      );
    }

    final shortMatch = _shortDatePattern.firstMatch(line);
    if (shortMatch == null) return null;

    final month = _monthNames[shortMatch.group(2)!.toLowerCase().substring(0, 3)];
    if (month == null) return null;

    return DateTime(
      statementYear,
      month,
      int.parse(shortMatch.group(1)!),
    );
  }

  int _leadingDateLength(String line) {
    final slashMatch = _slashDatePattern.firstMatch(line);
    if (slashMatch != null) return slashMatch.end;

    final shortMatch = _shortDatePattern.firstMatch(line);
    if (shortMatch != null) return shortMatch.end;

    return 0;
  }

  bool _isMetadataLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('start balance') ||
        lower.contains('end balance') ||
        lower.contains('statement period') ||
        lower.contains('sort code') ||
        lower.startsWith('page ');
  }
}

class _ParsedLine {
  const _ParsedLine({
    required this.date,
    required this.amountPence,
    required this.description,
    this.balancePence,
  });

  final DateTime date;
  final int amountPence;
  final String description;
  final int? balancePence;
}
