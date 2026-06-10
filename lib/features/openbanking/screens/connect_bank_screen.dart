import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/config/env.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/features/openbanking/widgets/bank_auth_webview.dart';
import 'package:swoosh/models/bank_connection.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/providers.dart';

const _fallbackInstitutions = [
  'Barclays',
  'HSBC',
];

Uri get _bankCallbackUri =>
    Uri.parse('${Env.supabaseUrl}/functions/v1/bank-callback');

String get _bankCallbackRedirect => _bankCallbackUri.toString();

bool _isBankCallback(Uri uri) {
  if (uri.scheme == 'swoosh' && uri.host == 'bank-callback') return true;
  return uri.scheme == 'https' &&
      uri.host == _bankCallbackUri.host &&
      uri.path == _bankCallbackUri.path;
}

class ConnectBankScreen extends ConsumerStatefulWidget {
  const ConnectBankScreen({super.key});

  @override
  ConsumerState<ConnectBankScreen> createState() => _ConnectBankScreenState();
}

class _ConnectBankScreenState extends ConsumerState<ConnectBankScreen> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _loading = false;
  bool _loadingInstitutions = false;
  bool _enableBankingExpanded = false;
  String? _status;
  List<String> _institutions = _fallbackInstitutions;
  String? _syncingConnectionId;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      await _handleCallback(initial);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(_handleCallback);
  }

  Future<void> _loadEnableBankingInstitutions() async {
    if (_institutions.length > _fallbackInstitutions.length) return;
    setState(() => _loadingInstitutions = true);
    try {
      final repo = ref.read(bankConnectionRepositoryProvider);
      final aspsps = await repo.fetchInstitutions();
      final names = aspsps
          .map((e) => e['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (names.isNotEmpty && mounted) {
        setState(() => _institutions = names);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingInstitutions = false);
  }

  Future<void> _handleCallback(Uri uri) async {
    if (!_isBankCallback(uri)) return;
    await _processOAuthCallback(uri);
  }

  Future<void> _processOAuthCallback(Uri uri) async {
    final error = uri.queryParameters['error'];
    if (error != null) {
      setState(() => _status = 'Bank connection failed: $error');
      return;
    }

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code == null || state == null) {
      setState(() => _status = 'Bank callback missing code or state.');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Completing bank connection...';
    });

    try {
      final repo = ref.read(bankConnectionRepositoryProvider);
      final result = await repo.completeConnection(
        code: code,
        state: state,
        redirectUrl: _bankCallbackRedirect,
      );
      final connectionId = result['connection_id'] as String? ?? state;
      if (result['approve_in_app'] == true) {
        setState(() => _status = 'Approve access in your Monzo app, then syncing...');
      }
      await _syncConnection(connectionId, showStatus: false);
      ref.invalidate(bankConnectionsProvider);
      setState(() => _status = 'Bank connected. Accounts and transactions synced.');
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _authenticateInBrowser(String authUrl) {
    return BankAuthWebView.open(
      context,
      authUrl: authUrl,
      callbackUri: _bankCallbackUri,
    );
  }

  Future<void> _resumeFromCallbackUrl() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final controller = TextEditingController(text: clipboard?.text ?? '');

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resume bank connection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Paste bank-callback URL from your browser',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty || !mounted) return;

    final uri = Uri.tryParse(url);
    if (uri == null || !_isBankCallback(uri)) {
      setState(() => _status = 'That does not look like a bank callback URL.');
      return;
    }

    await _processOAuthCallback(uri);
  }

  Future<void> _connectMonzo() async {
    setState(() {
      _loading = true;
      _status = 'Starting Monzo connection...';
    });

    try {
      final repo = ref.read(bankConnectionRepositoryProvider);
      final result = await repo.startMonzoConnection(
        redirectUrl: _bankCallbackRedirect,
      );
      final url = result['url'] as String?;
      if (url == null) {
        throw Exception('No authorization URL returned');
      }

      if (mounted) setState(() => _loading = false);
      setState(() => _status = 'Sign in with Monzo, then approve access in the Monzo app.');

      if (!mounted) return;
      final callbackUrl = await _authenticateInBrowser(url);
      if (callbackUrl == null) {
        setState(() => _status = 'Monzo connection cancelled.');
        return;
      }
      await _processOAuthCallback(Uri.parse(callbackUrl));
      ref.invalidate(bankConnectionsProvider);
    } catch (e) {
      setState(() => _status = 'Failed: $e. Set MONZO_CLIENT_ID and MONZO_CLIENT_SECRET in Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectEnableBanking(String institutionName) async {
    setState(() {
      _loading = true;
      _status = 'Starting $institutionName connection...';
    });

    try {
      final repo = ref.read(bankConnectionRepositoryProvider);
      final result = await repo.startEnableBankingConnection(
        institutionName: institutionName,
        redirectUrl: _bankCallbackRedirect,
      );
      final url = result['url'] as String?;
      if (url == null) {
        throw Exception('No authorization URL returned');
      }

      if (mounted) setState(() => _loading = false);
      setState(() => _status = 'Complete sign-in in your browser.');

      if (!mounted) return;
      final callbackUrl = await _authenticateInBrowser(url);
      if (callbackUrl == null) {
        setState(() => _status = 'Bank connection cancelled.');
        return;
      }
      await _processOAuthCallback(Uri.parse(callbackUrl));
      ref.invalidate(bankConnectionsProvider);
    } catch (e) {
      setState(() => _status = 'Failed: $e. Ensure Enable Banking secrets are set in Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncConnection(String connectionId, {bool showStatus = true}) async {
    setState(() {
      _syncingConnectionId = connectionId;
      if (showStatus) _status = 'Syncing accounts and transactions...';
    });

    try {
      final repo = ref.read(bankConnectionRepositoryProvider);
      final result = await repo.syncConnection(connectionId);
      final accounts = result['accounts_synced'] ?? 0;
      final transactions = result['transactions_synced'] ?? 0;
      if (showStatus) {
        setState(() => _status = 'Synced $accounts account(s), $transactions transaction(s).');
      }
      ref.invalidate(bankConnectionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider);
    } catch (e) {
      if (showStatus) setState(() => _status = 'Sync failed: $e');
      rethrow;
    } finally {
      if (mounted) setState(() => _syncingConnectionId = null);
    }
  }

  String _statusLabel(ConnectionStatus status) {
    return switch (status) {
      ConnectionStatus.pending => 'Pending',
      ConnectionStatus.active => 'Active',
      ConnectionStatus.expired => 'Expired',
      ConnectionStatus.revoked => 'Revoked',
    };
  }

  String _connectionLabel(BankConnection connection) {
    if (connection.provider == 'monzo') return 'Monzo';
    return connection.institutionName ?? 'Bank';
  }

  @override
  Widget build(BuildContext context) {
    final connectionsAsync = ref.watch(bankConnectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect bank')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Connect Monzo automatically, or import Barclays, Amex, Wise, and Moneybox via CSV.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          connectionsAsync.when(
            data: (connections) {
              if (connections.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your connections',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  for (final connection in connections) ...[
                    SwooshCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _connectionLabel(connection),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _statusLabel(connection.status),
                                  style: TextStyle(
                                    color: connection.needsReauth
                                        ? AppColors.spending
                                        : AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (connection.status == ConnectionStatus.active)
                            TextButton(
                              onPressed: _syncingConnectionId == connection.id
                                  ? null
                                  : () => _syncConnection(connection.id),
                              child: _syncingConnectionId == connection.id
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Sync'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Text(
            'Automatic sync',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          SwooshCard(
            onTap: _loading ? null : _connectMonzo,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monzo',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Direct API — balances and transactions',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwooshCard(
            onTap: () => context.push('/accounts'),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.everyday.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_file, color: AppColors.everyday),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import CSV',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Barclays, Amex, Wise, Moneybox — add account, then import from account screen',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SwooshCard(
            onTap: () {
              setState(() => _enableBankingExpanded = !_enableBankingExpanded);
              if (_enableBankingExpanded) _loadEnableBankingInstitutions();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Enable Banking (limited UK coverage)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(
                      _enableBankingExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                if (_enableBankingExpanded) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Requires whitelisting accounts in the Enable Banking portal. UK bank availability is limited — use Monzo or CSV instead.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingInstitutions)
                    const Center(child: CircularProgressIndicator())
                  else
                    for (final name in _institutions) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(name),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: _loading ? null : () => _connectEnableBanking(name),
                      ),
                    ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : _resumeFromCallbackUrl,
            child: const Text('Stuck in browser? Paste callback URL'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 20),
            Text(_status!, style: const TextStyle(fontSize: 13)),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
