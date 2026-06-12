import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/router/app_router.dart';
import 'package:swoosh/core/theme/app_theme.dart';
import 'package:swoosh/core/theme/swoosh_scroll_behavior.dart';
import 'package:swoosh/features/openbanking/bank_callback_listener.dart';

class SwooshApp extends ConsumerWidget {
  const SwooshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return BankCallbackListener(
      child: MaterialApp.router(
        title: 'Swoosh',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        scrollBehavior: const SwooshScrollBehavior(),
        routerConfig: router,
      ),
    );
  }
}
