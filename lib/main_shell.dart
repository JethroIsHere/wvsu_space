import 'package:flutter/material.dart';
import 'home.dart';
import 'community_standing.dart';
import 'widgets/bottom_nav.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    // Placeholder pages for Rooms and Gratitude until separate screens exist
    Center(child: Text('Rooms (coming soon)')),
    Center(child: Text('Gratitude (coming soon)')),
    CommunityStandingScreen(),
  ];

  void _onIndexChanged(int i) {
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNav(
        currentIndex: _index,
        onIndexChanged: _onIndexChanged,
      ),
    );
  }
}
