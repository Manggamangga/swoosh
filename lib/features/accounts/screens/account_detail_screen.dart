import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/error_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/transaction_tile.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/features/accounts/widgets/import_statement_sheet.dart';
import 'package:swoosh/models/account.dart';
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

  Future<void> _setCurrentBalance(Account account) async {
    final controller = TextEditingController(
      text: (account.balancePence.abs() / 100).toStringAsFixed(2),
    );
    final isCredit = account.accountType == AccountType.credit;

    final balanceText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCredit ? 'Set amount owed' : 'Set current balance'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: isCredit ? 'Amount owed' : 'Current balance',
            prefixText: '£',
          ),
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

    if (balanceText == null || balanceText.isEmpty) return;

    final pence = Money.parseToPence(balanceText);
    final resolved = isCredit ? -pence.abs() : pence;
    final today = DateTime.now().toIso8601String().split('T').first;

    final repo = await ref.read(accountRepositoryProvider.future);
    await repo.update(widget.accountId, {
      'balance_pence': resolved,
      'balance_anchor_pence': resolved,
      'balance_anchor_date': today,
    });
    ref.invalidate(accountsProvider);
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

    final repo = await ref.read(accountRepositoryProvider.future);
    await repo.delete(widget.accountId);
    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(allTransactionsProvider);

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
            tooltip: 'Import statement',
            onPressed: () => showImportStatementSheet(
              context,
              ref,
              accountId: widget.accountId,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final account = accountsAsync.valueOrNull
                  ?.where((item) => item.id == widget.accountId)
                  .firstOrNull;
              if (account == null) return;
              if (value == 'delete') {
                _deleteAccount(account);
              } else if (value == 'balance') {
                _setCurrentBalance(account);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'balance',
                child: Text('Set current balance'),
              ),
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
          children: const [
            SkeletonCard(),
            SizedBox(height: AppSpacing.sectionGap),
            SkeletonTransactionList(itemCount: 6),
          ],
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
                  const SizedBox(height: AppSpacing.sectionGap),
                  Text(
                    'Transactions',
                    style: AppTextStyles.sectionTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const SkeletonTransactionList(itemCount: 6),
                ],
              ),
              error: (error, _) => ListView(
                padding: ViewInsets.listPadding(context),
                children: [
                  _AccountHeader(account: account),
                  const SizedBox(height: AppSpacing.sectionGap),
                  ErrorState(message: error.toString()),
                ],
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return ListView(
                    padding: ViewInsets.listPadding(context),
                    children: [
                      _AccountHeader(account: account),
                      const SizedBox(height: AppSpacing.sectionGap),
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions',
                        subtitle: 'Import a statement to add transactions',
                        actionLabel: 'Import statement',
                        onAction: () => showImportStatementSheet(
                          context,
                          ref,
                          accountId: widget.accountId,
                        ),
                      ),
                    ],
                  );
                }

                return ListView(
                  padding: ViewInsets.listPadding(context),
                  children: [
                    _AccountHeader(account: account),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transactions',
                          style: AppTextStyles.sectionTitle(context),
                        ),
                        TextButton(
                          onPressed: () => context.push(
                            '/transactions?account=${widget.accountId}',
                          ),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwooshCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.cardPadding,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < transactions.length; i++)
                            InkWell(
                              onTap: () => context.push(
                                '/transactions?account=${widget.accountId}',
                              ),
                              child: TransactionTile(
                                transaction: transactions[i],
                                showExcludedBadge: true,
                                showDivider: i < transactions.length - 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
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
      case AccountType.credit:
        return AppColors.credit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: AppSpacing.iconSize,
      height: AppSpacing.iconSize,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.account_balance, color: _accent, size: 22),
    );

    return SwooshCard(
      variant: SwooshCardVariant.elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(tag: 'account-${account.id}', child: icon),
              const SizedBox(width: AppSpacing.iconGap),
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
                        style: AppTextStyles.tileSubtitle(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            Money.format(
              account.balancePence,
              currency: account.currency,
            ),
            style: AppTextStyles.headlineBalance(context),
          ),
        ],
      ),
    );
  }
}
