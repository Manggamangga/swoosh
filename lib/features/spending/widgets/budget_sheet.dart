import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/models/budget.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

Future<void> showBudgetSheet(
  BuildContext context,
  WidgetRef ref, {
  required DateTime month,
  String? categoryId,
  String? categoryName,
  Budget? existingBudget,
}) async {
  final categories = await ref.read(categoriesProvider.future);
  final spendCategories =
      categories.where((c) => c.name != 'Income' && c.name != 'Transfer');

  if (!context.mounted) return;

  final isEditing = existingBudget != null;
  var selectedCategoryId = categoryId ?? existingBudget?.categoryId;
  final amountController = TextEditingController(
    text: existingBudget != null
        ? (existingBudget.amountPence / 100).toStringAsFixed(2)
        : '',
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
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
            isEditing ? 'Edit budget' : 'Set budget',
            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (categoryName != null) ...[
            const SizedBox(height: 8),
            Text(
              categoryName,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          if (!isEditing && categoryId == null)
            DropdownButtonFormField<String>(
              initialValue: selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: spendCategories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (value) => selectedCategoryId = value,
            ),
          if (!isEditing && categoryId == null) const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monthly limit'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final resolvedCategoryId =
                  selectedCategoryId ?? existingBudget?.categoryId;
              if (resolvedCategoryId == null) return;

              final repo = ref.read(budgetRepositoryProvider);
              await repo.upsert(
                Budget(
                  id: existingBudget?.id ?? '',
                  userId: existingBudget?.userId ?? '',
                  categoryId: resolvedCategoryId,
                  periodMonth: DateTime(month.year, month.month, 1),
                  amountPence: Money.parseToPence(amountController.text),
                  categoryName: categoryName ?? existingBudget?.categoryName,
                  categoryColor:
                      existingBudget?.categoryColor ?? '#A855F7',
                ),
              );
              ref.invalidate(budgetsProvider);
              ref.invalidate(budgetsForMonthProvider(month));
              ref.invalidate(spendingMonthProvider(month));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Save changes' : 'Save budget'),
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await ref.read(budgetRepositoryProvider).delete(existingBudget.id);
                ref.invalidate(budgetsProvider);
                ref.invalidate(budgetsForMonthProvider(month));
                ref.invalidate(spendingMonthProvider(month));
                ref.invalidate(safeToSpendProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text(
                'Remove budget',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
