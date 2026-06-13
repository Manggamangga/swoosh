import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swoosh/features/accounts/screens/account_detail_screen.dart';
import 'package:swoosh/features/accounts/screens/accounts_screen.dart';
import 'package:swoosh/core/config/env.dart';
import 'package:swoosh/features/auth/screens/login_screen.dart';
import 'package:swoosh/features/auth/screens/unlock_screen.dart';
import 'package:swoosh/features/onboarding/screens/welcome_screen.dart';
import 'package:swoosh/features/spending/screens/spending_screen.dart';
import 'package:swoosh/features/home/screens/home_screen.dart';
import 'package:swoosh/features/insights/screens/insights_screen.dart';
import 'package:swoosh/features/shell/app_shell.dart';
import 'package:swoosh/features/settings/screens/settings_screen.dart';
import 'package:swoosh/features/transactions/screens/transactions_screen.dart';
import 'package:swoosh/providers/data_providers.dart';
import 'package:swoosh/providers/onboarding_provider.dart';
import 'package:swoosh/providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final isUnlocked = ref.watch(isUnlockedProvider);
  final accountsAsync = ref.watch(accountsProvider);
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (Env.skipAuth) {
        final accounts = accountsAsync.valueOrNull;
        final onWelcome = state.matchedLocation == '/welcome';
        if (accounts != null &&
            accounts.isEmpty &&
            !onboardingCompleted &&
            !onWelcome) {
          return '/welcome';
        }
        if (onboardingCompleted && onWelcome) return '/';
        return null;
      }

      final session = authState.valueOrNull?.session;
      final isLoggingIn = state.matchedLocation == '/login';
      final isUnlocking = state.matchedLocation == '/unlock';
      final onWelcome = state.matchedLocation == '/welcome';

      if (session == null) return isLoggingIn ? null : '/login';
      if (!isUnlocked && !isUnlocking) return '/unlock';
      if (isUnlocked && (isLoggingIn || isUnlocking)) return '/';

      final accounts = accountsAsync.valueOrNull;
      if (accounts != null &&
          accounts.isEmpty &&
          !onboardingCompleted &&
          !onWelcome &&
          !isLoggingIn &&
          !isUnlocking) {
        return '/welcome';
      }
      if (onboardingCompleted && onWelcome) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/unlock', builder: (_, __) => const UnlockScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: '/budgets',
        redirect: (_, __) => '/spending',
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
                path: '/insights',
                builder: (_, __) => const InsightsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/accounts/:id',
        builder: (_, state) => AccountDetailScreen(
          accountId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/transactions',
        builder: (_, state) => TransactionsScreen(
          initialCategoryId: state.uri.queryParameters['category'],
          initialAccountId: state.uri.queryParameters['account'],
        ),
      ),
    ],
  );
});
