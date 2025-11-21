// Test script for Firestore security rules using the emulator
// Requires: npm install @firebase/rules-unit-testing firebase-admin
// Run emulator first: `firebase emulators:start --only firestore,auth` (in project root)
// Then run: `node scripts/test_firestore_rules.js`

const fs = require('fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

async function main() {
  const rules = fs.readFileSync('firestore.rules', 'utf8');

  const testEnv = await initializeTestEnvironment({
    projectId: 'wvsu-space',
    firestore: { rules },
  });

  // Authenticated context: normal user
  const aliceAuth = { uid: 'alice', token: { email: 'alice@wvsu.edu.ph' } };
  const alice = testEnv.authenticatedContext(aliceAuth.uid, aliceAuth.token);
  const aliceDb = alice.firestore();

  // Authenticated context: developer test email
  const devAuth = { uid: 'dev', token: { email: 'jet3danocup@gmail.com' } };
  const dev = testEnv.authenticatedContext(devAuth.uid, devAuth.token);
  const devDb = dev.firestore();

  // Attempt allowed create (WVSU email)
  console.log('Test: creating users/alice with WVSU email should succeed');
  await assertSucceeds(
    aliceDb.collection('users').doc('alice').set({
      nickname: 'Alice',
      email: 'alice@wvsu.edu.ph',
      createdAt: { __datatype__: 'timestamp' },
      standing: 100,
      uid: 'alice',
    })
  ).then(() => console.log('  OK'))
    .catch((e) => console.error('  FAIL', e));

  // Attempt denied create (non-WVSU)
  console.log('Test: creating users/bob with non-WVSU email should fail');
  const bob = testEnv.authenticatedContext('bob', { email: 'bob@gmail.com' }).firestore();
  await assertFails(
    bob.collection('users').doc('bob').set({
      nickname: 'Bob',
      email: 'bob@gmail.com',
      createdAt: { __datatype__: 'timestamp' },
      standing: 100,
      uid: 'bob',
    })
  ).then(() => console.log('  OK'))
    .catch((e) => console.error('  FAIL', e));

  // Dev email exception should succeed
  console.log('Test: creating users/dev with dev email exception should succeed');
  await assertSucceeds(
    devDb.collection('users').doc('dev').set({
      nickname: 'Dev',
      email: 'jet3danocup@gmail.com',
      createdAt: { __datatype__: 'timestamp' },
      standing: 100,
      uid: 'dev',
    })
  ).then(() => console.log('  OK'))
    .catch((e) => console.error('  FAIL', e));

  await testEnv.cleanup();
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
