// Script to fix standing scores for users
// Run with: node fix_standing.js

const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json'); // You'll need to download this

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixUserStanding(uid) {
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    console.log(`User ${uid} not found`);
    return;
  }
  
  const userData = userDoc.data();
  const currentStanding = userData.standing || 0;
  
  console.log(`Current standing: ${currentStanding}`);
  
  // Get all standing reports
  const reportsSnapshot = await userRef.collection('standing_reports')
    .orderBy('time', 'asc')
    .get();
  
  if (reportsSnapshot.empty) {
    console.log('No reports found');
    // No reports, should be 100
    await userRef.update({ standing: 100 });
    console.log('Set standing to 100 (no reports)');
    return;
  }
  
  // Calculate standing from reports
  let calculatedStanding = 100; // Start at 100
  reportsSnapshot.forEach(doc => {
    const delta = doc.data().delta || 0;
    calculatedStanding += delta;
    console.log(`Report: ${doc.data().title}, Delta: ${delta}, New standing: ${calculatedStanding}`);
  });
  
  console.log(`Calculated standing: ${calculatedStanding}`);
  console.log(`Current standing in DB: ${currentStanding}`);
  
  if (calculatedStanding !== currentStanding) {
    await userRef.update({ standing: calculatedStanding });
    console.log(`✅ Updated standing from ${currentStanding} to ${calculatedStanding}`);
  } else {
    console.log('✅ Standing is correct');
  }
}

// Get UID from command line
const uid = process.argv[2];

if (!uid) {
  console.log('Usage: node fix_standing.js <user_id>');
  process.exit(1);
}

fixUserStanding(uid)
  .then(() => {
    console.log('Done');
    process.exit(0);
  })
  .catch(error => {
    console.error('Error:', error);
    process.exit(1);
  });
