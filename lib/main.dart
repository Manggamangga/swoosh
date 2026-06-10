import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/app.dart';
import 'package:swoosh/core/config/env.dart';
import 'package:swoosh/core/services/dev_auth_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  if (Env.skipAuth) {
    await bootstrapDevSession();
  }

  runApp(const ProviderScope(child: SwooshApp()));
}
