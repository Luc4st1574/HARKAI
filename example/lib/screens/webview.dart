import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebView extends StatefulWidget {
  PaymentWebView({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  PaymentWebViewState createState() => PaymentWebViewState();
}

late String getUrlPref;

class PaymentWebViewState extends State<PaymentWebView> {
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _clearCache();
  }

  Widget build(BuildContext context) {
    final responseArgument = ModalRoute.of(context)!.settings.arguments as Map;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WebView(
        initialUrl: responseArgument['response'],
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
        navigationDelegate: (NavigationRequest request) {
          final url = request.url;
          if (url.contains('success')) {
            Navigator.pushNamedAndRemoveUntil(
                context, '/success', (r) => false);
            return NavigationDecision.prevent;
          } else if(url.contains('error') || url.contains('cancel')){
            Navigator.pushNamedAndRemoveUntil(context, '/fail', (r) => false);
            return NavigationDecision.prevent;
          } else {
            return NavigationDecision.navigate;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _clearCache();
    super.dispose();
  }

  Future<void> _clearCache() async {
    await _webViewController?.clearCache();
    final cookieManager = CookieManager();
    await cookieManager.clearCookies();
  }
}
