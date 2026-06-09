import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/transaction_tile.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

final accountTransactionsProvider =
    FutureProvider.family<List<Transaction>, String>((ref, accountId) async {
  final repo = await ref.watch(transactionRepositoryProvider.future);
  return repo.fetchByAccount(accountId);
});

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(accountTransactionsProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => context.push('/accounts/$accountId/import'),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.push('/accounts/$accountId/transfer'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/accounts/$accountId/add-tx'),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          final account = accounts.firstWhere((a) => a.id == accountId);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(accountsProvider);
              ref.invalidate(accountTransactionsProvider(accountId));
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SwooshCard(
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
                          style: const TextStyle(color: Colors.grey),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        Money.format(
                          account.balancePence,
                          currency: account.currency,
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Transactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                transactionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions',
                        subtitle: 'Add manually or import a CSV statement',
                        action: ElevatedButton(
                          onPressed: () =>
                              context.push('/accounts/$accountId/import'),
                          child: const Text('Import CSV'),
                        ),
                      );
                    }
                    return SwooshCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        children: transactions
                            .map((t) => TransactionTile(transaction: t))
                            .toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
