import 'package:flutter/material.dart';


class Success extends StatefulWidget {
  const Success({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _SuccessState createState() => _SuccessState();
}

class _SuccessState extends State<Success> {
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
          const Text("Successful Transaction",
              style: TextStyle(
                  fontSize: 30, fontWeight:
                  FontWeight.bold,
                  color: Colors.green),
          ),

          ElevatedButton(
              onPressed: (){
                Navigator.pushNamed(
                    context, '/'
                );
              },
              child: Text("Ok, return"))
        ],
      ),
    );
  }
}
