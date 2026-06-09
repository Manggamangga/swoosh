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
}
