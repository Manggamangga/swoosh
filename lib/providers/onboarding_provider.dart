import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/providers/providers.dart';

const _onboardingKey = 'onboarding_completed';
const _dismissedRecurringKey = 'dismissed_recurring_keys';

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier(ref);
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._ref) : super(false) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    state = prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_onboardingKey, true);
    state = true;
  }
}

final dismissedRecurringKeysProvider =
    StateNotifierProvider<DismissedRecurringNotifier, Set<String>>((ref) {
  return DismissedRecurringNotifier(ref);
});

class DismissedRecurringNotifier extends StateNotifier<Set<String>> {
  DismissedRecurringNotifier(this._ref) : super({}) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final keys = prefs.getStringList(_dismissedRecurringKey) ?? [];
    state = keys.toSet();
  }

  Future<void> dismiss(String key) async {
    final updated = {...state, key};
    state = updated;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    await prefs.setStringList(_dismissedRecurringKey, updated.toList());
  }
}
