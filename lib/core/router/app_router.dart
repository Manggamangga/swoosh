import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/features/accounts/screens/account_detail_screen.dart';
import 'package:swoosh/features/accounts/screens/accounts_screen.dart';
import 'package:swoosh/features/accounts/screens/add_account_screen.dart';
import 'package:swoosh/features/accounts/screens/add_transaction_screen.dart';
import 'package:swoosh/features/accounts/screens/csv_import_screen.dart';
import 'package:swoosh/features/accounts/screens/transfer_screen.dart';
import 'package:swoosh/features/auth/screens/login_screen.dart';
import 'package:swoosh/features/auth/screens/unlock_screen.dart';
import 'package:swoosh/features/budgets/screens/budgets_screen.dart';
import 'package:swoosh/features/home/screens/home_screen.dart';
import 'package:swoosh/features/openbanking/screens/connect_bank_screen.dart';
import 'package:swoosh/features/planning/screens/planning_screen.dart';
import 'package:swoosh/features/recurring/screens/recurring_screen.dart';
import 'package:swoosh/features/shell/app_shell.dart';
import 'package:swoosh/providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final isUnlocked = ref.watch(isUnlockedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
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
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/accounts', builder: (_, __) => const AccountsScreen()),
          GoRoute(path: '/budgets', builder: (_, __) => const BudgetsScreen()),
          GoRoute(path: '/planning', builder: (_, __) => const PlanningScreen()),
          GoRoute(
            path: '/recurring',
            builder: (_, __) => const RecurringScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/accounts/add',
        builder: (_, __) => const AddAccountScreen(),
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
        path: '/accounts/:id/transfer',
        builder: (_, state) => TransferScreen(
          fromAccountId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/connect-bank',
        builder: (_, __) => const ConnectBankScreen(),
      ),
    ],
  );
});
