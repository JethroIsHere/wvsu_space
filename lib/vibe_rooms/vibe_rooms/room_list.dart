import 'package:flutter/material.dart';
import 'repository.dart';
import 'chat.dart';
import 'room_card.dart';
import 'add_room_dialog.dart';
import 'models.dart';
import 'styles.dart';

class RoomListScreen extends StatelessWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.accent,
        title: const Text('Themed Rooms'),
        centerTitle: false,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8)),
              child: const Text(
                  'Room Guidelines\nStay on topic for each room • Be respectful and supportive • Report inappropriate behavior',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<VibeRoom>>(
              stream: VibeRoomsRepository.roomsStream(),
              builder: (context, snapshot) {
                final rooms = snapshot.data ?? [];
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final r = rooms[index];
                    return RoomCard(
                      room: r,
                      onJoin: () async {
                        await VibeRoomsRepository.joinRoom(r.roomId);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    RoomChatScreen(roomId: r.roomId)),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
        onPressed: () async {
          await showDialog(
              context: context, builder: (_) => const AddRoomDialog());
        },
      ),
    );
  }
}
