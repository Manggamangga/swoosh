import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/services/forecast_service.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/theme/fab_location.dart';
import 'package:swoosh/core/utils/money.dart';
import 'package:swoosh/core/widgets/empty_state.dart';
import 'package:swoosh/core/widgets/error_state.dart';
import 'package:swoosh/core/widgets/skeleton_loader.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/goal.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final recurringAsync = ref.watch(recurringProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final forecastService = ref.watch(forecastServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Planning')),
      floatingActionButtonLocation:
          FabAboveNavBarLocation(ViewInsets.bottomClearance(context)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(goalsProvider);
          ref.invalidate(recurringProvider);
          ref.invalidate(accountsProvider);
        },
        child: ListView(
          padding: ViewInsets.listPadding(context, includeFab: true),
          children: [
            Text(
              'Cash-flow forecast',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const SkeletonCard(),
              error: (error, _) => ErrorState(message: error.toString()),
              data: (accounts) => recurringAsync.when(
                skipLoadingOnReload: true,
                loading: () => const SkeletonCard(),
                error: (error, _) => ErrorState(message: error.toString()),
                data: (recurring) {
                  final points = forecastService.forecast(
                    accounts: accounts,
                    recurring: recurring,
                  );
                  return SwooshCard(
                    child: RepaintBoundary(
                      child: _ForecastChart(points: points),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/planning/recurring'),
                child: const Text('Recurring payments'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Savings goals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            goalsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const SkeletonCard(),
              error: (error, _) => ErrorState(message: error.toString()),
              data: (goals) {
                if (goals.isEmpty) {
                  return EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'No goals yet',
                    subtitle: 'Set a savings target with an optional deadline',
                    action: ElevatedButton(
                      onPressed: () => _showGoalSheet(context, ref),
                      child: const Text('Add goal'),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _GoalCard(
                    goal: goals[index],
                    onTap: () => _showGoalSheet(context, ref, existing: goals[index]),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showGoalSheet(
    BuildContext context,
    WidgetRef ref, {
    Goal? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetController = TextEditingController(
      text: existing != null
          ? Money.format(existing.targetAmountPence)
          : '',
    );
    final currentController = TextEditingController(
      text: existing != null
          ? Money.format(existing.currentAmountPence)
          : '',
    );
    DateTime? targetDate = existing?.targetDate;

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
                existing == null ? 'Add savings goal' : 'Edit savings goal',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Goal name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Target amount'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: currentController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Current amount'),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Target date (optional)'),
                subtitle: Text(
                  targetDate == null
                      ? 'No deadline'
                      : '${targetDate!.day}/${targetDate!.month}/${targetDate!.year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: targetDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) {
                    setSheetState(() => targetDate = picked);
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final userId = ref.read(supabaseProvider).auth.currentUser!.id;
                  final repo = ref.read(goalRepositoryProvider);
                  final payload = {
                    'name': nameController.text.trim(),
                    'target_amount_pence':
                        Money.parseToPence(targetController.text),
                    'current_amount_pence':
                        Money.parseToPence(currentController.text),
                    'target_date': targetDate?.toIso8601String().split('T').first,
                  };

                  if (existing == null) {
                    await repo.create(
                      Goal(
                        id: '',
                        userId: userId,
                        name: payload['name'] as String,
                        targetAmountPence: payload['target_amount_pence'] as int,
                        currentAmountPence: payload['current_amount_pence'] as int,
                        currency: 'GBP',
                        targetDate: targetDate,
                      ),
                    );
                  } else {
                    await repo.update(existing.id, payload);
                  }
                  ref.invalidate(goalsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Save goal' : 'Save changes'),
              ),
              if (existing != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(goalRepositoryProvider).delete(existing.id);
                    ref.invalidate(goalsProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Delete goal',
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

class _ForecastChart extends StatelessWidget {
  const _ForecastChart({required this.points});

  final List<ForecastPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Add accounts and recurring payments')),
      );
    }

    final sampled = _sample(points, 30);
    final spots = sampled
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.balancePence / 100))
        .toList();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.forecast,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.forecast.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  List<ForecastPoint> _sample(List<ForecastPoint> all, int maxPoints) {
    if (all.length <= maxPoints) return all;
    final step = all.length / maxPoints;
    return List.generate(
      maxPoints,
      (i) => all[(i * step).floor()],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SwooshCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            '${Money.format(goal.currentAmountPence)} / ${Money.format(goal.targetAmountPence)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.forecast,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.forecast,
            ),
          ),
          if (goal.targetDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Target: ${goal.targetDate!.day}/${goal.targetDate!.month}/${goal.targetDate!.year}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
