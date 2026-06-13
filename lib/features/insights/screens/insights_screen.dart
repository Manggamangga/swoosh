import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/app_snackbar.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/category_icon.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/error_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/features/accounts/widgets/import_statement_sheet.dart';
import 'package:swoosh/features/insights/widgets/category_trend_chart.dart';
import 'package:swoosh/models/detected_recurring.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/onboarding_provider.dart';
import 'package:swoosh/providers/providers.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String? _selectedCategoryId;

  int _confirmedMonthlyTotal(List<RecurringPayment> payments) {
    return payments
        .where((p) => p.amountPence < 0)
        .fold<int>(0, (sum, p) {
      final monthly = _monthlyFromCadence(p.amountPence.abs(), p.cadence);
      return sum + monthly;
    });
  }

  int _monthlyFromCadence(int amountPence, RecurringCadence cadence) {
    switch (cadence) {
      case RecurringCadence.weekly:
        return (amountPence * 52 / 12).round();
      case RecurringCadence.monthly:
        return amountPence;
      case RecurringCadence.quarterly:
        return (amountPence / 3).round();
      case RecurringCadence.yearly:
        return (amountPence / 12).round();
    }
  }

  Future<void> _confirmDetected(DetectedRecurring detected) async {
    final userId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (userId == null) return;

    final detector = ref.read(recurringDetectionServiceProvider);
    final repo = ref.read(recurringRepositoryProvider);
    await repo.create(
      RecurringPayment(
        id: '',
        userId: userId,
        name: detected.name,
        amountPence: -detected.typicalAmountPence,
        currency: detected.currency,
        cadence: detected.cadence,
        nextDate: detector.nextDateFrom(detected.cadence, detected.lastSeenDate),
        accountId: detected.accountId,
        categoryId: detected.categoryId,
        autoDetected: true,
      ),
    );
    _invalidateRecurring();
    if (mounted) {
      showAppSnackBar(context, 'Added ${detected.name}');
    }
  }

  Future<void> _dismissDetected(DetectedRecurring detected) async {
    await ref
        .read(dismissedRecurringKeysProvider.notifier)
        .dismiss(detected.detectionKey);
    ref.invalidate(detectedRecurringProvider);
  }

  Future<void> _showAddRecurringSheet() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    RecurringCadence cadence = RecurringCadence.monthly;
    var isIncome = false;
    var nextDate = DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add recurring payment',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Expense')),
                  ButtonSegment(value: true, label: Text('Income')),
                ],
                selected: {isIncome},
                onSelectionChanged: (s) {
                  HapticFeedback.selectionClick();
                  setSheetState(() => isIncome = s.first);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RecurringCadence>(
                initialValue: cadence,
                decoration: const InputDecoration(labelText: 'Cadence'),
                items: RecurringCadence.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSheetState(() => cadence = v!),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next date'),
                subtitle:
                    Text('${nextDate.day}/${nextDate.month}/${nextDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: nextDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setSheetState(() => nextDate = picked);
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final userId =
                      ref.read(supabaseProvider).auth.currentUser?.id;
                  if (userId == null) return;

                  var amount = Money.parseToPence(amountController.text);
                  if (!isIncome && amount > 0) amount = -amount;
                  if (isIncome && amount < 0) amount = -amount;

                  await ref.read(recurringRepositoryProvider).create(
                        RecurringPayment(
                          id: '',
                          userId: userId,
                          name: nameController.text.trim(),
                          amountPence: amount,
                          currency: 'GBP',
                          cadence: cadence,
                          nextDate: nextDate,
                          autoDetected: false,
                        ),
                      );
                  _invalidateRecurring();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _invalidateRecurring() {
    ref.invalidate(recurringProvider);
    ref.invalidate(detectedRecurringProvider);
    ref.invalidate(safeToSpendProvider);
    ref.invalidate(upcomingRecurringProvider);
  }

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final recurringAsync = ref.watch(recurringProvider);
    final detectedAsync = ref.watch(detectedRecurringProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final accounts = accountsAsync.valueOrNull;
    if (accounts != null && accounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: ListView(
          padding: ViewInsets.listPadding(context),
          children: [
            EmptyState(
              icon: Icons.insights_outlined,
              title: 'No insights yet',
              subtitle: 'Import transactions to see recurring payments and category trends',
              actionLabel: 'Import statement',
              onAction: () => showImportStatementSheet(context, ref),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add recurring',
            onPressed: _showAddRecurringSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recurringProvider);
          ref.invalidate(detectedRecurringProvider);
          ref.invalidate(allTransactionsProvider);
          ref.invalidate(categoriesProvider);
        },
        child: ListView(
          padding: ViewInsets.listPadding(context),
          children: [
            Text(
              'Subscriptions & recurring',
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.md),
            recurringAsync.when(
              loading: () => const SkeletonCard(),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(recurringProvider),
              ),
              data: (confirmed) {
                final detected = detectedAsync.valueOrNull ?? [];
                final monthlyTotal = _confirmedMonthlyTotal(confirmed) +
                    detected.fold<int>(
                      0,
                      (sum, d) => sum + d.monthlyTotalPence,
                    );

                if (confirmed.isEmpty && detected.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_repeat,
                    title: 'No recurring payments',
                    subtitle:
                        'We will suggest subscriptions and bills as you import more transactions',
                    actionLabel: 'Add manually',
                    onAction: _showAddRecurringSheet,
                    compact: true,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (monthlyTotal > 0)
                      SwooshCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Est. monthly total',
                              style: AppTextStyles.label(context),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              Money.format(monthlyTotal),
                              style: AppTextStyles.headlineBalance(context),
                            ),
                          ],
                        ),
                      ),
                    if (monthlyTotal > 0) const SizedBox(height: AppSpacing.md),
                    ...confirmed.map(
                      (payment) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ConfirmedRecurringCard(payment: payment),
                      ),
                    ),
                    ...detected.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _DetectedRecurringCard(
                          detected: item,
                          onConfirm: () => _confirmDetected(item),
                          onDismiss: () => _dismissDetected(item),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            Text(
              'Category trends',
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.md),
            categoriesAsync.when(
              loading: () => const SkeletonCard(),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
              data: (categories) {
                if (categories.isEmpty) {
                  return const EmptyState(
                    icon: Icons.trending_up,
                    title: 'No categories yet',
                    subtitle: 'Categories appear after you import transactions',
                    compact: true,
                  );
                }

                final selectedId = _selectedCategoryId ?? categories.first.id;
                final selected = categories
                    .where((c) => c.id == selectedId)
                    .firstOrNull;
                final trendAsync = ref.watch(categoryTrendProvider(selectedId));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = category.id == selectedId;
                          return FilterChip(
                            label: Text(category.name),
                            selected: isSelected,
                            onSelected: (_) => setState(
                              () => _selectedCategoryId = category.id,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    trendAsync.when(
                      loading: () => const SkeletonLoader(height: 180),
                      error: (e, _) => ErrorState(message: e.toString()),
                      data: (points) {
                        final current = points.last.spentPence;
                        final previous = points.length > 1
                            ? points[points.length - 2].spentPence
                            : 0;
                        final change = current - previous;

                        return SwooshCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (selected != null)
                                    CategoryIcon(
                                      iconName: selected.icon,
                                      color: selected.color,
                                      size: 36,
                                    ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selected?.name ?? 'Category',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${Money.format(current)} this month',
                                          style: AppTextStyles.caption(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (change != 0)
                                    Text(
                                      '${change > 0 ? '+' : '-'}${Money.format(change.abs())}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: change > 0
                                            ? AppColors.spending
                                            : AppColors.income,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              CategoryTrendChart(
                                points: points,
                                categoryColor: selected != null
                                    ? _parseColor(selected.color)
                                    : AppColors.primary,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextButton(
                                onPressed: () => context.push(
                                  '/transactions?category=$selectedId',
                                ),
                                child: const Text('View transactions'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmedRecurringCard extends StatelessWidget {
  const _ConfirmedRecurringCard({required this.payment});

  final RecurringPayment payment;

  @override
  Widget build(BuildContext context) {
    return SwooshCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${payment.cadence.name} · Next ${DateFormat('d MMM').format(payment.nextDate)}',
                  style: AppTextStyles.caption(context),
                ),
                if (payment.categoryName != null)
                  Text(
                    payment.categoryName!,
                    style: AppTextStyles.captionMuted(context),
                  ),
              ],
            ),
          ),
          Text(
            Money.formatSigned(payment.amountPence),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedRecurringCard extends StatelessWidget {
  const _DetectedRecurringCard({
    required this.detected,
    required this.onConfirm,
    required this.onDismiss,
  });

  final DetectedRecurring detected;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SwooshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detected.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Text(
                            'Suggested',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${detected.cadence.name} · ${Money.format(detected.typicalAmountPence)} typical',
                      style: AppTextStyles.caption(context),
                    ),
                    Text(
                      '${Money.format(detected.monthlyTotalPence)}/mo · Last ${DateFormat('d MMM').format(detected.lastSeenDate)} · ${detected.occurrenceCount}×',
                      style: AppTextStyles.captionMuted(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
