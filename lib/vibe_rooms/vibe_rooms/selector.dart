import 'package:flutter/material.dart';
import 'repository.dart';
import 'chat.dart';
import 'utils.dart';

/// Simple mood selector that demonstrates entry points for the Vibe Rooms feature.
class VibeRoomSelector extends StatelessWidget {
  const VibeRoomSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vibe Rooms')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: moods
            .map((m) => Card(
                  child: ListTile(
                    leading:
                        Text(m.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(m.name),
                    subtitle: Text(m.description),
                    onTap: () => _join(context, m.id),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _join(BuildContext context, String mood) async {
    final roomId = await VibeRoomsRepository.findOrCreateVibeRoom(mood);
    await VibeRoomsRepository.joinRoom(roomId);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomChatScreen(roomId: roomId),
        ),
      );
    }
  }
}
