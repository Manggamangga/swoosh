import 'package:swoosh/core/utils/analytics.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/transaction.dart';

class MonthlySummaryResult {
  const MonthlySummaryResult({
    required this.incomePence,
    required this.spendingPence,
  });

  final int incomePence;
  final int spendingPence;

  int get netPence => incomePence - spendingPence;
}

class AnalyticsService {
  int computeNetWorth(List<Account> accounts) {
    return accounts.fold<int>(0, (sum, account) {
      return switch (account.accountType) {
        AccountType.credit => sum - account.balancePence.abs(),
        AccountType.everyday || AccountType.savings => sum + account.balancePence,
      };
    });
  }

  MonthlySummaryResult computeMonthlySummary(
    List<Transaction> transactions,
    List<Account> accounts,
  ) {
    final everydayIds = everydayAccountIds(accounts);
    final filtered = everydayTransactions(transactions, everydayIds);

    return MonthlySummaryResult(
      incomePence: sumIncome(filtered),
      spendingPence: sumSpending(filtered),
    );
  }
}
