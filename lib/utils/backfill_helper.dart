import 'package:cloud_firestore/cloud_firestore.dart';

// Backfill helper's goal is to populate reporter/reported nicknames when available.
Future<int> backfillRecentReports(
  FirebaseFirestore db, {
  int limit = 500,
}) async {
  // Read both 'reports' and 'user_reports' to cover test and production data.
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];

  try {
    final reportsSnap = await db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    docs.addAll(reportsSnap.docs);
  } catch (_) {
    // Ignore if collection does not exist
  }

  try {
    final userReportsSnap = await db
        .collection('user_reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    docs.addAll(userReportsSnap.docs);
  } catch (_) {
    // Ignore if absent
  }

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

  for (final doc in docs) {
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
