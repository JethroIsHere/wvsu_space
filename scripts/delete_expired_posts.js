// scripts/delete_expired_posts.js
// Usage:
// 1) Install dependencies: npm install firebase-admin
// 2) Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path
//    e.g. in PowerShell:
//      $env:GOOGLE_APPLICATION_CREDENTIALS='C:\path\to\service-account.json'
// 3) Run: node scripts/delete_expired_posts.js

const admin = require('firebase-admin');

// Initialize using Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS)
admin.initializeApp();

const db = admin.firestore();

async function deleteExpiredBatch() {
  const now = admin.firestore.Timestamp.now();
  const limit = 500; // batch size per loop (500 is safe for Firestore batch)
  let total = 0;

  while (true) {
    const snap = await db
      .collection('gratitude_posts')
      .where('expiresAt', '<', now)
      .limit(limit)
      .get();

    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    total += snap.size;
    console.log(`Deleted ${snap.size} docs (total ${total})`);

    if (snap.size < limit) break; // no more docs beyond this page
  }

  console.log(`Done. Deleted ${total} expired docs.`);
}

deleteExpiredBatch().catch((err) => {
  console.error('Error deleting expired posts:', err);
  process.exitCode = 1;
});
