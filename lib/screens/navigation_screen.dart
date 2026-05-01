import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'planner_screen.dart';
import 'profile_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int currentIndex = 0;

  void _openPlanner() {
    setState(() => currentIndex = 3);
  }

  void _openProfile() {
    setState(() => currentIndex = 4);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onOpenPlanner: _openPlanner, onOpenProfile: _openProfile),
      const ChatScreen(),
      HistoryScreen(isActive: currentIndex == 2),
      PlannerScreen(onOpenProfile: _openProfile),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: currentIndex, children: screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
