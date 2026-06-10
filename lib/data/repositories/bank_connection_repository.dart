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

  Future<List<Map<String, dynamic>>> fetchInstitutions({String country = 'GB'}) async {
    final response = await _client.functions.invoke(
      'enable-banking-connect',
      body: {'action': 'aspsps', 'country': country},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['aspsps'] as List? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> startConnection({
    required String institutionName,
    required String redirectUrl,
  }) async {
    final response = await _client.functions.invoke(
      'enable-banking-connect',
      body: {
        'action': 'start',
        'institution_name': institutionName,
        'redirect_url': redirectUrl,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeConnection({
    required String code,
    required String state,
  }) async {
    final response = await _client.functions.invoke(
      'enable-banking-connect',
      body: {
        'action': 'complete',
        'code': code,
        'state': state,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncConnection(String connectionId) async {
    final response = await _client.functions.invoke(
      'enable-banking-sync',
      body: {'connection_id': connectionId},
    );
    return response.data as Map<String, dynamic>;
  }
}
