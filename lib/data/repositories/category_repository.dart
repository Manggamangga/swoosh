import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/models/category.dart';

class CategoryRepository {
  CategoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Category>> fetchAll() async {
    final data = await _client
        .from('categories')
        .select()
        .order('name');
    return (data as List).map((e) => Category.fromJson(e)).toList();
  }

  Future<void> seedDefaults() async {
    await _client.rpc('seed_default_categories', params: {
      'p_user_id': _client.auth.currentUser!.id,
    });
  }
}
