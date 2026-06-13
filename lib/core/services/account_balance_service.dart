import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/transaction.dart';

class AccountBalanceService {
  int computeBalance(Account account, List<Transaction> transactions) {
    final anchorPence = account.balanceAnchorPence ?? account.balancePence;
    final anchorDate = account.balanceAnchorDate ?? account.createdAt;
    final anchorDay = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
    );

    final txSum = transactions
        .where((transaction) => transaction.accountId == account.id)
        .where((transaction) {
          final txDay = DateTime(
            transaction.transactionDate.year,
            transaction.transactionDate.month,
            transaction.transactionDate.day,
          );
          return txDay.isAfter(anchorDay);
        })
        .fold<int>(0, (sum, transaction) => sum + transaction.amountPence);

    return anchorPence + txSum;
  }

  bool needsRecompute(Account account) =>
      account.source == DataSource.manual || account.source == DataSource.csv;
}
