/**
 * Backfill missing `expiresAt` on `gratitude_posts` documents.
 *
 * Usage:
 *  # dry-run: show what would be changed
 *  node scripts/backfill_expires.js --dry --limit=500
 *
 *  # run for real (uses your GOOGLE_APPLICATION_CREDENTIALS env var)
 *  node scripts/backfill_expires.js --limit=500
 *
 * Notes:
 *  - Script requires a service account with Firestore read/write access.
 *  - It processes posts in timestamp order in batches of `--limit`.
 *  - For each express post missing `expiresAt` it sets expiresAt = timestamp + 30 minutes.
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
  console.log(`Backfill starting (limit=${LIMIT}) dry=${DRY}`);

  let processed = 0;
  // Query express posts ordered by timestamp
  const q = db.collection('gratitude_posts')
    .where('type', '==', 'express')
    .orderBy('timestamp')
    .limit(LIMIT);

  const snap = await q.get();
  console.log(`Fetched ${snap.docs.length} express posts (batch).`);
  if (snap.empty) {
    console.log('No express posts found.');
    return;
  }

  const batch = db.batch();
  let updates = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    // Consider missing or null expiresAt as needing backfill
    const hasExpires = Object.prototype.hasOwnProperty.call(data, 'expiresAt') && data.expiresAt != null;
    if (hasExpires) continue;

    const ts = data.timestamp;
    if (!ts) {
      console.warn(`${doc.id} missing timestamp — skipping`);
      continue;
    }
    // timestamp is a Firestore Timestamp; convert to Date then add 30 minutes
    const when = ts.toDate();
    const expiresAt = new Date(when.getTime() + 30 * 60 * 1000);
    const expiresTs = admin.firestore.Timestamp.fromDate(expiresAt);

    console.log(`Will set expiresAt for ${doc.id} -> ${expiresAt.toISOString()}`);
    updates += 1;
    if (!DRY) {
      batch.update(doc.ref, { expiresAt: expiresTs });
    }
  }

  if (!DRY && updates > 0) {
    await batch.commit();
    console.log(`Committed ${updates} updates.`);
  } else {
    console.log(`Dry-run: ${updates} would have been updated.`);
  }

  processed = snap.docs.length;
  console.log(`Done. Processed ${processed} docs, updated ${updates} entries.`);
}

run().catch(err => {
  console.error('Backfill failed:', err);
  process.exit(2);
});
