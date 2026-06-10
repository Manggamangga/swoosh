import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/account_row.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/period_pills.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/core/widgets/transaction_tile.dart';
import 'package:swoosh/features/accounts/widgets/add_account_chooser.dart';
import 'package:swoosh/features/home/widgets/balance_chart.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ChartPeriod _period = ChartPeriod.threeMonths;
  AccountType _selectedType = AccountType.everyday;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final balanceService = ref.watch(balanceHistoryServiceProvider);
    final bottomPadding = ViewInsets.bottomClearance(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          ref.invalidate(monthlySummaryProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('Overview'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.invalidate(accountsProvider);
                    ref.invalidate(transactionsProvider);
                  },
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _TypeTabs(
                  selected: _selectedType,
                  onChanged: (type) => setState(() => _selectedType = type),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: accountsAsync.when(
                  loading: () => const SkeletonCard(),
                  error: (e, _) => Text('Error: $e'),
                  data: (accounts) {
                    final filtered =
                        accounts.where((a) => a.accountType == _selectedType);
                    final total = filtered.fold<int>(
                      0,
                      (sum, a) => sum + a.balancePence,
                    );

                    return transactionsAsync.when(
                      loading: () => SwooshCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _labelForType(_selectedType),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              Money.format(total),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 16),
                            const SkeletonLoader(height: 180),
                          ],
                        ),
                      ),
                      error: (e, _) => Text('Error: $e'),
                      data: (transactions) {
                        final now = DateTime.now();
                        final start = _period.startFrom(now);
                        final points = balanceService.buildHistory(
                          accounts: filtered.toList(),
                          transactions: transactions,
                          start: start,
                          end: now,
                        );

                        return SwooshCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _labelForType(_selectedType),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Money.format(total),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEE, d MMMM').format(now),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              RepaintBoundary(
                                child: BalanceChart(points: points),
                              ),
                              const SizedBox(height: 16),
                              PeriodPills(
                                selected: _period,
                                onChanged: (period) =>
                                    setState(() => _period = period),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: summaryAsync.when(
                  loading: () => const SkeletonCard(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (summary) => SwooshCard(
                    child: Row(
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
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/transactions'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: transactionsAsync.when(
                loading: () => const SliverToBoxAdapter(child: SkeletonCard()),
                error: (e, _) => SliverToBoxAdapter(child: Text('Error: $e')),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions yet',
                        subtitle: 'Add an account and import or log transactions',
                        action: ElevatedButton(
                          onPressed: () => showAddAccountChooser(context),
                          child: const Text('Add account'),
                        ),
                      ),
                    );
                  }

                  final preview = transactions.take(5).toList();
                  return SliverToBoxAdapter(
                    child: SwooshCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        children: preview
                            .map((transaction) => TransactionTile(transaction: transaction))
                            .toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: accountsAsync.when(
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (e, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                data: (accounts) {
                  final filtered =
                      accounts.where((a) => a.accountType == _selectedType);
                  if (filtered.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Text(
                          'Accounts',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: SwooshCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Column(
                            children: filtered
                                .map(
                                  (account) => AccountRow(
                                    account: account,
                                    onTap: () => context.go('/accounts/${account.id}'),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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

  String _labelForType(AccountType type) {
    return type.name[0].toUpperCase() + type.name.substring(1);
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selected, required this.onChanged});

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...AccountType.values.map((type) {
            final isSelected = type == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(type);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.surfaceElevated
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    type.name[0].toUpperCase() + type.name.substring(1),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Net worth',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
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
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          Money.format(amount),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }
}
