import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/error_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/transaction_tile.dart';
import 'package:swoosh/models/category.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _selectedCategoryId;
  String _search = '';
  bool _categorizing = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runRetroactiveOnce());
  }

  Future<void> _runRetroactiveOnce() async {
    if (_categorizing) return;
    setState(() => _categorizing = true);
    try {
      final service = await ref.read(categorizationServiceProvider.future);
      final updated = await service.retroactivelyCategorize();
      if (updated > 0) {
        ref.invalidate(transactionsProvider);
        ref.invalidate(allTransactionsProvider);
      }
    } catch (_) {}
    if (mounted) setState(() => _categorizing = false);
  }

  List<Transaction> _filter(List<Transaction> transactions) {
    final query = _search.trim().toLowerCase();
    return transactions.where((transaction) {
      if (_selectedCategoryId != null &&
          transaction.categoryId != _selectedCategoryId) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack =
          '${transaction.merchant ?? ''} ${transaction.description}'.toLowerCase();
      return haystack.contains(query);
    }).toList();
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
    final now = DateTime.now();
    ref.invalidate(spendingMonthProvider(DateTime(now.year, now.month, 1)));
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search merchants or descriptions',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) => _CategoryChips(
              categories: categories,
              selectedCategoryId: _selectedCategoryId,
              onSelected: (categoryId) =>
                  setState(() => _selectedCategoryId = categoryId),
            ),
          ),
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
                          subtitle: 'Try another category or search term',
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

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = selectedCategoryId == null;
            return FilterChip(
              label: const Text('All'),
              selected: selected,
              onSelected: (_) => onSelected(null),
            );
          }
          final category = categories[index - 1];
          final selected = selectedCategoryId == category.id;
          return FilterChip(
            label: Text(category.name),
            selected: selected,
            onSelected: (_) => onSelected(category.id),
          );
        },
      ),
    );
  }
}
