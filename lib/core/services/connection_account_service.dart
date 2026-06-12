import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/bank_connection.dart';

abstract final class ConnectionAccountService {
  static bool accountBelongsToConnection(Account account, BankConnection connection) {
    if (account.source != DataSource.openbanking) return false;
    if (connection.provider == 'monzo') {
      return account.institution == 'Monzo';
    }
    final institution = connection.institutionName;
    if (institution == null || institution.isEmpty) return false;
    return account.institution == institution;
  }

  static List<Account> accountsForConnection(
    BankConnection connection,
    List<Account> accounts,
  ) {
    return accounts
        .where((account) => accountBelongsToConnection(account, connection))
        .toList();
  }

  static BankConnection? connectionForAccount(
    Account account,
    List<BankConnection> connections,
  ) {
    for (final connection in connections) {
      if (accountBelongsToConnection(account, connection)) {
        return connection;
      }
    }
    return null;
  }

  static String connectionLabel(BankConnection connection) {
    if (connection.provider == 'monzo') return 'Monzo';
    return connection.institutionName ?? 'Bank';
  }
}
