import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
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

  Future<void> _editCategory(Transaction transaction) async {
    final categories = await ref.read(categoriesProvider.future);
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose category')),
            for (final category in categories)
              ListTile(
                title: Text(category.name),
                onTap: () => Navigator.pop(context, category.id),
              ),
          ],
        ),
      ),
    );

    if (selected == null || selected == transaction.categoryId) return;

    final txRepo = await ref.read(transactionRepositoryProvider.future);
    await txRepo.updateCategory(
      transactionId: transaction.id,
      categoryId: selected,
    );
    await (await ref.read(categorizationServiceProvider.future)).learnFromCorrection(
          transaction: transaction,
          categoryId: selected,
        );
    ref.invalidate(transactionsProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(budgetsProvider);
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
                  children: const [SkeletonCard(), SizedBox(height: 16), SkeletonCard()],
                ),
                error: (error, _) => ListView(
                  padding: ViewInsets.listPadding(context),
                  children: [Text('Error: $error')],
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
                        onTap: () => _editCategory(transaction),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index == 0 ||
                                !_sameDay(
                                  filtered[index - 1].transactionDate,
                                  transaction.transactionDate,
                                ))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 8),
                                child: Text(
                                  DateFormat('EEE, d MMM yyyy')
                                      .format(transaction.transactionDate),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            TransactionTile(transaction: transaction),
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
