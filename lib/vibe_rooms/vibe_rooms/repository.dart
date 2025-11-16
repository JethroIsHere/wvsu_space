import 'dart:async';
import 'models.dart';

/// In-memory repository that simulates rooms and messages so the UI works
/// without Firestore. Replace with Firestore logic later when ready.
class VibeRoomsRepository {
  static final Map<String, VibeRoom> _rooms = {};
  static final Map<String, List<VibeMessage>> _messages = {};

  static final StreamController<List<VibeRoom>> _roomsController =
      StreamController.broadcast();

  static final Map<String, StreamController<List<VibeMessage>>>
      _messagesControllers = {};

  static bool _initialized = false;

  static void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    // seed with a few example rooms to match the designer mockups
    final now = DateTime.now();
    void addSample(
        String id, String mood, String title, String desc, int active) {
      final room = VibeRoom(
        roomId: id,
        mood: mood,
        title: title,
        description: desc,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 30)),
        status: 'active',
        participantCount: active,
        maxParticipants: 8,
      );
      _rooms[id] = room;
      _messages[id] = [
        VibeMessage(
          messageId: '${id}_m1',
          senderId: 'system',
          senderNickname: 'System',
          text: '$title room created',
          timestamp: now,
        )
      ];
      _messagesControllers[id] =
          StreamController<List<VibeMessage>>.broadcast();
      _messagesControllers[id]!.add(_messages[id]!);
    }

    addSample('random_chat', 'random', 'Random Chat',
        'Talk about anything and everything', 12);
    addSample('anime_gaming', 'happy', 'Anime & Gaming',
        'Discuss your favorite shows and games', 15);
    addSample('stress_relief', 'support', 'Stress Relief',
        'Share your feelings and find support', 18);
    addSample('study_help', 'chill', 'Study Help',
        'Get help with assignments and exams', 22);

    // notify initial list
    _emitRooms();
  }

  static void _emitRooms() {
    _roomsController.add(_rooms.values.toList());
  }

  /// Stream of available rooms (simulated)
  static Stream<List<VibeRoom>> roomsStream() {
    _ensureInit();
    return _roomsController.stream;
  }

  /// Create a new room (in-memory)
  static Future<String> createRoom({
    required String mood,
    required String title,
    String description = '',
  }) async {
    _ensureInit();
    final id = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final room = VibeRoom(
      roomId: id,
      mood: mood,
      title: title,
      description: description,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
      status: 'active',
      participantCount: 1,
      maxParticipants: 8,
    );
    _rooms[id] = room;
    _messages[id] = [];
    _messagesControllers[id] = StreamController<List<VibeMessage>>.broadcast();
    _emitRooms();
    return id;
  }

  /// Find an existing room by mood or create a new one
  static Future<String> findOrCreateVibeRoom(String mood) async {
    _ensureInit();
    try {
      final open = _rooms.values.where(
          (r) => r.mood == mood && r.participantCount < r.maxParticipants);
      if (open.isNotEmpty) return open.first.roomId;
    } catch (_) {}
    return createRoom(
        mood: mood, title: '${mood[0].toUpperCase()}${mood.substring(1)} Room');
  }

  /// Join a room (increments participant count and emits update)
  static Future<void> joinRoom(String roomId, {String userId = 'me'}) async {
    _ensureInit();
    final room = _rooms[roomId];
    if (room == null) throw StateError('Room not found');
    room.participantCount += 1;
    _rooms[roomId] = room;
    _emitRooms();
    // add a system join message
    sendMessage(roomId, 'system',
        '${userId == 'me' ? 'You' : 'Anonymous'} joined the room');
  }

  static Future<void> leaveRoom(String roomId, {String userId = 'me'}) async {
    _ensureInit();
    final room = _rooms[roomId];
    if (room == null) return;
    room.participantCount =
        (room.participantCount - 1).clamp(0, room.maxParticipants);
    _emitRooms();
    sendMessage(roomId, 'system',
        '${userId == 'me' ? 'You' : 'Anonymous'} left the room');
  }

  /// Stream messages for a room
  static Stream<List<VibeMessage>> messagesStream(String roomId) {
    _ensureInit();
    final ctl = _messagesControllers[roomId];
    if (ctl == null) {
      _messagesControllers[roomId] =
          StreamController<List<VibeMessage>>.broadcast();
      _messagesControllers[roomId]!.add(_messages[roomId] ?? []);
    }
    return _messagesControllers[roomId]!.stream;
  }

  /// Send a message to a room
  static Future<void> sendMessage(String roomId, String senderId, String text,
      {String? senderNickname}) async {
    _ensureInit();
    final msg = VibeMessage(
      messageId: '${roomId}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderNickname:
          senderNickname ?? (senderId == 'me' ? 'You' : 'Anonymous'),
      text: text,
      timestamp: DateTime.now(),
    );
    _messages.putIfAbsent(roomId, () => []);
    _messages[roomId]!.add(msg);
    _messagesControllers.putIfAbsent(
        roomId, () => StreamController<List<VibeMessage>>.broadcast());
    _messagesControllers[roomId]!.add(List.unmodifiable(_messages[roomId]!));
  }

  /// Dispose controllers (not strictly necessary for the in-memory demo)
  static void dispose() {
    _roomsController.close();
    for (final c in _messagesControllers.values) {
      c.close();
    }
  }
}
