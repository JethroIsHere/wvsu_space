import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wvsu_space/utils/backfill_helper.dart';

void main() {
  test('backfillRecentReports populates missing nicknames', () async {
    final db = FakeFirebaseFirestore();

    // Seed users
    await db.collection('users').doc('u1').set({'nickname': 'Alice'});
    await db.collection('users').doc('u2').set({'nickname': 'Bob'});

    // Seed reports: one missing nicknames, one already has
    await db.collection('reports').add({
      'reporterId': 'u1',
      'reportedUserId': 'u2',
      'createdAt': DateTime.now(),
    });

    await db.collection('reports').add({
      'reporterId': 'u1',
      'reportedUserId': 'u2',
      'reporterNickname': 'Existing',
      'createdAt': DateTime.now(),
    });

    final updated = await backfillRecentReports(db, limit: 10);
    // both seeded documents are missing at least one nickname field, so expect 2 updates
    expect(updated, 2);

    final snap = await db.collection('reports').get();
    final docs = snap.docs;
    // Ensure reportedNickname was filled for all docs
    for (final d in docs) {
      final data = d.data();
      expect(data['reportedNickname'], 'Bob');
    }

    // Ensure reporterNickname values include both the existing value and the filled value
    final reporterNicks =
        docs.map((d) => d.data()['reporterNickname'] as String?).toList();
    expect(reporterNicks.contains('Existing'), isTrue);
    expect(reporterNicks.contains('Alice'), isTrue);
  });
}
