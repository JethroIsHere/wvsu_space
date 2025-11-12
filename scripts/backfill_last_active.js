// Backfill script to populate users/* lastActiveAt when missing
// Strategy:
// 1) If user.lastActive exists and lastActiveAt is missing, copy lastActive -> lastActiveAt
// 2) Otherwise, best-effort derive from latest session message timestamp where user is a participant
// Notes:
// - Read-only for sessions/messages; writes only to users/{uid}
// - Safe to run multiple times; only updates when lastActiveAt is missing
//
// Usage:
//   node backfill_last_active.js --dry-run
//   node backfill_last_active.js --project your-project-id --batch 300

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

const dryRun = !!argv['dry-run'] || !!argv['dryrun'] || !!argv['dry'];
const projectId = argv['project'] || process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT;
const batchSize = parseInt(argv['batch'] || '300', 10) || 300;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: projectId || undefined });
}

const db = admin.firestore();

async function latestMessageTimeForUser(uid) {
  // Scan sessions where user is a participant, then check last message time.
  // This is potentially expensive; we keep it bounded by ordering and limiting.
  // Requires that sessions store participants array and messages have 'ts' timestamp.
  try {
    const sessionsSnap = await db
      .collection('sessions')
      .where('participants', 'array-contains', uid)
      // Avoid requiring a composite index; we'll scan a small set
      .limit(50)
      .get();

    let best = null;
    for (const s of sessionsSnap.docs) {
      const messagesRef = s.ref.collection('messages');
      const latestMsg = await messagesRef.orderBy('ts', 'desc').limit(1).get();
      const msgTs = latestMsg.empty ? null : latestMsg.docs[0].get('ts');
      if (msgTs && msgTs.toMillis) {
        const dt = new Date(msgTs.toMillis());
        if (!best || dt > best) best = dt;
      }
    }
    return best;
  } catch (e) {
    console.warn('latestMessageTimeForUser failed', uid, e);
    return null;
  }
}

(async () => {
  console.log('Starting lastActiveAt backfill', { dryRun, projectId, batchSize });
  let processed = 0;
  let updated = 0;

  try {
    const usersSnap = await db.collection('users').get();
    for (const userDoc of usersSnap.docs) {
      processed++;
      const uid = userDoc.id;
      const data = userDoc.data() || {};
      const lastActiveAt = data.lastActiveAt || null;
      const legacy = data.lastActive || null;

      if (lastActiveAt) continue; // already has value

      const update = {};
      let source = null;

      if (legacy) {
        update.lastActiveAt = legacy;
        // also keep legacy field as-is
        source = 'legacy:lastActive';
      } else {
        const derived = await latestMessageTimeForUser(uid);
        if (derived) {
          update.lastActiveAt = admin.firestore.Timestamp.fromDate(derived);
          source = 'derived:messages';
        }
      }

      if (Object.keys(update).length === 0) continue;

      console.log(`[update] users/${uid}`, update, `source=${source}`);
      if (!dryRun) {
        await userDoc.ref.set(update, { merge: true });
        updated++;
      }
    }

    console.log('Backfill complete', { processed, updated, dryRun });
  } catch (e) {
    console.error('Backfill failed', e);
    process.exit(2);
  }
})();
