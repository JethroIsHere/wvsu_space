// Check user data fields for debugging
// Run with: node check_user_data.js

const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, '..', 'firebase_new.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkUserData() {
  try {
    // Query for user with nickname "ha"
    const usersSnapshot = await db.collection('users')
      .where('nickname', '==', 'ha')
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log('User "ha" not found');
      return;
    }

    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    console.log('\n=== User Data for "ha" ===');
    console.log('UID:', userDoc.id);
    console.log('Nickname:', userData.nickname);
    console.log('Student ID:', userData.studentId);
    console.log('Standing (score):', userData.standing);
    console.log('Score (old field):', userData.score);
    console.log('lastActiveAt:', userData.lastActiveAt);
    console.log('lastActive:', userData.lastActive);
    console.log('createdAt:', userData.createdAt);
    console.log('suspended:', userData.suspended);
    console.log('restricted:', userData.restricted);
    console.log('\n=== All Fields ===');
    console.log(JSON.stringify(userData, null, 2));

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit(0);
  }
}

checkUserData();
