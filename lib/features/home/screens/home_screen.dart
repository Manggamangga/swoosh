import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/app_snackbar.dart';
import 'package:swoosh/core/utils/haptics.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/account_row.dart';
import 'package:swoosh/core/widgets/animated_balance_text.dart';
import 'package:swoosh/core/widgets/category_icon.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/frosted_sliver_app_bar.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/core/widgets/transaction_tile.dart';
import 'package:swoosh/features/accounts/widgets/import_statement_sheet.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/data_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref, BuildContext context) async {
    AppHaptics.light();
    ref.invalidate(accountsProvider);
    ref.invalidate(netWorthProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(topSpendingCategoriesProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(recurringProvider);
    ref.invalidate(upcomingRecurringProvider);
    if (context.mounted) {
      showAppSnackBar(context, 'Refreshed');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final netWorthAsync = ref.watch(netWorthProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final topCategoriesAsync = ref.watch(topSpendingCategoriesProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final recurringAsync = ref.watch(recurringProvider);
    final bottomPadding = ViewInsets.bottomClearance(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref, context),
        child: CustomScrollView(
          slivers: [
            FrostedSliverAppBar(
              title: const Text('Overview'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                ),
                IconButton(
                  onPressed: () => _refresh(ref, context),
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.lg,
                AppSpacing.pageHorizontal,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _NetWorthHero(netWorthAsync: netWorthAsync),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sectionGap,
                AppSpacing.pageHorizontal,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _AccountsSection(accountsAsync: accountsAsync),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sectionGap,
                AppSpacing.pageHorizontal,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: summaryAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const SkeletonCard(height: 88),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (summary) => _MonthlySummaryCard(summary: summary),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sectionGap,
                AppSpacing.pageHorizontal,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _TopCategoriesSection(
                  categoriesAsync: topCategoriesAsync,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sectionGap,
                AppSpacing.pageHorizontal,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _RecentTransactionsSection(
                  transactionsAsync: transactionsAsync,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sectionGap,
                AppSpacing.pageHorizontal,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: recurringAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const SkeletonCard(height: 100),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (recurring) => _RecurringTeaser(
                    recurring: recurring,
                    onTap: () => context.push('/insights'),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              sliver: const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.netWorthAsync});

  final AsyncValue<int> netWorthAsync;

  @override
  Widget build(BuildContext context) {
    return netWorthAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SkeletonCard(height: 120),
      error: (_, __) => SwooshCard(
        child: Text(
          'Could not load net worth',
          style: AppTextStyles.bodyMuted(context),
        ),
      ),
      data: (netWorth) {
        final now = DateTime.now();
        return SwooshCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Net worth', style: AppTextStyles.label(context)),
              const SizedBox(height: AppSpacing.sm),
              AnimatedBalanceText(
                formattedAmount: Money.format(netWorth),
                style: AppTextStyles.headlineBalance(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                DateFormat('EEE, d MMMM').format(now),
                style: AppTextStyles.captionMuted(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountsSection extends ConsumerWidget {
  const _AccountsSection({
    required this.accountsAsync,
  });

  final AsyncValue<List<Account>> accountsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return accountsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SkeletonAccountList(itemCount: 4),
      error: (_, __) => const SizedBox.shrink(),
      data: (accounts) {
        if (accounts.isEmpty) {
          return EmptyState(
            icon: Icons.account_balance_outlined,
            title: 'No accounts yet',
            subtitle: 'Import a statement to see your net worth',
            actionLabel: 'Import statement',
            onAction: () => showImportStatementSheet(context, ref),
            compact: true,
          );
        }

        final sorted = [...accounts]..sort(
            (a, b) => a.accountType.index.compareTo(b.accountType.index),
          );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accounts', style: AppTextStyles.sectionTitle(context)),
            const SizedBox(height: AppSpacing.md),
            SwooshCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < sorted.length; i++)
                    AccountRow(
                      account: sorted[i],
                      heroTag: 'account-${sorted[i].id}',
                      onTap: () => context.push('/accounts/${sorted[i].id}'),
                      showDivider: i < sorted.length - 1,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM').format(DateTime.now());

    return SwooshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This month',
            style: AppTextStyles.sectionTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            monthLabel,
            style: AppTextStyles.captionMuted(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SummaryColumn(
                  label: 'Income',
                  amount: summary.incomePence,
                  color: AppColors.income,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: AppColors.border,
              ),
              Expanded(
                child: _SummaryColumn(
                  label: 'Spending',
                  amount: summary.spendingPence,
                  color: AppColors.spending,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.label(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Money.format(amount),
          style: AppTextStyles.amount(context, color: color),
        ),
      ],
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({required this.transactionsAsync});

  final AsyncValue<List<Transaction>> transactionsAsync;

  @override
  Widget build(BuildContext context) {
    return transactionsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SkeletonTransactionList(itemCount: 3),
      error: (_, __) => const SizedBox.shrink(),
      data: (transactions) {
        if (transactions.isEmpty) return const SizedBox.shrink();

        final preview = transactions.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent transactions',
                  style: AppTextStyles.sectionTitle(context),
                ),
                TextButton(
                  onPressed: () => context.push('/transactions'),
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
                  for (var i = 0; i < preview.length; i++)
                    InkWell(
                      onTap: () => context.push('/transactions'),
                      child: TransactionTile(
                        transaction: preview[i],
                        showDivider: i < preview.length - 1,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopCategoriesSection extends StatelessWidget {
  const _TopCategoriesSection({required this.categoriesAsync});

  final AsyncValue<List<CategorySpendingRow>> categoriesAsync;

  @override
  Widget build(BuildContext context) {
    return categoriesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SkeletonTransactionList(itemCount: 3),
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top spending',
                  style: AppTextStyles.sectionTitle(context),
                ),
                TextButton(
                  onPressed: () => context.push('/spending'),
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
                  for (var i = 0; i < categories.length; i++)
                    _CategoryPreviewRow(
                      row: categories[i],
                      showDivider: i < categories.length - 1,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryPreviewRow extends StatelessWidget {
  const _CategoryPreviewRow({
    required this.row,
    required this.showDivider,
  });

  final CategorySpendingRow row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.listItemVertical),
          child: Row(
            children: [
              CategoryIcon(
                iconName: row.categoryIcon,
                color: row.categoryColor,
                size: 36,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  row.categoryName,
                  style: AppTextStyles.tileTitle(context),
                ),
              ),
              Text(
                Money.format(row.spentPence),
                style: AppTextStyles.tileTitle(context),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.6),
          ),
      ],
    );
  }
}

class _RecurringTeaser extends StatelessWidget {
  const _RecurringTeaser({
    required this.recurring,
    required this.onTap,
  });

  final List<RecurringPayment> recurring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (recurring.isEmpty) return const SizedBox.shrink();

    final monthlyTotal = recurring
        .where((payment) => payment.amountPence < 0)
        .fold<int>(0, (sum, payment) => sum + payment.amountPence.abs());

    return SwooshCard(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: AppSpacing.iconSize,
            height: AppSpacing.iconSize,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.autorenew,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recurring payments',
                  style: AppTextStyles.tileTitle(context),
                ),
                const SizedBox(height: 2),
                Text(
                  '${recurring.length} tracked · ${Money.format(monthlyTotal)}/mo',
                  style: AppTextStyles.tileSubtitle(context),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
