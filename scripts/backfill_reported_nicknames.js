// Safe backfill script for reportedNickname/reporterNickname on reports
// Usage:
//   node backfill_reported_nicknames.js --dry-run
//   node backfill_reported_nicknames.js --project your-project-id --batch 200

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

const dryRun = !!argv['dry-run'] || !!argv['dryrun'] || !!argv['dry'];
const projectId = argv['project'] || process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT;
const batchSize = parseInt(argv['batch'] || '200', 10) || 200;

if (!admin.apps.length) {
  // Prefer ADC, but allow providing a service account via GOOGLE_APPLICATION_CREDENTIALS
  admin.initializeApp({ projectId: projectId || undefined });
}

const db = admin.firestore();

(async () => {
  console.log('Starting backfill', { dryRun, projectId, batchSize });
  let updated = 0;
  try {
    const snap = await db.collection('reports')
      .orderBy('createdAt', 'desc')
      .limit(1000)
      .get();

    const cache = new Map();

    for (const doc of snap.docs) {
      const data = doc.data();
      const reporterId = data.reporterId;
      const reportedId = data.reportedUserId;
      const update = {};

      async function nicknameFor(uid) {
        if (!uid) return null;
        if (cache.has(uid)) return cache.get(uid);
        try {
          const u = await db.collection('users').doc(uid).get();
          const nick = (u.data() || {}).nickname || null;
          cache.set(uid, nick);
          return nick;
        } catch (e) {
          console.warn('Failed to load user', uid, e);
          cache.set(uid, null);
          return null;
        }
      }

      if ((!data.reporterNickname || data.reporterNickname === '') && reporterId) {
        const n = await nicknameFor(reporterId);
        if (n) update.reporterNickname = n;
      }
      if ((!data.reportedNickname || data.reportedNickname === '') && reportedId) {
        const n = await nicknameFor(reportedId);
        if (n) update.reportedNickname = n;
      }

      if (Object.keys(update).length > 0) {
        console.log('Would update', doc.id, update);
        if (!dryRun) {
          await doc.ref.set(update, { merge: true });
          updated++;
        }
      }
    }

    console.log('Backfill complete. Updated', updated);
  } catch (e) {
    console.error('Backfill failed', e);
    process.exit(2);
  }
})();
