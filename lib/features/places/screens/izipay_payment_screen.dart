// lib/features/places/screens/izipay_payment_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:harkai/l10n/app_localizations.dart';

class IzipayPaymentScreen extends StatefulWidget {
  final double amount;

  const IzipayPaymentScreen({super.key, required this.amount});

  @override
  IzipayPaymentScreenState createState() => IzipayPaymentScreenState();
}

class IzipayPaymentScreenState extends State<IzipayPaymentScreen> {
  String? _formToken;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _didRunAsyncInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRunAsyncInit) {
      _didRunAsyncInit = true;
      _createFormToken();
    }
  }

  Future<void> _createFormToken() async {
    try {
      // Step 1: Get authentication credentials from .env file
      final String clientId = dotenv.env['IZIPAY_CLIENT_ID']!;
      final String clientSecret = dotenv.env['IZIPAY_PASSWORD_TEST']!;
      // Using the production URL you confirmed from your dashboard
      final String izipayApiUrl = dotenv.env['IZIPAY_BASE_URL_PROD']!;
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      final localizations = AppLocalizations.of(context)!;

      if (currentUser == null) {
        throw Exception(localizations.incidentModalErrorUserNotLoggedIn);
      }

      // Step 2: Create the payment details payload
      final paymentData = {
        "amount": (widget.amount * 100).toInt(),
        "currency": "PEN",
        "orderId": "order-harkai-${DateTime.now().millisecondsSinceEpoch}",
        "customer": {
          "email": currentUser.email ?? "no-email@example.com",
        }
      };

      // Step 3: Call the IziPay API
      // *** THE ONLY CHANGE IS ON THE LINE BELOW ***
      // We are trying the v3 endpoint, which is common for some "Mi Cuenta Web" accounts.
      final response = await http.post(
        Uri.parse('$izipayApiUrl/api/v3/Charge/CreatePayment'), // Changed from v4 to v3
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: jsonEncode(paymentData),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['status'] == 'SUCCESS' && responseBody['answer'] != null) {
          final answer = responseBody['answer'];
          if (answer['formToken'] != null) {
            setState(() {
              _formToken = answer['formToken'];
              _isLoading = false;
            });
          } else {
            throw Exception('formToken not found in IziPay response');
          }
        } else {
          throw Exception(
              'IziPay API Error: ${responseBody['answer']?['errorMessage'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to create payment session: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error in _createFormToken: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error creating payment token: $e';
        });
      }
    }
  }
  
  String _generatePaymentHtml(String formToken) {
    final String jsUrl = dotenv.env['IZIPAY_JS_URL']!;
    final String publicKey = dotenv.env['IZIPAY_JS_PUBLIC_KEY_TEST']!;
    const String successUrl = "https://example.com/harkai/payment/success";
    const String errorUrl = "https://example.com/harkai/payment/error";

    return """
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
          <script src="$jsUrl"
            kr-public-key="$publicKey"
            kr-post-url-success="$successUrl"
            kr-post-url-refused="$errorUrl"
            kr-post-url-error="$errorUrl"
            kr-form-token="$formToken">
          </script>
        </head>
        <body>
          <div class="kr-embedded" kr-popin></div>
        </body>
      </html>
    """;
  }


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.addPlaceButtonTitle),
        backgroundColor: const Color(0xFF001F3F),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,),
                  ),
                )
              : _formToken == null
                  ? Center(child: Text(localizations.paymentFailedMessage))
                  : InAppWebView(
                      initialData: InAppWebViewInitialData(
                        data: _generatePaymentHtml(_formToken!),
                        mimeType: 'text/html',
                      ),
                      onLoadStop: (controller, url) {
                        final String urlString = url.toString();
                        if (urlString.contains('/payment/success')) {
                          Navigator.pop(context, true);
                        } else if (urlString.contains('/payment/error') || urlString.contains('/payment/refused')) {
                          Navigator.pop(context, false);
                        }
                      },
                      onLoadError: (controller, url, code, message) {
                        debugPrint("WebView Error: $message (code: $code)");
                        if(mounted) {
                          Navigator.pop(context, false);
                        }
                      },
                    ),
    );
  }
}