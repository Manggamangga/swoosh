import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/utils/dedupe.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/features/accounts/screens/account_detail_screen.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/models/transaction.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _categoryId;
  bool _isExpense = true;
  bool _loading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_descriptionController.text.trim().isEmpty) return;
    setState(() => _loading = true);

    try {
      final repo = await ref.read(transactionRepositoryProvider.future);
      var amountPence = Money.parseToPence(_amountController.text);
      if (_isExpense && amountPence > 0) amountPence = -amountPence;

      final hash = buildDedupeHash(
        accountId: widget.accountId,
        date: _date,
        amountPence: amountPence,
        description: _descriptionController.text.trim(),
      );

      await repo.create(
        Transaction(
          id: '',
          userId: '',
          accountId: widget.accountId,
          transactionDate: _date,
          amountPence: amountPence,
          currency: 'GBP',
          description: _descriptionController.text.trim(),
          merchant: _descriptionController.text.trim(),
          categoryId: _categoryId,
          source: DataSource.manual,
          dedupeHash: hash,
          excludeFromAnalytics: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      ref.invalidate(transactionsProvider);
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(accountTransactionsProvider(widget.accountId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Expense')),
              ButtonSegment(value: false, label: Text('Income')),
            ],
            selected: {_isExpense},
            onSelectionChanged: (s) => setState(() => _isExpense = s.first),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date'),
            subtitle: Text(
              '${_date.day}/${_date.month}/${_date.year}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 16),
          categoriesAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (categories) => DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: null, child: Text('General')),
                ...categories.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save transaction'),
          ),
        ],
      ),
    );
  }
}
