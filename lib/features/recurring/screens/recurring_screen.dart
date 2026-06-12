import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/app_snackbar.dart';
import 'package:swoosh/core/theme/fab_location.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/error_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/recurring_payment.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Auto-detect',
            onPressed: () => _autoDetect(context, ref),
          ),
        ],
      ),
      floatingActionButtonLocation:
          FabAboveNavBarLocation(ViewInsets.bottomClearance(context)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecurring(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recurringProvider),
        child: recurringAsync.when(
          skipLoadingOnReload: true,
          loading: () => ListView(
            padding: ViewInsets.listPadding(context, includeFab: true),
            children: const [SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
          ),
          error: (error, _) => ErrorState(message: error.toString()),
          data: (payments) {
            if (payments.isEmpty) {
              return ListView(
                padding: ViewInsets.listPadding(context),
                children: [
                  EmptyState(
                    icon: Icons.event_repeat,
                    title: 'No recurring payments',
                    subtitle:
                        'Track rent, subscriptions, salary, and regular bills',
                    action: ElevatedButton(
                      onPressed: () => _showAddRecurring(context, ref),
                      child: const Text('Add recurring payment'),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: ViewInsets.listPadding(context, includeFab: true),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final payment = payments[index];
                return Padding(
                  padding:
                      EdgeInsets.only(bottom: index == payments.length - 1 ? 0 : 12),
                  child: SwooshCard(
                    onTap: () => _showEditRecurring(context, ref, payment),
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
                                '${payment.cadence.name} · Next ${payment.nextDate.day}/${payment.nextDate.month}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              if (payment.amountPence > 0)
                                const Text(
                                  'Expected income',
                                  style: TextStyle(
                                    color: AppColors.income,
                                    fontSize: 12,
                                  ),
                                ),
                              if (payment.autoDetected)
                                const Text(
                                  'Auto-detected',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          Money.formatSigned(payment.amountPence),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: payment.amountPence > 0
                                ? AppColors.income
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _autoDetect(BuildContext context, WidgetRef ref) async {
    final transactions = await ref.read(transactionsProvider.future);
    final userId = ref.read(supabaseProvider).auth.currentUser!.id;
    final detector = ref.read(recurringDetectionServiceProvider);
    final detected = detector.detect(userId: userId, transactions: transactions);
    final repo = ref.read(recurringRepositoryProvider);

    for (final payment in detected) {
      await repo.create(payment);
    }

    ref.invalidate(recurringProvider);
    ref.invalidate(safeToSpendProvider);
    if (context.mounted) {
      showAppSnackBar(context, 'Detected ${detected.length} recurring payments');
    }
  }

  Future<void> _showAddRecurring(BuildContext context, WidgetRef ref) {
    return _showRecurringSheet(context, ref);
  }

  Future<void> _showEditRecurring(
    BuildContext context,
    WidgetRef ref,
    RecurringPayment payment,
  ) {
    return _showRecurringSheet(context, ref, existing: payment);
  }

  Future<void> _showRecurringSheet(
    BuildContext context,
    WidgetRef ref, {
    RecurringPayment? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final amountController = TextEditingController(
      text: existing != null
          ? Money.format(existing.amountPence.abs())
          : '',
    );
    RecurringCadence cadence = existing?.cadence ?? RecurringCadence.monthly;
    var isIncome = (existing?.amountPence ?? 0) > 0;
    var nextDate = existing?.nextDate ?? DateTime.now();

    await showModalBottomSheet(
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
                existing == null ? 'Add recurring payment' : 'Edit recurring payment',
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
                subtitle: Text('${nextDate.day}/${nextDate.month}/${nextDate.year}'),
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
                  final userId = ref.read(supabaseProvider).auth.currentUser!.id;
                  final repo = ref.read(recurringRepositoryProvider);
                  var amount = Money.parseToPence(amountController.text);
                  if (!isIncome && amount > 0) amount = -amount;
                  if (isIncome && amount < 0) amount = -amount;

                  if (existing == null) {
                    await repo.create(
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
                  } else {
                    await repo.update(existing.id, {
                      'name': nameController.text.trim(),
                      'amount_pence': amount,
                      'cadence': cadence.name,
                      'next_date': nextDate.toIso8601String().split('T').first,
                    });
                  }

                  ref.invalidate(recurringProvider);
                  ref.invalidate(safeToSpendProvider);
                  ref.invalidate(upcomingRecurringProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Save' : 'Save changes'),
              ),
              if (existing != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(recurringRepositoryProvider)
                        .delete(existing.id);
                    ref.invalidate(recurringProvider);
                    ref.invalidate(safeToSpendProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
