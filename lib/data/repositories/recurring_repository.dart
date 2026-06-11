import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/models/recurring_payment.dart';

class RecurringRepository {
  RecurringRepository(this._client);

  final SupabaseClient _client;

  Future<List<RecurringPayment>> fetchAll() async {
    final data = await _client
        .from('recurring_payments')
        .select('*, categories(name)')
        .order('next_date');
    return (data as List).map((e) => RecurringPayment.fromJson(e)).toList();
  }

  Future<RecurringPayment> create(RecurringPayment payment) async {
    final data = await _client
        .from('recurring_payments')
        .insert(payment.toJson())
        .select('*, categories(name)')
        .single();
    return RecurringPayment.fromJson(data);
  }

  Future<RecurringPayment> update(String id, Map<String, dynamic> updates) async {
    final data = await _client
        .from('recurring_payments')
        .update(updates)
        .eq('id', id)
        .select('*, categories(name)')
        .single();
    return RecurringPayment.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('recurring_payments').delete().eq('id', id);
  }
}
