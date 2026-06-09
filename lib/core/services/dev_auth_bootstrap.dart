import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/core/config/env.dart';

Future<void> bootstrapDevSession() async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession != null) return;

  try {
    await client.auth.signInWithPassword(
      email: Env.devEmail,
      password: Env.devPassword,
    );
    return;
  } catch (_) {}

  try {
    await client.auth.signUp(
      email: Env.devEmail,
      password: Env.devPassword,
    );
  } catch (_) {}
}
