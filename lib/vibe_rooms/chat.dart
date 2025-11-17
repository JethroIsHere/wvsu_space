import 'package:flutter/material.dart';
import 'repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';
import 'message_bubble.dart';

class RoomChatScreen extends StatefulWidget {
  final String roomId;

  const RoomChatScreen({super.key, required this.roomId});

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen>
    with WidgetsBindingObserver {
  final _ctl = TextEditingController();
  final ScrollController _scrollCtl = ScrollController();

  bool _left = false;
  final Map<String, int> _userColorIndex = {};
  static const int _maxColors = 8;
  // Palette: background (light) and border (stronger) pairs.
  final List<Color> _bgPalette = [
    Color(0xFFDCEBFF), // light blue
    Color(0xFFDFF5E6), // light green
    Color(0xFFFFF4D9), // light amber
    Color(0xFFF0E6FF), // light purple
    Color(0xFFFFE6F0), // light pink
    Color(0xFFE6F8F5), // light teal
    Color(0xFFFFEDE0), // light coral
    Color(0xFFE8EDFF), // light indigo
  ];
  final List<Color> _borderPalette = [
    Color(0xFF3A6ED8), // blue
    Color(0xFF1F9A3F), // green
    Color(0xFFF5A623), // amber/orange
    Color(0xFF7C4DFF), // purple
    Color(0xFFE91E63), // pink
    Color(0xFF009688), // teal
    Color(0xFFF57C00), // orange
    Color(0xFF4455FF), // indigo
  ];

  @override
  void dispose() {
    // ensure we leave the room when disposed
    if (!_left) {
      VibeRoomsRepository.leaveRoom(widget.roomId, userId: 'me');
      _left = true;
    }
    _ctl.dispose();
    _scrollCtl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Best-effort: when app goes to background/detached, attempt to leave the room
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_left) {
        VibeRoomsRepository.leaveRoom(widget.roomId, userId: 'me');
        _left = true;
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await _confirmLeave();
    if (shouldLeave) {
      await VibeRoomsRepository.leaveRoom(widget.roomId, userId: 'me');
      _left = true;
    }
    return shouldLeave;
  }

  Future<bool> _confirmLeave() async {
    final isLast =
        VibeRoomsRepository.isUserLastParticipant(widget.roomId, 'me');
    if (isLast) {
      final r = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('Leave room?'),
                content: const Text(
                    'You are the last person in this room. If you leave the room will be deleted along with its messages. Do you want to leave and delete this room?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Leave and Delete')),
                ],
              ));
      return r == true;
    }

    final r = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Leave room?'),
              content: const Text(
                  'Are you sure you want to leave this room? You can rejoin later if the room remains active.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Leave')),
              ],
            ));
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // A pop was attempted by the system (back button or gesture).
        // Show confirmation and if the user confirms, perform the pop.
        try {
          final shouldLeave = await _onWillPop();
          if (shouldLeave && context.mounted) {
            Navigator.of(context).pop();
          }
        } catch (_) {}
      },
      child: Scaffold(
        appBar: AppBar(
            title: StreamBuilder<List<VibeRoom>>(
                stream: VibeRoomsRepository.roomsStream(),
                builder: (context, snap) {
                  final rooms = snap.data ?? [];
                  final found = rooms.firstWhere(
                      (r) => r.roomId == widget.roomId,
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
                          maxParticipants: 8,
                          ownerUid: null));
                  if (found.title != 'Room') {
                    return Text(found.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18, fontWeight: FontWeight.w800));
                  }
                  // fallback: try to fetch the room from Firestore once
                  return FutureBuilder<VibeRoom?>(
                      future: VibeRoomsRepository.getRoom(widget.roomId),
                      builder: (c, f) {
                        final r = f.data ?? found;
                        return Text(r.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    fontSize: 18, fontWeight: FontWeight.w800));
                      });
                })),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<VibeMessage>>(
                stream: VibeRoomsRepository.messagesStream(widget.roomId),
                builder: (context, snapshot) {
                  var messages = snapshot.data ?? [];
                  // sort ascending by timestamp to ensure oldest -> newest
                  messages = List.from(messages)
                    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                  // auto-scroll to bottom when messages change
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtl.hasClients) {
                      _scrollCtl.animateTo(
                        _scrollCtl.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollCtl,
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      try {
                        final m = messages[index];
                        final currentUid =
                            FirebaseAuth.instance.currentUser?.uid;
                        final isOwn =
                            currentUid != null && m.senderId == currentUid;

                        // Assign a consistent color index for each user in this room
                        if (!_userColorIndex.containsKey(m.senderId) &&
                            _userColorIndex.length < _maxColors) {
                          _userColorIndex[m.senderId] = _userColorIndex.length;
                        } else if (!_userColorIndex.containsKey(m.senderId)) {
                          // If we exceeded palette, wrap around deterministically
                          _userColorIndex[m.senderId] =
                              m.senderId.hashCode.abs() % _maxColors;
                        }
                        final idx = _userColorIndex[m.senderId] ??
                            (m.senderId.hashCode.abs() % _maxColors);
                        final bgColor = _bgPalette[idx % _bgPalette.length];
                        final borderColor =
                            _borderPalette[idx % _borderPalette.length];
                        if (m.isSystem) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                Text(
                                  m.text,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.black54),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.black38),
                                ),
                              ],
                            ),
                          );
                        }

                        return MessageBubble(
                          text: m.text,
                          author: isOwn ? 'You' : m.senderNickname,
                          timestamp: m.timestamp,
                          isOwn: isOwn,
                          backgroundColor: bgColor,
                          borderColor: borderColor,
                        );
                      } catch (e, st) {
                        debugPrint('VibeRooms: message item builder error: $e');
                        debugPrint('$st');
                        return const SizedBox.shrink();
                      }
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          widget.roomId, 'me', txt);
                      _ctl.clear();
                    },
                    child: const Icon(Icons.send),
                  )
                ]),
              ),
            )
          ],
        ),
      ),
    );
  }
}
