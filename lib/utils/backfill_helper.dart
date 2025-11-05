import 'package:cloud_firestore/cloud_firestore.dart';

/// Backfill helper that can be used in tests or server-side Dart code.
/// It will populate reporterNickname and reportedNickname for recent reports
/// when the corresponding user documents contain a non-empty `nickname` field.
Future<int> backfillRecentReports(
  FirebaseFirestore db, {
  int limit = 500,
}) async {
  final snap = await db
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .get();

  final Map<String, String?> cache = {};
  int updates = 0;

  Future<String?> nicknameFor(String uid) async {
    if (cache.containsKey(uid)) return cache[uid];
    try {
      final u = await db.collection('users').doc(uid).get();
      final nick = (u.data()?['nickname'] as String?)?.trim();
      cache[uid] = (nick != null && nick.isNotEmpty) ? nick : null;
    } catch (_) {
      cache[uid] = null;
    }
    return cache[uid];
  }

  for (final doc in snap.docs) {
    final data = doc.data();
    final reporterId = data['reporterId'] as String?;
    final reportedId = data['reportedUserId'] as String?;
    String? reporterNickname = (data['reporterNickname'] as String?)?.trim();
    String? reportedNickname = (data['reportedNickname'] as String?)?.trim();

    final Map<String, dynamic> updateData = {};
    if ((reporterNickname == null || reporterNickname.isEmpty) &&
        reporterId != null) {
      final n = await nicknameFor(reporterId);
      if (n != null) updateData['reporterNickname'] = n;
    }
    if ((reportedNickname == null || reportedNickname.isEmpty) &&
        reportedId != null) {
      final n = await nicknameFor(reportedId);
      if (n != null) updateData['reportedNickname'] = n;
    }

    if (updateData.isNotEmpty) {
      await doc.reference.set(updateData, SetOptions(merge: true));
      updates++;
    }
  }

  return updates;
}
