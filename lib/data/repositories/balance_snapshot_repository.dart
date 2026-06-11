import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/core/services/balance_history_service.dart';

class BalanceSnapshotRepository {
  BalanceSnapshotRepository(this._client);

  final SupabaseClient _client;

  Future<List<BalancePoint>> fetchForAccounts(
    List<String> accountIds,
    DateTime start,
    DateTime end,
  ) async {
    if (accountIds.isEmpty) return const [];

    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;

    final data = await _client
        .from('account_balance_snapshots')
        .select('snapshot_date, balance_pence')
        .inFilter('account_id', accountIds)
        .gte('snapshot_date', startStr)
        .lte('snapshot_date', endStr)
        .order('snapshot_date');

    final byDate = <DateTime, int>{};
    for (final row in (data as List).cast<Map<String, dynamic>>()) {
      final date = DateTime.parse(row['snapshot_date'] as String);
      final day = DateTime(date.year, date.month, date.day);
      byDate[day] = (byDate[day] ?? 0) + (row['balance_pence'] as num).toInt();
    }

    return byDate.entries
        .map((entry) => BalancePoint(date: entry.key, balancePence: entry.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
