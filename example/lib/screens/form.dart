import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainForm extends StatefulWidget {
  MainForm({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MainFormState createState() => _MainFormState();
}

class _MainFormState extends State<MainForm> {
  String urlValue =
      "https://secure.micuentaweb.pe/vads-payment/entry.silentInit.a";
  String currencyValue = '604'; //Dolar 840 - Sol 604 - Euro 978
  String languageValue = 'es';

  late String? _dataModel;

  final formGlobalKey = GlobalKey<FormState>();
  String paymentModeValue = 'TEST'; //TEST - PRODUCTION
  TextEditingController amountController = TextEditingController();
  TextEditingController orderIdController = TextEditingController();
  TextEditingController emailController = TextEditingController();

  Future<String?> _submitForm(String language, String amount, String email,
      String orderId, String paymentMode, String currency) async {
    String amountInteger = (int.parse(amount) * 100).toString();
    try {
      var url = Uri.parse('-SERVER WEBVIEW URL-');

      var body = {
        'email': email,
        'amount': amountInteger,
        'currency': currency,
        'mode': paymentMode,
        'language': language,
        'orderId': orderId
      };

      var jsonData = json.encode(body);

      var response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonData,
      );

      if (response.statusCode != 200) return null;
      var data = jsonDecode(response.body);
      String responseString = data['redirectionUrl'].toString();
      return responseString;
    } catch (error) {
      print('Error al realizar la solicitud HTTP: $error');
    }
  }

  _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      urlValue = (prefs.getString("url") ?? "");
      currencyValue = (prefs.getString("currency") ?? currencyValue);
      languageValue = (prefs.getString("language") ?? languageValue);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(widget.title),
              new IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/configuration');
                  },
                  icon: new Icon(Icons.settings_rounded))
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: formGlobalKey,
            child: Wrap(
              spacing: 10,
              children: [
                // Amount
                const SizedBox(height: 50),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))
                  ],
                  decoration:
                      InputDecoration(labelText: "Monto", hintText: "0"),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return "Please enter an amount";
                    }
                  },
                ),
                // Email
                const SizedBox(height: 15),
                TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                        labelText: "Email", hintText: "example@email.com"),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Por favor ingresa tu correo";
                      }
                    }),
                // Order ID
                const SizedBox(height: 15),
                TextFormField(
                  controller: orderIdController,
                  keyboardType: TextInputType.text,
                  decoration:
                      InputDecoration(labelText: "Order ID", hintText: ""),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return "Ingresa un order ID";
                    }
                  },
                ),
                const SizedBox(height: 60),

                ElevatedButton(
                    onPressed: () async {
                      String language = languageValue;
                      String amount = amountController.text;
                      String email = emailController.text;
                      String orderId = orderIdController.text;
                      String paymentMode = paymentModeValue;
                      String currency = currencyValue;
                      if (formGlobalKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Redirecting')),
                        );
                        String? data = await _submitForm(language, amount,
                            email, orderId, paymentMode, currency);
                        setState(() {
                          _dataModel = data;
                        });
                        Navigator.pushNamed(context, '/webview',
                            arguments: {'response': data});
                      }
                    },
                    child: Text("Pagar ahora"))
              ],
            ),
          ),
        ));
  }
}
