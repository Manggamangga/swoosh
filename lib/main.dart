import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/app.dart';
import 'package:swoosh/core/config/env.dart';
import 'package:swoosh/features/auth/widgets/dev_auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  Widget app = const ProviderScope(child: SwooshApp());

  if (Env.skipAuth) {
    app = DevAuthGate(child: app);
  }

  runApp(app);
}
