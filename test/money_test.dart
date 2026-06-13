import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/utils/money.dart';

void main() {
  group('Money', () {
    test('format displays GBP correctly', () {
      expect(Money.format(701049), '£7,010.49');
    });

    test('parseToPence converts pounds to pence', () {
      expect(Money.parseToPence('12.50'), 1250);
      expect(Money.parseToPence('£1,234.56'), 123456);
    });

    test('parseExchangeRate parses decimal rates', () {
      expect(Money.parseExchangeRate('0.79'), 0.79);
      expect(Money.parseExchangeRate('1.27'), 1.27);
      expect(Money.parseExchangeRate(''), isNull);
    });

    test('convertForeignToGbpPence converts using rate to GBP', () {
      expect(
        Money.convertForeignToGbpPence(
          foreignAmountPence: -2550,
          currency: 'USD',
          exchangeFrom: 'USD',
          exchangeTo: 'GBP',
          exchangeRate: 0.79,
        ),
        -2015,
      );
    });

    test('convertForeignToGbpPence keeps GBP amounts unchanged', () {
      expect(
        Money.convertForeignToGbpPence(
          foreignAmountPence: -4599,
          currency: 'GBP',
          exchangeFrom: 'GBP',
          exchangeTo: 'GBP',
          exchangeRate: null,
        ),
        -4599,
      );
    });
  });
}
