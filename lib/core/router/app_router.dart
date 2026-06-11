import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/features/accounts/screens/account_detail_screen.dart';
import 'package:swoosh/features/accounts/screens/accounts_screen.dart';
import 'package:swoosh/features/accounts/screens/add_account_screen.dart';
import 'package:swoosh/features/accounts/screens/add_transaction_screen.dart';
import 'package:swoosh/features/accounts/screens/csv_import_screen.dart';
import 'package:swoosh/core/config/env.dart';
import 'package:swoosh/features/auth/screens/login_screen.dart';
import 'package:swoosh/features/auth/screens/unlock_screen.dart';
import 'package:swoosh/features/spending/screens/spending_screen.dart';
import 'package:swoosh/features/home/screens/home_screen.dart';
import 'package:swoosh/features/openbanking/screens/connect_bank_screen.dart';
import 'package:swoosh/features/planning/screens/planning_screen.dart';
import 'package:swoosh/features/recurring/screens/recurring_screen.dart';
import 'package:swoosh/features/shell/app_shell.dart';
import 'package:swoosh/features/settings/screens/settings_screen.dart';
import 'package:swoosh/features/transactions/screens/transactions_screen.dart';
import 'package:swoosh/providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final isUnlocked = ref.watch(isUnlockedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (Env.skipAuth) return null;

      final session = authState.valueOrNull?.session;
      final isLoggingIn = state.matchedLocation == '/login';
      final isUnlocking = state.matchedLocation == '/unlock';

      if (session == null) return isLoggingIn ? null : '/login';
      if (!isUnlocked && !isUnlocking) return '/unlock';
      if (isUnlocked && (isLoggingIn || isUnlocking)) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/unlock', builder: (_, __) => const UnlockScreen()),
      GoRoute(
        path: '/budgets',
        redirect: (_, __) => '/spending',
      ),
      GoRoute(
        path: '/recurring',
        redirect: (_, __) => '/planning/recurring',
      ),
      StatefulShellRoute(
        builder: (_, __, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        navigatorContainerBuilder: (_, navigationShell, children) {
          return AnimatedBranchStack(
            currentIndex: navigationShell.currentIndex,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                builder: (_, __) => const AccountsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/spending',
                builder: (_, __) => const SpendingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/planning',
                builder: (_, __) => const PlanningScreen(),
                routes: [
                  GoRoute(
                    path: 'recurring',
                    builder: (_, __) => const RecurringScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/accounts/add',
        builder: (_, state) => AddAccountScreen(
          continueImport: state.uri.queryParameters['continueImport'] == '1',
        ),
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (_, state) => AccountDetailScreen(
          accountId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/accounts/:id/add-tx',
        builder: (_, state) => AddTransactionScreen(
          accountId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/accounts/:id/import',
        builder: (_, state) => CsvImportScreen(
          accountId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/connect-bank',
        builder: (_, __) => const ConnectBankScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (_, state) => TransactionsScreen(
          initialCategoryId: state.uri.queryParameters['category'],
        ),
      ),
    ],
  );
});
