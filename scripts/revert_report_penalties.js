// Revert historical standing penalties that were applied automatically for reports.
// Usage:
//   node revert_report_penalties.js --dry-run
//   node revert_report_penalties.js --confirm
//
// Auth:
// - Uses Application Default Credentials (ADC)
// - Or set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON file

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

try {
  admin.initializeApp();
} catch (_) {}

const db = admin.firestore();

async function main() {
  const dryRun = argv['dry-run'] && !argv['confirm'];
  console.log(`[revert_report_penalties] starting; dryRun=${!!dryRun}`);

  // 1) Find all standing_reports entries created for reports
  const snap = await db.collectionGroup('standing_reports')
    .where('type', '==', 'report')
    .get();

  if (snap.empty) {
    console.log('No report-based standing reports found. Nothing to do.');
    return;
  }

  // Aggregate by userId (parent of standing_reports)
  const byUser = new Map(); // userId -> { totalDelta: number, examples: number }
  for (const doc of snap.docs) {
    const parent = doc.ref.parent.parent; // users/{uid}
    if (!parent) continue;
    const uid = parent.id;
    const delta = Number((doc.data() && doc.data().delta) || 0);
    const cur = byUser.get(uid) || { total: 0, count: 0 };
    cur.total += delta; // deltas are negative; we will reverse their sum
    cur.count += 1;
    byUser.set(uid, cur);
  }

  console.log(`Found ${snap.size} report entries across ${byUser.size} users.`);

  let updatedUsers = 0;
  for (const [uid, agg] of byUser.entries()) {
    if (!agg || !agg.total) continue;
    const reversal = -agg.total; // if total = -12, reversal = +12
    if (reversal === 0) continue;

    console.log(`User ${uid}: reversing ${reversal} (from ${agg.count} report entries)`);

    if (dryRun) continue;
    await db.runTransaction(async (tx) => {
      const userRef = db.collection('users').doc(uid);
      const userSnap = await tx.get(userRef);
      const current = (userSnap.exists && userSnap.data().standing) || 100;
      const newStanding = Math.max(0, Math.min(100, Number(current) + reversal));
      tx.set(userRef, { standing: newStanding }, { merge: true });
      tx.set(userRef.collection('standing_reports').doc(), {
        type: 'report_penalty_reversal',
        delta: reversal,
        time: admin.firestore.FieldValue.serverTimestamp(),
        note: 'Automated reversal of legacy report penalties',
      });
    });
    updatedUsers += 1;
  }

  // 2) Mark all reports without status as pending (optional)
  const reports = await db.collection('reports').where('status', '==', null).get().catch(() => ({ empty: true, docs: [] }));
  let updatedReports = 0;
  if (reports && !reports.empty && !dryRun) {
    const batch = db.batch();
    for (const d of reports.docs) {
      batch.set(d.ref, { status: 'pending' }, { merge: true });
      updatedReports += 1;
    }
    if (updatedReports > 0) await batch.commit();
  }

  console.log(`[revert_report_penalties] done. Users updated: ${updatedUsers}, reports marked pending: ${updatedReports}`);
}

main().catch((e) => {
  console.error('Failed:', e);
  process.exit(1);
});
