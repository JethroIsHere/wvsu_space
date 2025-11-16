// Simple, file-local data models used by the Vibe Rooms UI scaffolding.

class VibeParticipant {
  final String userId;
  final String nickname;
  final DateTime joinedAt;
  final bool isActive;

  VibeParticipant({
    required this.userId,
    required this.nickname,
    required this.joinedAt,
    required this.isActive,
  });
}

class VibeMessage {
  final String messageId;
  final String senderId;
  final String senderNickname;
  final String text;
  final DateTime timestamp;

  VibeMessage({
    required this.messageId,
    required this.senderId,
    required this.senderNickname,
    required this.text,
    required this.timestamp,
  });
}

class VibeRoom {
  final String roomId;
  final String mood;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status;
  int participantCount;
  final int maxParticipants;

  VibeRoom({
    required this.roomId,
    required this.mood,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.participantCount,
    required this.maxParticipants,
  });
}
