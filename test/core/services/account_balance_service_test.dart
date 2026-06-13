import 'package:flutter_test/flutter_test.dart';
import 'package:swoosh/core/services/account_balance_service.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/transaction.dart';

void main() {
  group('AccountBalanceService', () {
    test('does not double-count transactions on anchor date', () {
      final service = AccountBalanceService();
      final account = Account(
        id: 'acc-1',
        userId: 'user-1',
        name: 'Test',
        accountType: AccountType.everyday,
        balancePence: 100000,
        currency: 'GBP',
        source: DataSource.csv,
        balanceAnchorPence: 100000,
        balanceAnchorDate: DateTime(2026, 6, 11),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 6, 11),
      );

      final transactions = [
        Transaction(
          id: 'tx-1',
          userId: 'user-1',
          accountId: 'acc-1',
          transactionDate: DateTime(2026, 6, 11),
          amountPence: -5000,
          currency: 'GBP',
          description: 'Spend on anchor day',
          source: DataSource.csv,
          dedupeHash: 'hash-1',
          excludeFromAnalytics: false,
          createdAt: DateTime(2026, 6, 11),
          updatedAt: DateTime(2026, 6, 11),
        ),
        Transaction(
          id: 'tx-2',
          userId: 'user-1',
          accountId: 'acc-1',
          transactionDate: DateTime(2026, 6, 12),
          amountPence: -1000,
          currency: 'GBP',
          description: 'Spend after anchor day',
          source: DataSource.csv,
          dedupeHash: 'hash-2',
          excludeFromAnalytics: false,
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
        ),
      ];

      expect(service.computeBalance(account, transactions), 99000);
    });
  });
}
