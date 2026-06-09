import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/models/goal.dart';

class GoalRepository {
  GoalRepository(this._client);

  final SupabaseClient _client;

  Future<List<Goal>> fetchAll() async {
    final data = await _client
        .from('goals')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => Goal.fromJson(e)).toList();
  }

  Future<Goal> create(Goal goal) async {
    final data = await _client
        .from('goals')
        .insert(goal.toJson())
        .select()
        .single();
    return Goal.fromJson(data);
  }

  Future<Goal> update(String id, Map<String, dynamic> updates) async {
    final data = await _client
        .from('goals')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Goal.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('goals').delete().eq('id', id);
  }
}
