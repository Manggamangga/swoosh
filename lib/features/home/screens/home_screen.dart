import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/services/balance_history_service.dart';
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
import 'package:swoosh/features/home/home_balance_view.dart';
import 'package:swoosh/features/home/widgets/balance_chart.dart';
import 'package:swoosh/core/widgets/animated_balance_text.dart';
import 'package:swoosh/features/home/widgets/price_change_alert_card.dart';
import 'package:swoosh/features/home/widgets/safe_to_spend_card.dart';
import 'package:swoosh/core/widgets/swoosh_chip.dart';
import 'package:swoosh/features/home/widgets/upcoming_bills_card.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ChartPeriod _period = ChartPeriod.threeMonths;
  HomeBalanceView _view = HomeBalanceView.everyday;
  bool _isSyncing = false;

  Future<void> _syncAll() async {
    if (_isSyncing) return;

    HapticFeedback.lightImpact();
    setState(() => _isSyncing = true);

    try {
      final connections = await ref.read(bankConnectionsProvider.future);
      var totalAccounts = 0;
      var totalTransactions = 0;
      final errors = <String>[];

      if (connections.isEmpty) {
        ref.invalidate(accountsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(monthlySummaryProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refreshed')),
          );
        }
        return;
      }

      final repo = ref.read(bankConnectionRepositoryProvider);
      final results = await Future.wait(
        connections.map((connection) async {
          try {
            return await repo.syncConnection(connection.id);
          } catch (error) {
            return {'error': error.toString()};
          }
        }),
      );

      for (final result in results) {
        if (result.containsKey('error')) {
          errors.add(result['error'] as String);
          continue;
        }
        totalAccounts += (result['accounts_synced'] as num?)?.toInt() ?? 0;
        totalTransactions +=
            (result['transactions_synced'] as num?)?.toInt() ?? 0;
      }

      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(monthlySummaryProvider);
      ref.invalidate(bankConnectionsProvider);
      ref.invalidate(chartTransactionsProvider(_period));
      ref.invalidate(upcomingRecurringProvider);
      ref.invalidate(recurringProvider);
      ref.invalidate(safeToSpendProvider);
      ref.invalidate(priceChangeAlertsProvider);
      ref.invalidate(balanceHistoryProvider((_period, _view)));

      if (!mounted) return;

      if (errors.isNotEmpty && totalAccounts == 0 && totalTransactions == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: ${errors.first}')),
        );
      } else {
        final message = errors.isEmpty
            ? 'Synced $totalAccounts account(s), $totalTransactions transaction(s)'
            : 'Synced $totalAccounts account(s), $totalTransactions transaction(s). '
                '${errors.length} connection(s) failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  List<Account> _accountsForView(List<Account> accounts) {
    return accountsForView(accounts, _view);
  }

  int _monthRecurringTotal(List<RecurringPayment> payments) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    return payments
        .where(
          (payment) =>
              !payment.nextDate.isBefore(monthStart) &&
              !payment.nextDate.isAfter(monthEnd),
        )
        .fold<int>(0, (sum, payment) => sum + payment.amountPence);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final chartTransactionsAsync = ref.watch(chartTransactionsProvider(_period));
    final balanceHistoryAsync = ref.watch(balanceHistoryProvider((_period, _view)));
    final safeToSpendAsync = ref.watch(safeToSpendProvider);
    final priceAlertsAsync = ref.watch(priceChangeAlertsProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final upcomingAsync = ref.watch(upcomingRecurringProvider);
    final recurringAsync = ref.watch(recurringProvider);
    final bottomPadding = ViewInsets.bottomClearance(context);

    final accounts = accountsAsync.valueOrNull;
    final chartLoading =
        chartTransactionsAsync.isLoading && chartTransactionsAsync.valueOrNull == null;
    final transactions = transactionsAsync.valueOrNull;
    final summary = summaryAsync.valueOrNull;
    final upcoming = upcomingAsync.valueOrNull ?? const [];
    final recurring = recurringAsync.valueOrNull ?? const [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _syncAll,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('Overview'),
              actions: [
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_outlined),
                ),
                IconButton(
                  onPressed: _isSyncing ? null : _syncAll,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _TypeTabs(
                  selected: _view,
                  onChanged: (view) => setState(() => _view = view),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _buildBalanceCard(
                  context,
                  accounts: accounts,
                  accountsLoading: accounts == null && accountsAsync.isLoading,
                  balanceHistoryAsync: balanceHistoryAsync,
                  chartLoading: chartLoading,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: safeToSpendAsync.when(
                  loading: () => const SkeletonCard(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (result) => SafeToSpendCard(result: result),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: priceAlertsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (alerts) {
                    if (alerts.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: alerts
                          .map((alert) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: PriceChangeAlertCard(alert: alert),
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: summary == null && summaryAsync.isLoading
                    ? const SkeletonCard()
                    : summary == null
                        ? const SizedBox.shrink()
                        : SwooshCard(
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
            if (upcoming.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: UpcomingBillsCard(
                    payments: upcoming,
                    monthTotalPence: _monthRecurringTotal(recurring),
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
              sliver: SliverToBoxAdapter(
                child: _buildTransactionsPreview(context, transactions, transactionsAsync),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _buildAccountsSection(context, accounts),
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

  Widget _buildBalanceCard(
    BuildContext context, {
    required List<Account>? accounts,
    required bool accountsLoading,
    required AsyncValue<List<BalancePoint>> balanceHistoryAsync,
    required bool chartLoading,
  }) {
    if (accountsLoading && accounts == null) {
      return const SkeletonCard();
    }

    if (accounts == null) {
      return const SizedBox.shrink();
    }

    final filtered = _accountsForView(accounts);
    final total = filtered.fold<int>(0, (sum, account) => sum + account.balancePence);
    final now = DateTime.now();

    return SwooshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelForHomeBalanceView(_view),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          AnimatedBalanceText(
            formattedAmount: Money.format(total),
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
          balanceHistoryAsync.when(
            loading: () => chartLoading
                ? const SkeletonLoader(height: 180)
                : const SkeletonLoader(height: 180),
            error: (_, __) => const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'Could not load chart',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
            data: (balanceHistory) {
              if (chartLoading && balanceHistory.isEmpty) {
                return const SkeletonLoader(height: 180);
              }
              return RepaintBoundary(
                child: BalanceChart(points: balanceHistory),
              );
            },
          ),
          const SizedBox(height: 16),
          PeriodPills(
            selected: _period,
            onChanged: (period) => setState(() => _period = period),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsPreview(
    BuildContext context,
    List<Transaction>? transactions,
    AsyncValue<List<Transaction>> transactionsAsync,
  ) {
    if (transactions == null && transactionsAsync.isLoading) {
      return const SkeletonCard();
    }

    if (transactions == null || transactions.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions yet',
        subtitle: 'Add an account and import or log transactions',
        action: ElevatedButton(
          onPressed: () => showAddAccountChooser(context, ref),
          child: const Text('Add account'),
        ),
      );
    }

    final preview = transactions.take(5).toList();
    return SwooshCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: preview
            .map((transaction) => TransactionTile(transaction: transaction))
            .toList(),
      ),
    );
  }

  Widget _buildAccountsSection(BuildContext context, List<Account>? accounts) {
    if (accounts == null || accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_view == HomeBalanceView.netWorth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final type in AccountType.values) ...[
            if (accounts.any((account) => account.accountType == type)) ...[
              Text(
                type.name[0].toUpperCase() + type.name.substring(1),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              SwooshCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: accounts
                      .where((account) => account.accountType == type)
                      .map(
                        (account) => AccountRow(
                          account: account,
                          heroTag: 'account-${account.id}',
                          onTap: () => context.push('/accounts/${account.id}'),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ],
      );
    }

    final filtered = _accountsForView(accounts);
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accounts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        SwooshCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: filtered
                .map(
                  (account) => AccountRow(
                    account: account,
                    heroTag: 'account-${account.id}',
                    onTap: () => context.push('/accounts/${account.id}'),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.selected,
    required this.onChanged,
  });

  final HomeBalanceView selected;
  final ValueChanged<HomeBalanceView> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = [
      HomeBalanceView.everyday,
      HomeBalanceView.savings,
      HomeBalanceView.netWorth,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((view) {
          final isSelected = view == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SwooshChip(
              label: _label(view),
              selected: isSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(view);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(HomeBalanceView view) => labelForHomeBalanceView(view);
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
