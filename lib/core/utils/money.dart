import 'package:intl/intl.dart';

abstract final class Money {
  static final _gbp = NumberFormat.currency(locale: 'en_GB', symbol: '£');

  static String format(int pence, {String currency = 'GBP'}) {
    if (currency != 'GBP') {
      return NumberFormat.currency(
        locale: 'en_GB',
        symbol: currency,
      ).format(pence / 100);
    }
    return _gbp.format(pence / 100);
  }

  static String formatSigned(int pence, {String currency = 'GBP'}) {
    final prefix = pence >= 0 ? '+' : '';
    return '$prefix${format(pence, currency: currency)}';
  }

  static int parseToPence(String input) {
    final cleaned = input.replaceAll(RegExp(r'[£,\s]'), '');
    final value = double.tryParse(cleaned) ?? 0;
    return (value * 100).round();
  }

  static double? parseExchangeRate(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned.replaceAll(',', ''));
  }

  static int convertForeignToGbpPence({
    required int foreignAmountPence,
    required String currency,
    required String exchangeFrom,
    required String exchangeTo,
    required double? exchangeRate,
  }) {
    if (currency == 'GBP' || foreignAmountPence == 0) {
      return foreignAmountPence;
    }

    final rate = exchangeRate;
    if (rate == null || rate <= 0) {
      return foreignAmountPence;
    }

    if (exchangeTo == 'GBP' || (exchangeTo.isEmpty && currency != 'GBP')) {
      return (foreignAmountPence * rate).round();
    }

    if (exchangeFrom == 'GBP' && exchangeTo.isNotEmpty) {
      return (foreignAmountPence / rate).round();
    }

    return foreignAmountPence;
  }
}
