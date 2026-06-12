import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/utils/app_snackbar.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/models/account.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key, this.continueImport = false});

  final bool continueImport;

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _balanceController = TextEditingController();
  AccountType _type = AccountType.everyday;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _loading = true);

    try {
      final repo = await ref.read(accountRepositoryProvider.future);
      final balancePence = Money.parseToPence(_balanceController.text);
      final source = widget.continueImport ? DataSource.csv : DataSource.manual;
      final account = await repo.create(
        Account(
          id: '',
          userId: '',
          name: _nameController.text.trim(),
          accountType: _type,
          balancePence: balancePence,
          currency: 'GBP',
          institution: _institutionController.text.trim().isEmpty
              ? null
              : _institutionController.text.trim(),
          source: source,
          balanceAnchorPence: balancePence,
          balanceAnchorDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      ref.invalidate(accountsProvider);
      if (!mounted) return;
      if (widget.continueImport) {
        context.go('/accounts/${account.id}/import');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.continueImport ? 'New account for CSV' : 'Add account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Account name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _institutionController,
            decoration: const InputDecoration(
              labelText: 'Institution (e.g. Barclays, Wise)',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Current balance'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AccountType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Account type'),
            items: AccountType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
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
                : Text(widget.continueImport ? 'Create & import CSV' : 'Save account'),
          ),
        ],
      ),
    );
  }
}
