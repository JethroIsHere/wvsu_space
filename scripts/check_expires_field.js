// scripts/check_expires_field.js
// Usage:
// 1) npm install firebase-admin
// 2) set $env:GOOGLE_APPLICATION_CREDENTIALS to your service account JSON (PowerShell)
// 3) node .\scripts\check_expires_field.js

const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function run() {
  console.log('Scanning up to 2000 documents in gratitude_posts...');
  const pageSize = 500;
  let cursor = null;
  let totalChecked = 0;
  let missing = 0;
  let badType = 0;
  const badSamples = [];

  while (true) {
    let q = db.collection('gratitude_posts').orderBy('__name__').limit(pageSize);
    if (cursor) q = q.startAfter(cursor);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      totalChecked++;
      const e = doc.get('expiresAt');
      if (e === undefined) {
        missing++;
      } else if (!(e instanceof admin.firestore.Timestamp)) {
        badType++;
        if (badSamples.length < 10) {
          badSamples.push({ id: doc.id, value: e });
        }
      }
    }

    cursor = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
    // Limit to 2000 docs to avoid long scans; remove this guard if you want full scan
    if (totalChecked >= 2000) break;
  }

  console.log(`Checked ${totalChecked} docs: missing=${missing}, badType=${badType}`);
  if (badSamples.length > 0) {
    console.log('Sample bad docs (id + value):');
    console.log(JSON.stringify(badSamples, null, 2));
  }
  console.log('Done.');
}

run().catch(err => {
  console.error('Error during check:', err);
  process.exit(1);
});
