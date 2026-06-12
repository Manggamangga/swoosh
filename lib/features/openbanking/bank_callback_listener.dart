import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swoosh/core/config/env.dart';
import 'package:swoosh/core/router/app_router.dart';

final pendingBankCallbackProvider = StateProvider<Uri?>((ref) => null);

Uri get bankCallbackRelayUri =>
    Uri.parse('${Env.supabaseUrl}/functions/v1/bank-callback');

bool isBankCallbackUri(Uri uri) {
  if (uri.scheme == 'swoosh' && uri.host == 'bank-callback') return true;
  return uri.scheme == 'https' &&
      uri.host == bankCallbackRelayUri.host &&
      uri.path == bankCallbackRelayUri.path;
}

class BankCallbackListener extends ConsumerStatefulWidget {
  const BankCallbackListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BankCallbackListener> createState() => _BankCallbackListenerState();
}

class _BankCallbackListenerState extends ConsumerState<BankCallbackListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      _handleCallback(initial);
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(_handleCallback);
  }

  void _handleCallback(Uri uri) {
    if (!isBankCallbackUri(uri)) return;

    ref.read(pendingBankCallbackProvider.notifier).state = uri;
    ref.read(routerProvider).go('/connect-bank');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
