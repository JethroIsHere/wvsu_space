import 'package:flutter/material.dart';
import 'repository.dart';
import 'models.dart';
import 'message_bubble.dart';

class RoomChatScreen extends StatefulWidget {
  final String roomId;

  const RoomChatScreen({super.key, required this.roomId});

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: StreamBuilder<List<VibeRoom>>(
              stream: VibeRoomsRepository.roomsStream(),
              builder: (context, snap) {
                final rooms = snap.data ?? [];
                final room = rooms.firstWhere((r) => r.roomId == widget.roomId,
                    orElse: () => VibeRoom(
                        roomId: widget.roomId,
                        mood: 'unknown',
                        title: 'Room',
                        description: '',
                        createdAt: DateTime.now(),
                        expiresAt:
                            DateTime.now().add(const Duration(minutes: 30)),
                        status: 'active',
                        participantCount: 0,
                        maxParticipants: 8));
                return Text(room.title);
              })),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<VibeMessage>>(
              stream: VibeRoomsRepository.messagesStream(widget.roomId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isOwn = m.senderId == 'me' ||
                        m.senderId == 'system' && m.senderNickname == 'You';
                    return MessageBubble(
                        text: m.text,
                        author: m.senderNickname,
                        timestamp: m.timestamp,
                        isOwn: isOwn);
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: _ctl,
                        decoration: const InputDecoration(
                            hintText: 'Share with the group',
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(24)))))),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () async {
                    final txt = _ctl.text.trim();
                    if (txt.isEmpty) return;
                    await VibeRoomsRepository.sendMessage(
                        widget.roomId, 'me', txt,
                        senderNickname: 'You');
                    _ctl.clear();
                  },
                  child: const Icon(Icons.send),
                )
              ]),
            ),
          )
        ],
      ),
    );
  }
}
