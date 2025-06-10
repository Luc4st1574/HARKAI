import 'package:flutter/material.dart';
import 'package:flutter_webview/screens/configuration.dart';
import 'package:flutter_webview/screens/fail.dart';
import 'package:flutter_webview/screens/form.dart';
import 'package:flutter_webview/screens/success.dart';
import 'package:flutter_webview/screens/webview.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => MainForm(title: 'Flutter App'),
          '/configuration': (context) => Configuration(title: "Settings"),
          '/webview': (context) => PaymentWebView(title: 'Flutter WebView'),
          '/success': (context) => Success(title: "Success Transaction"),
          '/fail': (context) => Fail(title: "Failed Transaction"),
        }
    );
  }
}
