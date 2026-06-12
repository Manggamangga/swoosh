import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/services/connection_account_service.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/error_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/transaction_tile.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/bank_connection.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

final accountTransactionsProvider =
    FutureProvider.family<List<Transaction>, String>((ref, accountId) async {
  final repo = await ref.watch(transactionRepositoryProvider.future);
  return repo.fetchByAccount(accountId);
});

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  Future<void> _renameAccount(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename account'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Account name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    final repo = await ref.read(accountRepositoryProvider.future);
    await repo.update(widget.accountId, {'name': newName});
    ref.invalidate(accountsProvider);
  }

  Future<({BankConnection connection, bool deleteSynced})?>
      _collectDisconnectDecision(BankConnection connection) async {
    final label = ConnectionAccountService.connectionLabel(connection);
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Also disconnect $label?'),
        content: Text(
          'This was the last account synced from $label. '
          'Disconnecting removes the bank link so it no longer shows as active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (choice != true || !mounted) return null;

    final deleteSynced = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep synced data?'),
        content: const Text(
          'Choose whether to keep any remaining synced accounts as static history, '
          'or delete them along with the connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep accounts'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete synced accounts',
              style: TextStyle(color: AppColors.error.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );

    if (deleteSynced == null || !mounted) return null;
    return (connection: connection, deleteSynced: deleteSynced);
  }

  Future<void> _deleteAccount(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          'Delete ${account.name} and all its transactions? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    BankConnection? connectionToDisconnect;
    bool? deleteSyncedAccounts;
    if (account.source == DataSource.openbanking) {
      final connections = await ref.read(bankConnectionsProvider.future);
      final accounts = await ref.read(accountsProvider.future);
      final connection = ConnectionAccountService.connectionForAccount(
        account,
        connections,
      );
      if (connection != null) {
        final linked = ConnectionAccountService.accountsForConnection(
          connection,
          accounts,
        );
        if (linked.length == 1 && linked.first.id == account.id) {
          final decision = await _collectDisconnectDecision(connection);
          if (!mounted) return;
          if (decision != null) {
            connectionToDisconnect = decision.connection;
            deleteSyncedAccounts = decision.deleteSynced;
          }
        }
      }
    }

    final repo = await ref.read(accountRepositoryProvider.future);
    await repo.delete(widget.accountId);
    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(allTransactionsProvider);

    if (connectionToDisconnect != null && deleteSyncedAccounts != null) {
      final bankRepo = ref.read(bankConnectionRepositoryProvider);
      await bankRepo.disconnect(
        connectionId: connectionToDisconnect.id,
        deleteSyncedAccounts: deleteSyncedAccounts,
      );
      ref.invalidate(bankConnectionsProvider);
    }

    if (mounted) context.go('/accounts');
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(accountTransactionsProvider(widget.accountId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: 'Rename account',
            onPressed: () {
              final account = accountsAsync.valueOrNull
                  ?.where((item) => item.id == widget.accountId)
                  .firstOrNull;
              if (account != null) _renameAccount(account.name);
            },
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => context.push('/accounts/${widget.accountId}/import'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/accounts/${widget.accountId}/add-tx'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final account = accountsAsync.valueOrNull
                  ?.where((item) => item.id == widget.accountId)
                  .firstOrNull;
              if (account != null && value == 'delete') {
                _deleteAccount(account);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete account',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => ListView(
          padding: ViewInsets.listPadding(context),
          children: const [SkeletonCard()],
        ),
        error: (error, _) => ErrorState(message: error.toString()),
        data: (accounts) {
          final account = accounts
              .where((a) => a.id == widget.accountId)
              .firstOrNull;
          if (account == null) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(accountsProvider);
              ref.invalidate(accountTransactionsProvider(widget.accountId));
            },
            child: transactionsAsync.when(
              loading: () => ListView(
                padding: ViewInsets.listPadding(context),
                children: [
                  _AccountHeader(account: account),
                  const SizedBox(height: 20),
                  const SkeletonCard(),
                ],
              ),
              error: (error, _) => ListView(
                padding: ViewInsets.listPadding(context),
                children: [
                  _AccountHeader(account: account),
                  const SizedBox(height: 20),
                  ErrorState(message: error.toString()),
                ],
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return ListView(
                    padding: ViewInsets.listPadding(context),
                    children: [
                      _AccountHeader(account: account),
                      const SizedBox(height: 20),
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions',
                        subtitle: 'Add manually or import a CSV statement',
                        action: ElevatedButton(
                          onPressed: () =>
                              context.push('/accounts/${widget.accountId}/import'),
                          child: const Text('Import CSV'),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: ViewInsets.listPadding(context),
                  itemCount: transactions.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) return _AccountHeader(account: account);
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 12),
                        child: Text(
                          'Transactions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      );
                    }

                    final transaction = transactions[index - 2];
                    return SwooshCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      child: TransactionTile(transaction: transaction),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.account});

  final Account account;

  Color get _accent {
    switch (account.accountType) {
      case AccountType.everyday:
        return AppColors.everyday;
      case AccountType.savings:
        return AppColors.savings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.account_balance, color: _accent, size: 22),
    );

    return SwooshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(tag: 'account-${account.id}', child: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (account.institution != null)
                      Text(
                        account.institution!,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Money.format(
              account.balancePence,
              currency: account.currency,
            ),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
