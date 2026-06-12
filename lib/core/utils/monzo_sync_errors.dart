import 'package:supabase_flutter/supabase_flutter.dart';

const monzoAwaitingApprovalMessage =
    'Open your Monzo app and approve access, then tap Sync.';

bool isMonzoAwaitingApprovalError(Object error) {
  final message = _errorMessage(error).toLowerCase();
  return message.contains('insufficient_permissions') ||
      message.contains('forbidden.insufficient') ||
      (message.contains('403') &&
          (message.contains('forbidden') || message.contains('permission')));
}

String _errorMessage(Object error) {
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map) {
      final err = details['error'];
      if (err != null) return err.toString();
    }
    return error.reasonPhrase ?? error.toString();
  }
  return error.toString();
}
