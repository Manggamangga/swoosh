import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/providers/providers.dart';

const _ukInstitutions = [
  ('MONZO_MONZO', 'Monzo'),
  ('BARCLAYS_BARCLAYS', 'Barclays'),
  ('AMEX_AMEX', 'American Express'),
];

class ConnectBankScreen extends ConsumerStatefulWidget {
  const ConnectBankScreen({super.key});

  @override
  ConsumerState<ConnectBankScreen> createState() => _ConnectBankScreenState();
}

class _ConnectBankScreenState extends ConsumerState<ConnectBankScreen> {
  bool _loading = false;
  String? _status;

  Future<void> _connect(String institutionId, String name) async {
    setState(() {
      _loading = true;
      _status = 'Connecting to $name...';
    });

    try {
      final repo = ref.read(bankConnectionRepositoryProvider);
      final result = await repo.startConnection(
        institutionId: institutionId,
        institutionName: name,
        redirectUrl: 'swoosh://bank-callback',
      );
      setState(() => _status = 'Connection started. Link: ${result['link']}');
    } catch (e) {
      setState(() => _status = 'Failed: $e. Ensure GoCardless secrets are set in Supabase Edge Functions.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect bank')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Connect your UK bank via GoCardless Open Banking. Free for personal use. Re-consent required every 90 days.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          for (final (id, name) in _ukInstitutions) ...[
            SwooshCard(
              onTap: _loading ? null : () => _connect(id, name),
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
