import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/category_icon.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/budget.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudget(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(budgetsProvider),
        child: budgetsAsync.when(
          loading: () => ListView(
            padding: ViewInsets.listPadding(context, includeFab: true),
            children: const [SkeletonCard(), SizedBox(height: 16), SkeletonCard()],
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (budgets) {
            if (budgets.isEmpty) {
              return EmptyState(
                icon: Icons.pie_chart_outline,
                title: 'No budgets yet',
                subtitle: 'Set monthly spending limits by category',
                action: ElevatedButton(
                  onPressed: () => _showAddBudget(context, ref),
                  child: const Text('Set up budget'),
                ),
              );
            }
            return ListView.builder(
              padding: ViewInsets.listPadding(context, includeFab: true),
              itemCount: budgets.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(bottom: index == budgets.length - 1 ? 0 : 12),
                child: _BudgetCard(
                  budget: budgets[index],
                  onTap: () => context.push(
                    '/transactions?category=${budgets[index].categoryId}',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddBudget(BuildContext context, WidgetRef ref) async {
    final categories = await ref.read(categoriesProvider.future);
    final spendCategories =
        categories.where((c) => c.name != 'Income' && c.name != 'Transfer');

    if (!context.mounted) return;

    String? categoryId = spendCategories.firstOrNull?.id;
    final amountController = TextEditingController();

    await showModalBottomSheet(
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
              'Add budget',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: spendCategories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => categoryId = v,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly limit',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (categoryId == null) return;
                final now = DateTime.now();
                final repo = ref.read(budgetRepositoryProvider);
                await repo.upsert(
                  Budget(
                    id: '',
                    userId: '',
                    categoryId: categoryId!,
                    periodMonth: DateTime(now.year, now.month, 1),
                    amountPence: Money.parseToPence(amountController.text),
                  ),
                );
                ref.invalidate(budgetsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save budget'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, this.onTap});

  final Budget budget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = budget.progress.clamp(0.0, 1.0);
    final color = budget.isOverBudget ? AppColors.error : AppColors.primary;

    return SwooshCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIcon(
                iconName: 'category',
                color: budget.categoryColor ?? '#a855f7',
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  budget.categoryName ?? 'Category',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${Money.format(budget.spentPence)} / ${Money.format(budget.amountPence)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
