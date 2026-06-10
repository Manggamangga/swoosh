import 'package:flutter/material.dart';
import 'package:swoosh/core/services/dev_auth_bootstrap.dart';
import 'package:swoosh/core/theme/app_colors.dart';

class DevAuthGate extends StatefulWidget {
  const DevAuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<DevAuthGate> createState() => _DevAuthGateState();
}

class _DevAuthGateState extends State<DevAuthGate> {
  DevAuthBootstrapResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    final result = await bootstrapDevSession();
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_result?.success != true) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not sign in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _result?.error ?? 'Dev auth failed. Check your Supabase credentials.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _bootstrap,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
