// WVSU Space — `lib/features/home/main_shell.dart`
// Simple: the app shell that holds the main tabs and floating actions.
import 'package:flutter/material.dart';
import 'package:wvsu_space/features/home/home.dart';
import 'package:wvsu_space/features/standing/community_standing.dart';
import 'package:wvsu_space/widgets/bottom_nav.dart';
import 'package:wvsu_space/features/vibe_rooms/room_list.dart';
import 'package:wvsu_space/features/vibe_rooms/add_room_dialog.dart';
import 'package:wvsu_space/features/gratitude_wall/gratitude_wall.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    // Vibe Rooms list (shows available rooms)
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
      // Keep other pages' state while showing the selected one
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNav(
        currentIndex: _index,
        onIndexChanged: _onIndexChanged,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // Show a create-room (+) button only on the Rooms tab
      floatingActionButton: _index == 1
          ? Padding(
              // Lift the + button so it does not cover list items
              padding: const EdgeInsets.only(bottom: 40.0),
              child: FloatingActionButton(
                heroTag: null,
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
