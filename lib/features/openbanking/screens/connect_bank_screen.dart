import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/models/bank_connection.dart';
import 'package:swoosh/providers/providers.dart';
import 'package:url_launcher/url_launcher.dart';

const _fallbackInstitutions = [
  'Monzo',
  'Barclays',
  'American Express',
];

const _bankCallbackRedirect = 'swoosh://bank-callback';

class ConnectBankScreen extends ConsumerStatefulWidget {
  const ConnectBankScreen({super.key});

  @override
  ConsumerState<ConnectBankScreen> createState() => _ConnectBankScreenState();
}

class _ConnectBankScreenState extends ConsumerState<ConnectBankScreen> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _loading = false;
  bool _loadingInstitutions = true;
  String? _status;
  List<String> _institutions = _fallbackInstitutions;
  String? _syncingConnectionId;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _loadInstitutions();
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

  Future<void> _loadInstitutions() async {
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
        setState(() {
          _institutions = names;
          _loadingInstitutions = false;
        });
      } else if (mounted) {
        setState(() => _loadingInstitutions = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInstitutions = false);
    }
  }

  Future<void> _handleCallback(Uri uri) async {
    if (uri.scheme != 'swoosh' || uri.host != 'bank-callback') return;

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
      final result = await repo.completeConnection(code: code, state: state);
      final connectionId = result['connection_id'] as String? ?? state;
      await _syncConnection(connectionId, showStatus: false);
      ref.invalidate(bankConnectionsProvider);
      setState(() => _status = 'Bank connected. Accounts and transactions synced.');
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(String institutionName) async {
    setState(() {
      _loading = true;
      _status = 'Starting $institutionName connection...';
    });

    try {
      final repo = ref.read(bankConnectionRepositoryProvider);
      final result = await repo.startConnection(
        institutionName: institutionName,
        redirectUrl: _bankCallbackRedirect,
      );
      final url = result['url'] as String?;
      if (url == null) {
        throw Exception('No authorization URL returned');
      }

      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Could not open bank authorization page');
      }

      setState(() => _status = 'Complete sign-in in your browser, then return to Swoosh.');
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
      ref.invalidate(accountRepositoryProvider);
      ref.invalidate(transactionRepositoryProvider);
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

  @override
  Widget build(BuildContext context) {
    final connectionsAsync = ref.watch(bankConnectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect bank')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Connect UK banks via Enable Banking Open Banking. Free for personal use in restricted mode — whitelist your accounts in the Enable Banking portal first. Re-consent required every 90 days.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SwooshCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Before connecting',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  '1. Register a production app at enablebanking.com\n'
                  '2. Activate via "Activate by linking accounts"\n'
                  '3. Whitelist Monzo, Barclays, Amex, etc.\n'
                  '4. Set ENABLE_BANKING_APP_ID and ENABLE_BANKING_PRIVATE_KEY in Supabase secrets',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
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
                                  connection.institutionName ?? 'Bank',
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
            'Add a bank',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (_loadingInstitutions)
            const Center(child: CircularProgressIndicator())
          else
            for (final name in _institutions) ...[
              SwooshCard(
                onTap: _loading ? null : () => _connect(name),
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
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          SwooshCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manual accounts',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Wise and Moneybox can be added manually or via CSV import.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
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
