import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRecurring(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recurringProvider),
        child: recurringAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (payments) {
            if (payments.isEmpty) {
              return EmptyState(
                icon: Icons.event_repeat,
                title: 'No recurring payments',
                subtitle: 'Track rent, subscriptions, and regular bills',
                action: ElevatedButton(
                  onPressed: () => _showAddRecurring(context, ref),
                  child: const Text('Add recurring payment'),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final payment in payments) ...[
                  SwooshCard(
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
                          Money.format(payment.amountPence),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 80),
              ],
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detected ${detected.length} recurring payments')),
      );
    }
  }

  Future<void> _showAddRecurring(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    RecurringCadence cadence = RecurringCadence.monthly;

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
              'Add recurring payment',
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
            DropdownButtonFormField<RecurringCadence>(
              value: cadence,
              decoration: const InputDecoration(labelText: 'Cadence'),
              items: RecurringCadence.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => cadence = v!,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final userId = ref.read(supabaseProvider).auth.currentUser!.id;
                final repo = ref.read(recurringRepositoryProvider);
                var amount = Money.parseToPence(amountController.text);
                if (amount > 0) amount = -amount;
                await repo.create(
                  RecurringPayment(
                    id: '',
                    userId: userId,
                    name: nameController.text.trim(),
                    amountPence: amount,
                    currency: 'GBP',
                    cadence: cadence,
                    nextDate: DateTime.now(),
                    autoDetected: false,
                  ),
                );
                ref.invalidate(recurringProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
