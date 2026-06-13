import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/core/config/env.dart';
import 'package:swoosh/core/theme/app_colors.dart';
import 'package:swoosh/core/utils/view_insets.dart';
import 'package:swoosh/core/widgets/swoosh_card.dart';
import 'package:swoosh/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(supabaseProvider).auth.currentUser;
    final isUnlocked = ref.watch(isUnlockedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: ViewInsets.listPadding(context),
        children: [
          SwooshCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? 'Not signed in',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SwooshCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Biometric unlock'),
              subtitle: Text(
                Env.skipAuth
                    ? 'Available when auth is enabled'
                    : isUnlocked
                        ? 'Enabled for this session'
                        : 'Lock app on next launch',
              ),
              value: !Env.skipAuth && isUnlocked,
              onChanged: Env.skipAuth
                  ? null
                  : (value) {
                      ref.read(isUnlockedProvider.notifier).state = value;
                    },
            ),
          ),
          const SizedBox(height: 12),
          if (!Env.skipAuth)
            SwooshCard(
              onTap: () async {
                final cache = await ref.read(localCacheProvider.future);
                await cache.clear();
                await ref.read(supabaseProvider).auth.signOut();
                ref.read(isUnlockedProvider.notifier).state = false;
                if (context.mounted) context.go('/login');
              },
              child: const Row(
                children: [
                  Icon(Icons.logout, color: AppColors.error),
                  SizedBox(width: 14),
                  Text(
                    'Sign out',
                    style: TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
