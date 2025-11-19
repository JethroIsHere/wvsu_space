import 'package:flutter/material.dart';
import 'repository.dart';
import 'utils.dart';
import 'chat.dart';
import '../widgets/app_button.dart';

class AddRoomDialog extends StatefulWidget {
  const AddRoomDialog({super.key});

  @override
  State<AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends State<AddRoomDialog> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  String _mood = 'chill';
  bool _loading = false;

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    final title = _titleCtl.text.trim();
    final desc = _descCtl.text.trim();
    if (title.isEmpty) return;
    setState(() => _loading = true);
    try {
      final id = await VibeRoomsRepository.createRoom(
          mood: _mood, title: title, description: desc);
      await VibeRoomsRepository.joinRoom(id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RoomChatScreen(roomId: id)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to add room: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    labelText: 'Room Description',
                    border: OutlineInputBorder()),
                maxLines: 3),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _mood,
              items: moods
                  .map(
                      (m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                  .toList(),
              onChanged: (v) => setState(() => _mood = v ?? 'chill'),
              decoration: const InputDecoration(labelText: 'Mood'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                onPressed: _loading ? null : _handleAdd,
                child: _loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Add'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
