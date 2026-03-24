import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';
import 'screens/navigation_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const HomeworkAI(),
    ),
  );
}

class HomeworkAI extends StatelessWidget {
  const HomeworkAI({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Homework AI",

      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        primaryColor: const Color(0xFF4F46E5),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),

      themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,

      home: const NavigationScreen(),
    );
  }
}
