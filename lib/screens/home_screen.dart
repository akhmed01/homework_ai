import 'package:flutter/material.dart';
import 'camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Homework AI"),
        centerTitle: true,
        backgroundColor: const Color(0xFF4F46E5),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            const Text(
              "Solve homework instantly",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CameraScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text("Scan Homework"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 18,
                  ),
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              "Recent Problems",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                children: const [
                  ProblemCard(text: "2x + 5 = 15"),
                  ProblemCard(text: "Find velocity in physics"),
                  ProblemCard(text: "Explain binary search"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProblemCard extends StatelessWidget {
  final String text;

  const ProblemCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Text(text),
    );
  }
}
