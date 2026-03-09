import 'package:flutter/material.dart';

void main() {
  runApp(HomeworkAI());
}

class HomeworkAI extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homework AI',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Homework AI")),
      body: Center(
        child: ElevatedButton(onPressed: () {}, child: Text("Scan Homework")),
      ),
    );
  }
}
