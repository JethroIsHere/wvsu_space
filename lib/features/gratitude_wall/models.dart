import 'package:cloud_firestore/cloud_firestore.dart';

class GratitudePost {
  final String id;
  final String type; // 'gratitude' | 'express'
  final String content;
  final String authorId;
  final String? authorNickname;
  final bool isAnonymous;
  final Timestamp timestamp;
  final Timestamp? expiresAt;
  final int likes;
  final Map<String, dynamic>? likedBy;

  GratitudePost({
    required this.id,
    required this.type,
    required this.content,
    required this.authorId,
    this.authorNickname,
    required this.isAnonymous,
    required this.timestamp,
    this.expiresAt,
    this.likes = 0,
    this.likedBy,
  });

  factory GratitudePost.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GratitudePost(
      id: doc.id,
      type: data['type'] as String? ?? 'gratitude',
      content: data['content'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorNickname: data['authorNickname'] as String?,
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      expiresAt: data['expiresAt'] as Timestamp?,
      likes: (data['likes'] as num?)?.toInt() ??
          (data['likedBy'] is Map ? (data['likedBy'] as Map).length : 0),
      likedBy: data['likedBy'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
      'authorId': authorId,
      'authorNickname': authorNickname,
      'isAnonymous': isAnonymous,
      'timestamp': timestamp,
      'expiresAt': expiresAt,
      'likes': likes,
      'likedBy': likedBy,
    };
  }
}
