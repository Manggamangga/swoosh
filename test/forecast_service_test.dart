import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/services/forecast_service.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/recurring_payment.dart';

void main() {
  test('forecast reduces balance with recurring expenses', () {
    final service = ForecastService();
    final accounts = [
      Account(
        id: '1',
        userId: 'u',
        name: 'Monzo',
        accountType: AccountType.everyday,
        balancePence: 100000,
        currency: 'GBP',
        source: DataSource.manual,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];
    final recurring = [
      RecurringPayment(
        id: 'r1',
        userId: 'u',
        name: 'Rent',
        amountPence: -50000,
        currency: 'GBP',
        cadence: RecurringCadence.monthly,
        nextDate: DateTime.now().add(const Duration(days: 5)),
        autoDetected: false,
      ),
    ];

    final points = service.forecast(
      accounts: accounts,
      recurring: recurring,
      expectedIncome: const [],
      daysAhead: 30,
    );

    expect(points.length, greaterThan(1));
    final hasLower = points.any((p) => p.balancePence < 100000);
    expect(hasLower, isTrue);
  });
}
