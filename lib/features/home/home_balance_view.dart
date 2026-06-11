import 'package:swoosh/models/account.dart';

enum HomeBalanceView { everyday, savings, netWorth }

List<Account> accountsForView(List<Account> accounts, HomeBalanceView view) {
  switch (view) {
    case HomeBalanceView.everyday:
      return accounts
          .where((account) => account.accountType == AccountType.everyday)
          .toList();
    case HomeBalanceView.savings:
      return accounts
          .where((account) => account.accountType == AccountType.savings)
          .toList();
    case HomeBalanceView.netWorth:
      return accounts;
  }
}

String labelForHomeBalanceView(HomeBalanceView view) {
  switch (view) {
    case HomeBalanceView.everyday:
      return 'Everyday';
    case HomeBalanceView.savings:
      return 'Savings';
    case HomeBalanceView.netWorth:
      return 'Net worth';
  }
}
