import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/fab_location.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/account_row.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/features/accounts/widgets/import_statement_sheet.dart';
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
      ),
      floatingActionButtonLocation:
          FabAboveNavBarLocation(ViewInsets.bottomClearance(context)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showImportStatementSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsProvider),
        child: accountsAsync.when(
          skipLoadingOnReload: true,
          loading: () => ListView(
            padding: ViewInsets.listPadding(context, includeFab: true),
            children: const [
              SkeletonCard(),
              SizedBox(height: AppSpacing.lg),
              SkeletonAccountList(itemCount: 4),
            ],
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
                    subtitle: 'Import a bank statement to add your first account',
                    actionLabel: 'Import statement',
                    onAction: () => showImportStatementSheet(context, ref),
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
                  padding: EdgeInsets.only(
                    bottom: index == sections.length - 1 ? 0 : AppSpacing.sectionGap,
                  ),
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
                      const SizedBox(height: AppSpacing.sm),
                      SwooshCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.xs,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < sectionAccounts.length; i++)
                              AccountRow(
                                account: sectionAccounts[i],
                                onTap: () =>
                                    context.push('/accounts/${sectionAccounts[i].id}'),
                                showDivider: i < sectionAccounts.length - 1,
                              ),
                          ],
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
      case AccountType.credit:
        return AppColors.credit;
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
          style: AppTextStyles.sectionTitle(context),
        ),
        Text(
          Money.format(total),
          style: AppTextStyles.amount(context, color: color),
        ),
      ],
    );
  }
}
