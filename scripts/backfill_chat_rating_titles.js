// Backfill script to sanitize chat rating titles in users/*/standing_reports
// - Sets type = 'chat_rating' when title indicates a chat rating
// - Replaces title with 'Conversation feedback received'
// - Adds ratingLabel and rating (when inferable) for analytics
//
// Usage:
//   node backfill_chat_rating_titles.js --dry-run
//   node backfill_chat_rating_titles.js --project your-project-id --batch 300

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));

const dryRun = !!argv['dry-run'] || !!argv['dryrun'] || !!argv['dry'];
const projectId = argv['project'] || process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT;
const batchSize = parseInt(argv['batch'] || '300', 10) || 300;

if (!admin.apps.length) {
  // Prefer ADC; allow GOOGLE_APPLICATION_CREDENTIALS
  admin.initializeApp({ projectId: projectId || undefined });
}

const db = admin.firestore();

function parseRatingFromTitle(title) {
  if (!title || typeof title !== 'string') return null;
  const lower = title.toLowerCase();
  if (!lower.startsWith('chat rating')) return null;
  // Expect formats like: "Chat Rating: Poor", "Chat Rating - Good"
  const parts = title.split(/[:\-]/);
  if (parts.length < 2) return null;
  const label = parts[1].trim();
  const map = {
    'poor': 1,
    'fair': 2,
    'good': 3,
    'very good': 4,
    'excellent': 5,
  };
  const key = label.toLowerCase();
  const rating = map[key] || null;
  return { label, rating };
}

(async () => {
  console.log('Starting backfill', { dryRun, projectId, batchSize });
  let processed = 0;
  let updated = 0;

  try {
    // Iterate over users collection in batches
    const usersSnap = await db.collection('users').get();
    for (const userDoc of usersSnap.docs) {
      const userId = userDoc.id;
      const reportsRef = userDoc.ref.collection('standing_reports');

      let last = null;
      while (true) {
        let q = reportsRef.orderBy('time').limit(batchSize);
        if (last) q = q.startAfter(last);
        const snap = await q.get();
        if (snap.empty) break;

        const batch = db.batch();
        for (const doc of snap.docs) {
          processed++;
          const data = doc.data() || {};
          const title = data.title || '';
          const type = data.type || null;

          let needsUpdate = false;
          const update = {};

          // Detect chat rating by explicit type or legacy title prefix
          const looksLikeRating = (type === 'chat_rating') || (typeof title === 'string' && title.toLowerCase().startsWith('chat rating'));
          if (!looksLikeRating) continue;

          // Ensure normalized title and type
          if (title !== 'Conversation feedback received') {
            update.title = 'Conversation feedback received';
            needsUpdate = true;
          }
          if (type !== 'chat_rating') {
            update.type = 'chat_rating';
            needsUpdate = true;
          }

          // Populate ratingLabel/rating if missing and inferable
          if ((data.ratingLabel == null || data.rating == null) && typeof title === 'string') {
            const parsed = parseRatingFromTitle(title);
            if (parsed) {
              if (data.ratingLabel == null) update.ratingLabel = parsed.label;
              if (data.rating == null && parsed.rating != null) update.rating = parsed.rating;
              needsUpdate = true;
            }
          }

          if (needsUpdate) {
            console.log(`[update] users/${userId}/standing_reports/${doc.id}`, update);
            if (!dryRun) batch.set(doc.ref, update, { merge: true });
            updated++;
          }
        }

        if (!dryRun) await batch.commit();
        last = snap.docs[snap.docs.length - 1];

        // Optional: throttle to avoid rate limits
        await new Promise((r) => setTimeout(r, 50));
      }
    }

    console.log('Backfill complete', { processed, updated, dryRun });
  } catch (e) {
    console.error('Backfill failed', e);
    process.exit(2);
  }
})();
