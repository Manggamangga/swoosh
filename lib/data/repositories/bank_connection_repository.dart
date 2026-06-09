import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/models/bank_connection.dart';

class BankConnectionRepository {
  BankConnectionRepository(this._client);

  final SupabaseClient _client;

  Future<List<BankConnection>> fetchAll() async {
    final data = await _client
        .from('bank_connections')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => BankConnection.fromJson(e)).toList();
  }

  Future<BankConnection> create(Map<String, dynamic> data) async {
    final result = await _client
        .from('bank_connections')
        .insert(data)
        .select()
        .single();
    return BankConnection.fromJson(result);
  }

  Future<Map<String, dynamic>> startConnection({
    required String institutionId,
    required String institutionName,
    required String redirectUrl,
  }) async {
    final response = await _client.functions.invoke(
      'gocardless-connect',
      body: {
        'institution_id': institutionId,
        'institution_name': institutionName,
        'redirect_url': redirectUrl,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncConnection(String connectionId) async {
    final response = await _client.functions.invoke(
      'gocardless-sync',
      body: {'connection_id': connectionId},
    );
    return response.data as Map<String, dynamic>;
  }
}
