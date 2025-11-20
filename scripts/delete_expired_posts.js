/**
 * Delete expired `gratitude_posts` documents (admin script).
 *
 * Usage:
 *  # dry-run: show which docs would be deleted
 *  node scripts/delete_expired_posts.js --dry --limit=500
 *
 *  # run for real (uses your GOOGLE_APPLICATION_CREDENTIALS env var)
 *  node scripts/delete_expired_posts.js --limit=500
 *
 * Notes:
 *  - Script requires a service account with Firestore read/write access.
 *  - It deletes express posts whose `expiresAt` is <= now.
 *  - Use `--limit` to control how many docs are processed per run.
 */

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

const LIMIT = parseInt(argv.limit || argv.l || '200', 10);
const DRY = !!argv.dry || !!argv.d;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Please set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function run() {
  console.log(`Delete expired posts starting (limit=${LIMIT}) dry=${DRY}`);

  const now = admin.firestore.Timestamp.fromDate(new Date());

  // Query express posts with expiresAt <= now
  const q = db.collection('gratitude_posts')
    .where('type', '==', 'express')
    .where('expiresAt', '<=', now)
    .orderBy('expiresAt')
    .limit(LIMIT);

  const snap = await q.get();
  console.log(`Fetched ${snap.docs.length} expired express posts (batch).`);
  if (snap.empty) {
    console.log('No expired express posts to delete.');
    return;
  }

  if (DRY) {
    for (const d of snap.docs) {
      const data = d.data();
      const expiresAt = data.expiresAt && data.expiresAt.toDate ? data.expiresAt.toDate().toISOString() : data.expiresAt;
      console.log(`DRY: would delete ${d.id} expiresAt=${expiresAt}`);
    }
    console.log(`Dry-run complete: ${snap.docs.length} docs would be deleted.`);
    return;
  }

  const batch = db.batch();
  for (const d of snap.docs) {
    batch.delete(d.ref);
  }
  await batch.commit();
  console.log(`Committed delete of ${snap.docs.length} docs.`);
}

run().catch(err => {
  console.error('Delete expired posts failed:', err);
  process.exit(2);
});
