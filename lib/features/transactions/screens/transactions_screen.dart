import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/spacing.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/error_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/transaction_tile.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/category.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

enum TransactionTypeFilter { all, income, spend, excluded }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({
    super.key,
    this.initialCategoryId,
    this.initialAccountId,
  });

  final String? initialCategoryId;
  final String? initialAccountId;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _selectedCategoryId;
  String? _selectedAccountId;
  String _search = '';
  bool _categorizing = false;
  TransactionTypeFilter _typeFilter = TransactionTypeFilter.all;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _selectedAccountId = widget.initialAccountId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runRetroactiveOnce());
  }

  Future<void> _runRetroactiveOnce() async {
    if (_categorizing) return;
    setState(() => _categorizing = true);
    try {
      final service = await ref.read(categorizationServiceProvider.future);
      final updated = await service.retroactivelyCategorize();
      if (updated > 0) {
        _invalidateAll();
      }
    } catch (_) {}
    if (mounted) setState(() => _categorizing = false);
  }

  bool get _hasSecondaryFilters =>
      _selectedAccountId != null ||
      _selectedCategoryId != null ||
      _typeFilter == TransactionTypeFilter.excluded ||
      _startDate != null ||
      _endDate != null;

  List<Transaction> _filter(List<Transaction> transactions) {
    final query = _search.trim().toLowerCase();
    return transactions.where((transaction) {
      if (_selectedCategoryId != null &&
          transaction.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_selectedAccountId != null &&
          transaction.accountId != _selectedAccountId) {
        return false;
      }
      if (_startDate != null &&
          transaction.transactionDate.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null) {
        final end = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );
        if (transaction.transactionDate.isAfter(end)) return false;
      }
      switch (_typeFilter) {
        case TransactionTypeFilter.income:
          if (transaction.amountPence <= 0) return false;
        case TransactionTypeFilter.spend:
          if (transaction.amountPence >= 0) return false;
        case TransactionTypeFilter.excluded:
          if (!transaction.excludeFromAnalytics) return false;
        case TransactionTypeFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      final haystack =
          '${transaction.merchant ?? ''} ${transaction.description} ${transaction.accountName ?? ''}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _showFiltersSheet({
    required List<Account> accounts,
    required List<Category> categories,
  }) async {
    var accountId = _selectedAccountId;
    var categoryId = _selectedCategoryId;
    var typeFilter = _typeFilter;
    var startDate = _startDate;
    var endDate = _endDate;

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
                'Refine',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Account, category, date range, and excluded transactions',
                style: AppTextStyles.captionMuted(ctx),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All accounts')),
                  ...accounts.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ),
                ],
                onChanged: (v) => setSheetState(() => accountId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All categories')),
                  ...categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setSheetState(() => categoryId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TransactionTypeFilter>(
                initialValue: typeFilter,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: TransactionTypeFilter.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: TransactionTypeFilter.spend,
                    child: Text('Spending'),
                  ),
                  DropdownMenuItem(
                    value: TransactionTypeFilter.income,
                    child: Text('Income'),
                  ),
                  DropdownMenuItem(
                    value: TransactionTypeFilter.excluded,
                    child: Text('Excluded from analytics'),
                  ),
                ],
                onChanged: (v) => setSheetState(() => typeFilter = v!),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('From date'),
                subtitle: Text(
                  startDate != null
                      ? DateFormat('d MMM yyyy').format(startDate!)
                      : 'Any',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => startDate = picked);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('To date'),
                subtitle: Text(
                  endDate != null
                      ? DateFormat('d MMM yyyy').format(endDate!)
                      : 'Any',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => endDate = picked);
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedAccountId = accountId;
                    _selectedCategoryId = categoryId;
                    _typeFilter = typeFilter;
                    _startDate = startDate;
                    _endDate = endDate;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Apply filters'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedAccountId = null;
                    _selectedCategoryId = null;
                    _typeFilter = TransactionTypeFilter.all;
                    _startDate = null;
                    _endDate = null;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransactionActions(Transaction transaction) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit transaction'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: Icon(
                transaction.excludeFromAnalytics
                    ? Icons.analytics_outlined
                    : Icons.analytics,
              ),
              title: Text(
                transaction.excludeFromAnalytics
                    ? 'Include in analytics'
                    : 'Exclude from analytics',
              ),
              onTap: () => Navigator.pop(context, 'exclude'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Delete transaction',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    final txRepo = await ref.read(transactionRepositoryProvider.future);

    switch (action) {
      case 'edit':
        await _editTransaction(transaction);
      case 'exclude':
        await txRepo.updateExcludeFromAnalytics(
          transactionId: transaction.id,
          exclude: !transaction.excludeFromAnalytics,
        );
        _invalidateAll();
      case 'delete':
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirmed == true) {
          await txRepo.delete(transaction.id);
          _invalidateAll();
        }
    }
  }

  Future<void> _editTransaction(Transaction transaction) async {
    final descriptionController =
        TextEditingController(text: transaction.description);
    final amountController = TextEditingController(
      text: Money.format(transaction.amountPence.abs()),
    );
    var date = transaction.transactionDate;
    var isExpense = transaction.amountPence < 0;
    String? categoryId = transaction.categoryId;
    final originalCategoryId = transaction.categoryId;

    final categories = await ref.read(categoriesProvider.future);
    if (!mounted) return;

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
                'Edit transaction',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
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
                  ButtonSegment(value: true, label: Text('Expense')),
                  ButtonSegment(value: false, label: Text('Income')),
                ],
                selected: {isExpense},
                onSelectionChanged: (s) =>
                    setSheetState(() => isExpense = s.first),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text('${date.day}/${date.month}/${date.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => date = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('General')),
                  ...categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setSheetState(() => categoryId = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  var amountPence = Money.parseToPence(amountController.text);
                  if (isExpense && amountPence > 0) amountPence = -amountPence;
                  if (!isExpense && amountPence < 0) amountPence = -amountPence;

                  final hash = buildDedupeHash(
                    accountId: transaction.accountId,
                    date: date,
                    amountPence: amountPence,
                    description: descriptionController.text.trim(),
                  );

                  final txRepo =
                      await ref.read(transactionRepositoryProvider.future);
                  await txRepo.update(
                    transactionId: transaction.id,
                    updates: {
                      'description': descriptionController.text.trim(),
                      'merchant': descriptionController.text.trim(),
                      'amount_pence': amountPence,
                      'transaction_date':
                          date.toIso8601String().split('T').first,
                      'category_id': categoryId,
                      'dedupe_hash': hash,
                    },
                  );

                  if (categoryId != null && categoryId != originalCategoryId) {
                    final catService =
                        await ref.read(categorizationServiceProvider.future);
                    await catService.learnFromCorrection(
                      transaction: transaction,
                      categoryId: categoryId!,
                    );
                  }

                  _invalidateAll();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _invalidateAll() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(budgetsProvider);
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(safeToSpendProvider);
    ref.invalidate(priceChangeAlertsProvider);
    ref.invalidate(detectedRecurringProvider);
    final now = DateTime.now();
    ref.invalidate(spendingMonthProvider(DateTime(now.year, now.month, 1)));
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          if (_categorizing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasSecondaryFilters,
              smallSize: 8,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'More filters',
            onPressed: () async {
              final accounts = await ref.read(accountsProvider.future);
              final categories = await ref.read(categoriesProvider.future);
              if (!mounted) return;
              await _showFiltersSheet(
                accounts: accounts,
                categories: categories,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search transactions',
                prefixIcon: const Icon(Icons.search, size: 22),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SegmentedButton<TransactionTypeFilter>(
              segments: const [
                ButtonSegment(
                  value: TransactionTypeFilter.all,
                  label: Text('All'),
                ),
                ButtonSegment(
                  value: TransactionTypeFilter.spend,
                  label: Text('Spend'),
                ),
                ButtonSegment(
                  value: TransactionTypeFilter.income,
                  label: Text('Income'),
                ),
              ],
              selected: {
                _typeFilter == TransactionTypeFilter.excluded
                    ? TransactionTypeFilter.all
                    : _typeFilter,
              },
              onSelectionChanged: (selection) =>
                  setState(() => _typeFilter = selection.first),
            ),
          ),
          accountsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (accounts) => categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (categories) => _ActiveFilterPills(
                accounts: accounts,
                categories: categories,
                accountId: _selectedAccountId,
                categoryId: _selectedCategoryId,
                typeFilter: _typeFilter,
                startDate: _startDate,
                endDate: _endDate,
                onClearAccount: () =>
                    setState(() => _selectedAccountId = null),
                onClearCategory: () =>
                    setState(() => _selectedCategoryId = null),
                onClearType: () =>
                    setState(() => _typeFilter = TransactionTypeFilter.all),
                onClearDates: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                }),
                onClearAll: () => setState(() {
                  _selectedAccountId = null;
                  _selectedCategoryId = null;
                  _typeFilter = TransactionTypeFilter.all;
                  _startDate = null;
                  _endDate = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allTransactionsProvider);
                ref.invalidate(transactionsProvider);
              },
              child: transactionsAsync.when(
                loading: () => ListView(
                  padding: ViewInsets.listPadding(context),
                  children: const [
                    SkeletonCard(),
                    SizedBox(height: 16),
                    SkeletonCard(),
                  ],
                ),
                error: (error, _) => ListView(
                  padding: ViewInsets.listPadding(context),
                  children: [
                    ErrorState(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(allTransactionsProvider),
                    ),
                  ],
                ),
                data: (transactions) {
                  final filtered = _filter(transactions);
                  if (filtered.isEmpty) {
                    return ListView(
                      padding: ViewInsets.listPadding(context),
                      children: const [
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No matching transactions',
                          subtitle: 'Try another filter or search term',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: ViewInsets.listPadding(context),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final transaction = filtered[index];
                      return InkWell(
                        onTap: () => _showTransactionActions(transaction),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index == 0 ||
                                !_sameDay(
                                  filtered[index - 1].transactionDate,
                                  transaction.transactionDate,
                                ))
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8, top: 8),
                                child: Text(
                                  DateFormat('EEE, d MMM yyyy')
                                      .format(transaction.transactionDate),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            TransactionTile(
                              transaction: transaction,
                              showExcludedBadge: true,
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
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ActiveFilterPills extends StatelessWidget {
  const _ActiveFilterPills({
    required this.accounts,
    required this.categories,
    required this.accountId,
    required this.categoryId,
    required this.typeFilter,
    required this.startDate,
    required this.endDate,
    required this.onClearAccount,
    required this.onClearCategory,
    required this.onClearType,
    required this.onClearDates,
    required this.onClearAll,
  });

  final List<Account> accounts;
  final List<Category> categories;
  final String? accountId;
  final String? categoryId;
  final TransactionTypeFilter typeFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onClearAccount;
  final VoidCallback onClearCategory;
  final VoidCallback onClearType;
  final VoidCallback onClearDates;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];

    if (accountId != null) {
      final account = accounts.where((a) => a.id == accountId).firstOrNull;
      if (account != null) {
        pills.add(
          _FilterPill(
            label: account.name,
            onRemove: onClearAccount,
          ),
        );
      }
    }

    if (categoryId != null) {
      final category = categories.where((c) => c.id == categoryId).firstOrNull;
      if (category != null) {
        pills.add(
          _FilterPill(
            label: category.name,
            onRemove: onClearCategory,
          ),
        );
      }
    }

    if (typeFilter == TransactionTypeFilter.excluded) {
      pills.add(
        _FilterPill(
          label: 'Excluded',
          onRemove: onClearType,
        ),
      );
    }

    if (startDate != null || endDate != null) {
      final label = _dateRangeLabel(startDate, endDate);
      pills.add(_FilterPill(label: label, onRemove: onClearDates));
    }

    if (pills.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: pills.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == pills.length) {
              return TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear'),
              );
            }
            return pills[index];
          },
        ),
      ),
    );
  }

  String _dateRangeLabel(DateTime? start, DateTime? end) {
    final fmt = DateFormat('d MMM');
    if (start != null && end != null) {
      return '${fmt.format(start)} – ${fmt.format(end)}';
    }
    if (start != null) return 'From ${fmt.format(start)}';
    return 'Until ${fmt.format(end!)}';
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.close,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
