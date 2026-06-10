import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swoosh/core/config/env.dart';

class DevAuthBootstrapResult {
  const DevAuthBootstrapResult({required this.success, this.error});

  final bool success;
  final String? error;
}

Future<DevAuthBootstrapResult> bootstrapDevSession() async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession != null) {
    return const DevAuthBootstrapResult(success: true);
  }

  try {
    await client.auth.signInWithPassword(
      email: Env.devEmail,
      password: Env.devPassword,
    );
    if (client.auth.currentSession != null) {
      return const DevAuthBootstrapResult(success: true);
    }
  } on AuthException catch (error) {
    if (error.message.toLowerCase().contains('invalid login credentials')) {
      try {
        await client.auth.signUp(
          email: Env.devEmail,
          password: Env.devPassword,
        );
        if (client.auth.currentSession != null) {
          return const DevAuthBootstrapResult(success: true);
        }
      } on AuthException catch (signUpError) {
        return DevAuthBootstrapResult(
          success: false,
          error: signUpError.message,
        );
      } catch (error) {
        return DevAuthBootstrapResult(
          success: false,
          error: error.toString(),
        );
      }
    }
    return DevAuthBootstrapResult(success: false, error: error.message);
  } catch (error) {
    return DevAuthBootstrapResult(success: false, error: error.toString());
  }

  return const DevAuthBootstrapResult(
    success: false,
    error: 'Could not establish a dev session',
  );
}
