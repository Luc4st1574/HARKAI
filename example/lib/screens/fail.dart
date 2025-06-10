import 'dart:convert';

import 'package:flutter/material.dart';

class Fail extends StatefulWidget {
  const Fail({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _FailState createState() => _FailState();
}

class _FailState extends State<Fail> {
  //bool _visible = false;

  @override
  void initState() {
    super.initState();
  }

  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Row(
        ),
      ),
      body: ListView(
        children: [
          const Text("Failed Transaction",
              style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                  FontWeight.bold,
                  color: Colors.red)
          ),
          ElevatedButton(
              onPressed: (){
                Navigator.pushNamed(
                    context, '/'
                );
              },
              child: Text("Return"))
        ],
      ),
    );
  }
}
