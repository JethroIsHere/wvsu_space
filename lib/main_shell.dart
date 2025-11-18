import 'package:flutter/material.dart';
import 'home.dart';
import 'community_standing.dart';
import 'widgets/bottom_nav.dart';
import 'vibe_rooms/room_list.dart';
import 'vibe_rooms/add_room_dialog.dart';
import 'gratitude_wall/gratitude_wall.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    // Vibe Rooms list replaces the previous placeholder
    const RoomListScreen(),
    const GratitudeWallScreen(),
    const CommunityStandingScreen(),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _index == 1
          ? Padding(
              // raise FAB so it overlaps less with list items
              padding: const EdgeInsets.only(bottom: 40.0),
              child: FloatingActionButton(
                backgroundColor: Colors.green,
                onPressed: () async {
                  await showDialog(
                      context: context, builder: (_) => const AddRoomDialog());
                },
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }
}
