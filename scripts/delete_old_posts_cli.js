const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function usage() {
  console.log('Usage: node delete_old_posts_cli.js --key <service-account.json> --minutes <minutes> [--force] [--limit <n>]');
  process.exit(1);
}

const argv = require('minimist')(process.argv.slice(2));
const keyPath = argv.key || argv.k;
const minutes = parseInt(argv.minutes || argv.m || '30', 10);
const force = argv.force === true || argv.f === true || argv.force === 'true';
const limit = parseInt(argv.limit || '2000', 10);

if (!keyPath) {
  console.error('Missing --key argument');
  usage();
}

if (!fs.existsSync(keyPath)) {
  console.error('Service account file not found at', keyPath);
  process.exit(2);
}

const serviceAccount = require(path.resolve(keyPath));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function run() {
  const cutoff = new Date(Date.now() - minutes * 60 * 1000);
  console.log(`Scanning up to ${limit} documents older than ${minutes} minutes (before ${cutoff.toISOString()})`);

  const q = db.collection('gratitude_posts')
    .where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoff))
    .orderBy('timestamp')
    .limit(limit);

  const snap = await q.get();
  console.log(`Found ${snap.size} documents matching criteria.`);
  if (snap.empty) return;

  const sample = snap.docs.slice(0, 5).map(d => ({ id: d.id, timestamp: d.get('timestamp') }));
  console.log('Sample docs:', sample);

  if (!force) {
    console.log('Dry-run mode (no deletions). Re-run with --force to delete.');
    return;
  }

  const batchSize = 500;
  const docs = snap.docs;
  for (let i = 0; i < docs.length; i += batchSize) {
    const batch = db.batch();
    const slice = docs.slice(i, i + batchSize);
    slice.forEach(d => batch.delete(d.ref));
    console.log(`Committing batch delete for ${slice.length} docs...`);
    await batch.commit();
  }
  console.log('Deletion complete.');
}

run().catch(err => {
  console.error('Error:', err);
  process.exit(3);
});
