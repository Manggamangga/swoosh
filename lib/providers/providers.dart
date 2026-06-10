import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/core/config/env.dart';
import 'package:swoosh/core/cache/local_cache.dart';
import 'package:swoosh/core/services/balance_history_service.dart';
import 'package:swoosh/core/services/biometric_service.dart';
import 'package:swoosh/core/services/categorization_service.dart';
import 'package:swoosh/core/services/category_matcher_service.dart';
import 'package:swoosh/core/services/forecast_service.dart';
import 'package:swoosh/core/services/recurring_detection_service.dart';
import 'package:swoosh/data/csv_import_service.dart';
import 'package:swoosh/data/repositories/account_repository.dart';
import 'package:swoosh/data/repositories/bank_connection_repository.dart';
import 'package:swoosh/data/repositories/budget_repository.dart';
import 'package:swoosh/data/repositories/category_repository.dart';
import 'package:swoosh/data/repositories/category_rule_repository.dart';
import 'package:swoosh/data/repositories/goal_repository.dart';
import 'package:swoosh/data/repositories/recurring_repository.dart';
import 'package:swoosh/data/repositories/transaction_repository.dart';
import 'package:swoosh/models/bank_connection.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

final localCacheProvider = FutureProvider<LocalCache>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return LocalCache(prefs);
});

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(LocalAuthentication()),
);

final accountRepositoryProvider = FutureProvider<AccountRepository>((ref) async {
  final cache = await ref.watch(localCacheProvider.future);
  return AccountRepository(ref.watch(supabaseProvider), cache);
});

final transactionRepositoryProvider =
    FutureProvider<TransactionRepository>((ref) async {
  final cache = await ref.watch(localCacheProvider.future);
  return TransactionRepository(ref.watch(supabaseProvider), cache);
});

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(supabaseProvider)),
);

final categoryRuleRepositoryProvider = Provider<CategoryRuleRepository>(
  (ref) => CategoryRuleRepository(ref.watch(supabaseProvider)),
);

final categoryMatcherServiceProvider = Provider<CategoryMatcherService>(
  (ref) => CategoryMatcherService(),
);

final categorizationServiceProvider = FutureProvider<CategorizationService>((ref) async {
  final txRepo = await ref.watch(transactionRepositoryProvider.future);
  return CategorizationService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
    ruleRepository: ref.watch(categoryRuleRepositoryProvider),
    transactionRepository: txRepo,
    matcher: ref.watch(categoryMatcherServiceProvider),
  );
});

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(supabaseProvider)),
);

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(supabaseProvider)),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(supabaseProvider)),
);

final bankConnectionRepositoryProvider = Provider<BankConnectionRepository>(
  (ref) => BankConnectionRepository(ref.watch(supabaseProvider)),
);

final bankConnectionsProvider = FutureProvider<List<BankConnection>>((ref) async {
  final repo = ref.watch(bankConnectionRepositoryProvider);
  return repo.fetchAll();
});

final csvImportServiceProvider = Provider<CsvImportService>(
  (ref) => CsvImportService(),
);

final balanceHistoryServiceProvider = Provider<BalanceHistoryService>(
  (ref) => BalanceHistoryService(),
);

final forecastServiceProvider = Provider<ForecastService>(
  (ref) => ForecastService(),
);

final recurringDetectionServiceProvider = Provider<RecurringDetectionService>(
  (ref) => RecurringDetectionService(),
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

final isUnlockedProvider = StateProvider<bool>((ref) => Env.skipAuth);
