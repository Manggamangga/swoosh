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

    test('formatSigned includes plus for positive', () {
      expect(Money.formatSigned(50000), '+£500.00');
      expect(Money.formatSigned(-9400), '-£94.00');
    });
  });
}
