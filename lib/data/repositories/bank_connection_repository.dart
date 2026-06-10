import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/models/bank_connection.dart';

const _safeConnectionColumns =
    'id, user_id, provider, institution_id, institution_name, '
    'requisition_id, status, expires_at, created_at';

class BankConnectionRepository {
  BankConnectionRepository(this._client);

  final SupabaseClient _client;

  Future<List<BankConnection>> fetchAll() async {
    final data = await _client
        .from('bank_connections')
        .select(_safeConnectionColumns)
        .order('created_at', ascending: false);
    return (data as List).map((e) => BankConnection.fromJson(e)).toList();
  }

  Future<BankConnection> create(Map<String, dynamic> data) async {
    final result = await _client
        .from('bank_connections')
        .insert(data)
        .select(_safeConnectionColumns)
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

  Future<Map<String, dynamic>> startMonzoConnection({
    required String redirectUrl,
  }) async {
    final response = await _client.functions.invoke(
      'monzo-connect',
      body: {
        'action': 'start',
        'redirect_url': redirectUrl,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startEnableBankingConnection({
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
    required String redirectUrl,
  }) async {
    final provider = await _providerForConnection(state);
    if (provider == 'monzo') {
      final response = await _client.functions.invoke(
        'monzo-connect',
        body: {
          'action': 'complete',
          'code': code,
          'state': state,
          'redirect_url': redirectUrl,
        },
      );
      return response.data as Map<String, dynamic>;
    }

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
    final provider = await _providerForConnection(connectionId);
    final functionName = provider == 'monzo' ? 'monzo-sync' : 'enable-banking-sync';
    final response = await _client.functions.invoke(
      functionName,
      body: {'connection_id': connectionId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<String> _providerForConnection(String connectionId) async {
    final result = await _client
        .from('bank_connections')
        .select('provider')
        .eq('id', connectionId)
        .single();
    return result['provider'] as String? ?? 'enable_banking';
  }
}
