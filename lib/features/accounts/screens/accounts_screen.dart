import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/account_row.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/features/accounts/widgets/add_account_chooser.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final connectionsAsync = ref.watch(bankConnectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          connectionsAsync.maybeWhen(
            data: (connections) {
              if (connections.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.settings_ethernet),
                tooltip: 'Manage connections',
                onPressed: () => context.push('/connect-bank'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddAccountChooser(context),
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsProvider),
        child: accountsAsync.when(
          loading: () => ListView(
            padding: ViewInsets.listPadding(context, includeFab: true),
            children: const [SkeletonCard(), SizedBox(height: 16), SkeletonCard()],
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (accounts) {
            if (accounts.isEmpty) {
              return ListView(
                padding: ViewInsets.listPadding(context),
                children: [
                  EmptyState(
                    icon: Icons.account_balance_outlined,
                    title: 'No accounts yet',
                    subtitle: 'Add your Monzo, Barclays, Wise, or other accounts',
                    action: ElevatedButton(
                      onPressed: () => showAddAccountChooser(context),
                      child: const Text('Add account'),
                    ),
                  ),
                ],
              );
            }

            final grouped = <AccountType, List<Account>>{};
            for (final account in accounts) {
              grouped.putIfAbsent(account.accountType, () => []).add(account);
            }

            final sections = AccountType.values
                .where((type) => grouped[type]?.isNotEmpty ?? false)
                .toList();

            return ListView.builder(
              padding: ViewInsets.listPadding(context, includeFab: true),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final type = sections[index];
                final sectionAccounts = grouped[type]!;
                return Padding(
                  padding: EdgeInsets.only(bottom: index == sections.length - 1 ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: type.name[0].toUpperCase() + type.name.substring(1),
                        total: sectionAccounts.fold<int>(
                          0,
                          (sum, account) => sum + account.balancePence,
                        ),
                        color: _colorForType(type),
                      ),
                      const SizedBox(height: 8),
                      SwooshCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Column(
                          children: sectionAccounts
                              .map(
                                (account) => AccountRow(
                                  account: account,
                                  onTap: () => context.push('/accounts/${account.id}'),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
