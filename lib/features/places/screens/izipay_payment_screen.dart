import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class IzipayPaymentScreen extends StatefulWidget {
  final double amount;

  const IzipayPaymentScreen({super.key, required this.amount});

  @override
  IzipayPaymentScreenState createState() => IzipayPaymentScreenState();
}

class IzipayPaymentScreenState extends State<IzipayPaymentScreen> {
  InAppWebViewController? _webViewController;
  String? _formToken;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _createFormToken();
  }

  Future<void> _createFormToken() async {
    // IMPORTANT: This logic MUST be executed on your secure backend server,
    // not in the app. This is a simulation for demonstration purposes.
    // Your backend will use your Client ID and Client Secret to get the token.
    try {
      final String clientId = dotenv.env['IZIPAY_CLIENT_ID']!;
      final String clientSecret = dotenv.env['IZIPAY_PASSWORD_TEST']!; // Use TEST password for sandbox
      final String izipayApiUrl = dotenv.env['IZIPAY_BASE_URL_SANDBOX']!;

      final response = await http.post(
        Uri.parse('$izipayApiUrl/api/v3/auth/tokens'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
      );

      if (response.statusCode == 200) {
        final String token = response.body;
        // Now use the token to create the form session
        final paymentResponse = await http.post(
          Uri.parse('$izipayApiUrl/api/v3/payment/create'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            "amount": (widget.amount * 100).toInt(), // IziPay expects the amount in cents
            "currency": "PEN",
            "orderId": "order-${DateTime.now().millisecondsSinceEpoch}",
            "customer": {
              "email": "customer@example.com", // Replace with actual customer email
            }
          }),
        );
        
        if (paymentResponse.statusCode == 200) {
          final responseBody = jsonDecode(paymentResponse.body);
          final answer = responseBody['answer'];
          if(answer != null && answer['formToken'] != null) {
              setState(() {
                _formToken = answer['formToken'];
                _isLoading = false;
              });
          } else {
            throw Exception('formToken not found in payment response');
          }
        } else {
          throw Exception('Failed to create payment session: ${paymentResponse.body}');
        }
      } else {
        throw Exception('Failed to authenticate with IziPay: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error creating payment token: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Payment'),
        backgroundColor: const Color(0xFF001F3F),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _formToken == null
                  ? const Center(child: Text('Could not load payment form.'))
                  : InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(
                          '${dotenv.env['IZIPAY_BASE_URL_SANDBOX']!.replaceFirst("api.", "forms.")}/v1/html/form'
                        ), // Using sandbox forms URL
                        method: 'POST',
                        body: Uint8List.fromList(utf8.encode("kr-form-token=$_formToken")),
                        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                      ),
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        debugPrint('WebView created: $_webViewController');
                      },
                      onLoadStop: (controller, url) {
                        // Here you can check the URL to determine if the payment
                        // was successful, failed, or cancelled. These URLs must be
                        // configured in your IziPay Back-office.
                        final String urlString = url.toString();
                        if (urlString.contains('payment/success')) {
                          Navigator.pop(context, true); // Payment successful
                        } else if (urlString.contains('payment/failure') || urlString.contains('payment/cancelled')) {
                          Navigator.pop(context, false); // Payment failed or was cancelled
                        }
                      },
                    ),
    );
  }
}