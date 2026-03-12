import 'package:flutter/material.dart';
import 'screens/navigation_screen.dart';

void main() {
  runApp(const HomeworkAI());
}

class HomeworkAI extends StatelessWidget {
  const HomeworkAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Homework AI",
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        primaryColor: const Color(0xFF4F46E5),
        fontFamily: "Roboto",
      ),
      home: const NavigationScreen(),
    );
  }
}
