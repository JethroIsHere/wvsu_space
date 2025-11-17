import 'package:flutter/material.dart';
import 'repository.dart';
import 'utils.dart';
import 'chat.dart';

class AddRoomDialog extends StatefulWidget {
  const AddRoomDialog({super.key});

  @override
  State<AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends State<AddRoomDialog> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  String _mood = 'chill';

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Add a Room',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close))
          ]),
          const SizedBox(height: 8),
          TextField(
              controller: _titleCtl,
              decoration: const InputDecoration(
                  labelText: 'Room Title', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(
              controller: _descCtl,
              decoration: const InputDecoration(
                  labelText: 'Room Description', border: OutlineInputBorder()),
              maxLines: 3),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _mood,
            items: moods
                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                .toList(),
            onChanged: (v) => setState(() => _mood = v ?? 'chill'),
            decoration: const InputDecoration(labelText: 'Mood'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final title = _titleCtl.text.trim();
                final desc = _descCtl.text.trim();
                if (title.isEmpty) return;
                final id = await VibeRoomsRepository.createRoom(
                    mood: _mood, title: title, description: desc);
                // Ensure the creator is marked as joined and navigate into the room.
                await VibeRoomsRepository.joinRoom(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RoomChatScreen(roomId: id)),
                  );
                }
              },
              child: const Text('Add'),
            ),
          )
        ]),
      ),
    );
  }
}
