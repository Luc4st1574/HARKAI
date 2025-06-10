import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


class Configuration extends StatefulWidget {
  const Configuration({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _Configuration createState() => _Configuration();
}

class _Configuration extends State<Configuration> {
  final _urlController = TextEditingController();
  final _currencyController = TextEditingController();
  final _languageController = TextEditingController();

  void _saveSettings() async {
    final url = _urlController.text;
    final currency = _currencyController.text;
    final language = _languageController.text;
    if (url.isEmpty || currency.isEmpty || language.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields have to be filled')),
      );
    } else {
        saveSettings(url, currency, language).then((_) => {
          Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false)
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saving data'))
        );
      }
    }

  void _populateSettings() async {
    final settings = await getSettings();
    setState(() {
      _urlController.text = settings[0];
      _currencyController.text = settings[1];
      _languageController.text = settings[2];
    });
  }

  Future saveSettings(String url, String currency, String language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('url', url);
    await preferences.setString('currency', currency);
    await preferences.setString('language', language);
  }

  Future<List> getSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final url = (preferences.getString('url') ?? "");
    final currency = (preferences.getString('currency') ?? "");
    final language = (preferences.getString('language') ?? "");
    return [url, currency, language];
  }

  @override
  void initState() {
    super.initState();
    _populateSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: ListView(
          children: [
            ListTile(
              title: new TextField(
                controller: _urlController,
                decoration: InputDecoration(labelText: "Merchant Server URL"),
              ),
            ),
            ListTile(
              title: new TextField(
                controller: _currencyController,
                decoration: InputDecoration(labelText: "Currency (ISO 4217)"),
              ),
            ),
            ListTile(
              title: new TextField(
                controller: _languageController,
                decoration: InputDecoration(labelText: "Language (ISO 639-1)"),
              ),
            ),
            TextButton(
                onPressed: _saveSettings,
                child: Text("Save Settings")
            )
          ],
        )
    );
  }
}
