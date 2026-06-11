import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/category_icon.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/features/spending/widgets/budget_sheet.dart';
import 'package:swoosh/providers/data_providers.dart';

enum _SpendingViewMode { amount, change }

class SpendingScreen extends ConsumerStatefulWidget {
  const SpendingScreen({super.key});

  @override
  ConsumerState<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends ConsumerState<SpendingScreen> {
  late DateTime _selectedMonth;
  _SpendingViewMode _viewMode = _SpendingViewMode.amount;
  SpendingMonthData? _cachedData;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(spendingMonthProvider(_selectedMonth), (_, next) {
      next.whenData((data) {
        if (_cachedData != data) {
          setState(() => _cachedData = data);
        }
      });
    });

    final spendingAsync = ref.watch(spendingMonthProvider(_selectedMonth));
    final displayData = spendingAsync.valueOrNull ?? _cachedData;
    final isInitialLoad = displayData == null && spendingAsync.isLoading;
    final isRefreshing = displayData != null && spendingAsync.isLoading;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final isCurrentMonth = _selectedMonth.year == DateTime.now().year &&
        _selectedMonth.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(title: const Text('Spending')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(spendingMonthProvider(_selectedMonth));
          ref.invalidate(budgetsForMonthProvider(_selectedMonth));
        },
        child: isInitialLoad
            ? ListView(
                padding: ViewInsets.listPadding(context),
                children: const [
                  SkeletonCard(),
                  SizedBox(height: 16),
                  SkeletonCard(),
                  SizedBox(height: 12),
                  SkeletonCard(),
                ],
              )
            : spendingAsync.hasError && displayData == null
                ? Center(child: Text('Error: ${spendingAsync.error}'))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: Opacity(
                      key: ValueKey(_selectedMonth),
                      opacity: isRefreshing ? 0.55 : 1,
                      child: _SpendingContent(
                        data: displayData!,
                        monthLabel: monthLabel,
                        isCurrentMonth: isCurrentMonth,
                        selectedMonth: _selectedMonth,
                        viewMode: _viewMode,
                        onPreviousMonth: () => _shiftMonth(-1),
                        onNextMonth:
                            isCurrentMonth ? null : () => _shiftMonth(1),
                        onViewModeChanged: (mode) =>
                            setState(() => _viewMode = mode),
                        onCategoryTap: (categoryId) {
                          if (categoryId == '_uncategorized') return;
                          context.push('/transactions?category=$categoryId');
                        },
                        onSetBudget: (row) => showBudgetSheet(
                          context,
                          ref,
                          month: _selectedMonth,
                          categoryId: row.categoryId == '_uncategorized'
                              ? null
                              : row.categoryId,
                          categoryName: row.categoryName,
                          existingBudget: row.budget,
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _SpendingContent extends StatelessWidget {
  const _SpendingContent({
    required this.data,
    required this.monthLabel,
    required this.isCurrentMonth,
    required this.selectedMonth,
    required this.viewMode,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onViewModeChanged,
    required this.onCategoryTap,
    required this.onSetBudget,
  });

  final SpendingMonthData data;
  final String monthLabel;
  final bool isCurrentMonth;
  final DateTime selectedMonth;
  final _SpendingViewMode viewMode;
  final VoidCallback onPreviousMonth;
  final VoidCallback? onNextMonth;
  final ValueChanged<_SpendingViewMode> onViewModeChanged;
  final ValueChanged<String> onCategoryTap;
  final ValueChanged<CategorySpendingRow> onSetBudget;

  @override
  Widget build(BuildContext context) {
    if (data.categories.isEmpty && data.totalSpentPence == 0) {
      return ListView(
        padding: ViewInsets.listPadding(context),
        children: [
          _MonthHeader(
            label: monthLabel,
            isCurrentMonth: isCurrentMonth,
            onPrevious: onPreviousMonth,
            onNext: onNextMonth,
          ),
          const SizedBox(height: 24),
          const EmptyState(
            icon: Icons.pie_chart_outline,
            title: 'No spending this month',
            subtitle: 'Transactions on everyday accounts will appear here',
          ),
        ],
      );
    }

    final maxSpent = data.categories
        .map((row) => row.spentPence)
        .fold<int>(0, (max, value) => value > max ? value : max);

    return ListView(
      padding: ViewInsets.listPadding(context),
      children: [
        _MonthHeader(
          label: monthLabel,
          isCurrentMonth: isCurrentMonth,
          onPrevious: onPreviousMonth,
          onNext: onNextMonth,
        ),
        const SizedBox(height: 16),
        SwooshCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Total spent',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                Money.format(data.totalSpentPence),
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'in ${DateFormat('MMMM').format(selectedMonth)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              _ViewModeToggle(
                mode: viewMode,
                onChanged: onViewModeChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...data.categories.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CategorySpendingRow(
              row: row,
              maxSpent: maxSpent,
              viewMode: viewMode,
              onTap: () => onCategoryTap(row.categoryId),
              onSetBudget: () => onSetBudget(row),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.isCurrentMonth,
    required this.onPrevious,
    this.onNext,
  });

  final String label;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: Icon(
            Icons.chevron_right,
            color: onNext == null ? AppColors.textMuted : null,
          ),
        ),
      ],
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final _SpendingViewMode mode;
  final ValueChanged<_SpendingViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              label: 'Amount',
              selected: mode == _SpendingViewMode.amount,
              onTap: () => onChanged(_SpendingViewMode.amount),
            ),
          ),
          Expanded(
            child: _ToggleChip(
              label: 'Change',
              selected: mode == _SpendingViewMode.change,
              onTap: () => onChanged(_SpendingViewMode.change),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategorySpendingRow extends StatelessWidget {
  const _CategorySpendingRow({
    required this.row,
    required this.maxSpent,
    required this.viewMode,
    required this.onTap,
    required this.onSetBudget,
  });

  final CategorySpendingRow row;
  final int maxSpent;
  final _SpendingViewMode viewMode;
  final VoidCallback onTap;
  final VoidCallback onSetBudget;

  Color _parseColor(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(row.categoryColor);
    final barFraction =
        maxSpent == 0 ? 0.0 : (row.spentPence / maxSpent).clamp(0.0, 1.0);
    final budget = row.budget;
    final progress = budget?.progress.clamp(0.0, 1.0) ?? 0.0;
    final budgetColor =
        budget?.isOverBudget == true ? AppColors.error : AppColors.primary;

    final trailingText = viewMode == _SpendingViewMode.amount
        ? Money.format(row.spentPence)
        : _formatChange(row.changePence);

    return SwooshCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIcon(
                iconName: 'category',
                color: row.categoryColor,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    FractionallySizedBox(
                      widthFactor: barFraction,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        row.categoryName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailingText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: viewMode == _SpendingViewMode.change
                      ? _changeColor(row.changePence)
                      : AppColors.textPrimary,
                ),
              ),
              PopupMenuButton<String>(
                icon: row.categoryId == '_uncategorized'
                    ? const SizedBox(width: 24)
                    : const Icon(Icons.more_vert, color: AppColors.textMuted),
                onSelected: (value) {
                  if (value == 'budget') onSetBudget();
                },
                itemBuilder: (context) {
                  if (row.categoryId == '_uncategorized') {
                    return const [];
                  }
                  return [
                    PopupMenuItem(
                      value: 'budget',
                      child: Text(
                        budget == null ? 'Set budget' : 'Edit budget',
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          if (budget != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceElevated,
                      color: budgetColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${Money.format(budget.spentPence)} / ${Money.format(budget.amountPence)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: budgetColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatChange(int changePence) {
    if (changePence == 0) return '—';
    final prefix = changePence > 0 ? '+' : '-';
    return '$prefix${Money.format(changePence.abs())}';
  }

  Color _changeColor(int changePence) {
    if (changePence == 0) return AppColors.textMuted;
    return changePence > 0 ? AppColors.spending : AppColors.income;
  }
}
