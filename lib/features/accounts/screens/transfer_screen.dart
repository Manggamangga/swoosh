import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key, required this.fromAccountId});

  final String fromAccountId;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController(text: 'Transfer');
  String? _toAccountId;
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_toAccountId == null || _amountController.text.isEmpty) return;
    setState(() => _loading = true);

    try {
      final repo = await ref.read(transactionRepositoryProvider.future);
      final amount = Money.parseToPence(_amountController.text);
      await repo.createTransfer(
        fromAccountId: widget.fromAccountId,
        toAccountId: _toAccountId!,
        amountPence: amount,
        date: DateTime.now(),
        description: _descriptionController.text.trim(),
      );
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          final targets =
              accounts.where((a) => a.id != widget.fromAccountId).toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Move money between your own accounts. Excluded from spending analytics.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _toAccountId,
                decoration: const InputDecoration(labelText: 'To account'),
                items: targets
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _toAccountId = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
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
                    : const Text('Transfer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
