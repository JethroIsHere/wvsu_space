const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function usage() {
  console.log('Usage: node check_expires_field_cli.js --key <service-account.json> [--limit <n>]');
  process.exit(1);
}

const argv = require('minimist')(process.argv.slice(2));
const keyPath = argv.key || argv.k;
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
  console.log(`Scanning up to ${limit} documents in gratitude_posts for missing/invalid expiresAt field.`);
  const q = db.collection('gratitude_posts').limit(limit);
  const snap = await q.get();
  console.log(`Checked ${snap.size} documents.`);
  let missing = 0;
  let badType = 0;
  const samplesMissing = [];
  snap.docs.forEach(d => {
    const v = d.get('expiresAt');
    if (v === undefined) {
      missing += 1;
      if (samplesMissing.length < 5) samplesMissing.push(d.id);
    } else {
      // In Node admin SDK, Timestamp is an object with toDate function
      if (!v || typeof v.toDate !== 'function') {
        badType += 1;
      }
    }
  });
  console.log(`Results: missing=${missing}, badType=${badType}`);
  if (samplesMissing.length) console.log('Sample missing ids:', samplesMissing);
}

run().catch(err => {
  console.error('Error:', err);
  process.exit(3);
});
