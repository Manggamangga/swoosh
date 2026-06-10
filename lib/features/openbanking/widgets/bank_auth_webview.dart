import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BankAuthWebView extends StatefulWidget {
  const BankAuthWebView({
    super.key,
    required this.authUrl,
    required this.callbackUri,
  });

  final String authUrl;
  final Uri callbackUri;

  static Future<String?> open(
    BuildContext context, {
    required String authUrl,
    required Uri callbackUri,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => BankAuthWebView(
          authUrl: authUrl,
          callbackUri: callbackUri,
        ),
      ),
    );
  }

  @override
  State<BankAuthWebView> createState() => _BankAuthWebViewState();
}

class _BankAuthWebViewState extends State<BankAuthWebView> {
  late final WebViewController _controller;
  var _loading = true;
  var _completed = false;

  bool _matchesCallback(Uri uri) {
    if (uri.scheme == widget.callbackUri.scheme &&
        uri.host == widget.callbackUri.host &&
        uri.path == widget.callbackUri.path) {
      return true;
    }
    return uri.scheme == 'swoosh' && uri.host == 'bank-callback';
  }

  void _complete(String url) {
    if (_completed || !mounted) return;
    _completed = true;
    Navigator.of(context).pop(url);
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            if (_matchesCallback(uri)) {
              _complete(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null) return;
            final uri = Uri.parse(url);
            if (_matchesCallback(uri)) {
              _complete(url);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank sign-in'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
