import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/account_row.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/providers/data_providers.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () => context.push('/connect-bank'),
            tooltip: 'Connect bank',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounts/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsProvider),
        child: accountsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(20),
            children: const [SkeletonCard(), SizedBox(height: 16), SkeletonCard()],
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (accounts) {
            if (accounts.isEmpty) {
              return EmptyState(
                icon: Icons.account_balance_outlined,
                title: 'No accounts yet',
                subtitle: 'Add your Monzo, Barclays, Wise, or other accounts',
                action: ElevatedButton(
                  onPressed: () => context.push('/accounts/add'),
                  child: const Text('Add account'),
                ),
              );
            }

            final grouped = <AccountType, List<Account>>{};
            for (final account in accounts) {
              grouped.putIfAbsent(account.accountType, () => []).add(account);
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final type in AccountType.values) ...[
                  if (grouped[type]?.isNotEmpty ?? false) ...[
                    _SectionHeader(
                      title: type.name[0].toUpperCase() + type.name.substring(1),
                      total: grouped[type]!
                          .fold<int>(0, (sum, a) => sum + a.balancePence),
                      color: _colorForType(type),
                    ),
                    const SizedBox(height: 8),
                    SwooshCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Column(
                        children: grouped[type]!
                            .map(
                              (a) => AccountRow(
                                account: a,
                                onTap: () => context.push('/accounts/${a.id}'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _colorForType(AccountType type) {
    switch (type) {
      case AccountType.everyday:
        return AppColors.everyday;
      case AccountType.savings:
        return AppColors.savings;
      case AccountType.investment:
        return AppColors.investment;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.total,
    required this.color,
  });

  final String title;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          Money.format(total),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
