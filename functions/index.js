'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');

try {
  admin.initializeApp();
} catch (e) {
  // no-op for re-initialize in emulator
}

const db = admin.firestore();

// Callable: Atomically match a user with a partner and create a session.
// Input: { mode: 'random'|'keyword', keywords: string[] }
// Output: { status: 'paired', sessionId } | { status: 'waiting' }
exports.matchUser = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    try {
      const uid = context.auth && context.auth.uid;
      if (!uid) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
      }

      const mode = (data && data.mode) === 'keyword' ? 'keyword' : 'random';
      const keywords = Array.isArray(data && data.keywords)
        ? data.keywords.map((x) => String(x)).slice(0, 10)
        : [];

      const queueRef = db.collection('matchQueue').doc(uid);
      const now = admin.firestore.FieldValue.serverTimestamp();

      // Ensure caller is marked waiting in the queue
      await queueRef.set(
        {
          uid,
          mode,
          keywords,
          status: 'waiting',
          createdAt: now,
        },
        { merge: true }
      );

      // Build a small candidate window to try pairing
      let q = db
        .collection('matchQueue')
        .where('status', '==', 'waiting')
        .where('mode', '==', mode)
        .limit(25);

      // Prefer keyword overlap if in keyword mode
      let candidates = [];
      try {
        if (mode === 'keyword' && keywords.length > 0) {
          const q2 = db
            .collection('matchQueue')
            .where('status', '==', 'waiting')
            .where('mode', '==', 'keyword')
            .where('keywords', 'array-contains-any', keywords)
            .limit(25);
          const snap2 = await q2.get();
          candidates = snap2.docs;
        }
      } catch (e) {
        console.warn('Keyword query failed (likely missing index), falling back', e);
      }

      if (candidates.length === 0) {
        try {
          const snap = await q.get();
          candidates = snap.docs;
        } catch (e) {
          // Missing composite index for (status, mode). Fall back to a simpler
          // query and filter by mode on the server to avoid failing.
          console.warn('Base query (status+mode) failed, falling back', e);
          const snapSimple = await db
            .collection('matchQueue')
            .where('status', '==', 'waiting')
            .limit(25)
            .get();
          candidates = snapSimple.docs.filter((d) => {
            const data = d.data();
            return data && data.mode === mode;
          });
        }
      }

      // Filter out self and non-overlapping keyword entries (if in keyword mode)
      const kwSet = new Set(keywords);
      const filtered = candidates.filter((d) => {
        const data = d.data();
        if (!data || !data.uid) return false;
        if (data.uid === uid) return false;
        if (mode === 'keyword' && Array.isArray(data.keywords) && kwSet.size > 0) {
          const their = new Set(data.keywords.map((x) => String(x)));
          const overlap = [...kwSet].some((k) => their.has(k));
          if (!overlap) return false;
        }
        return true;
      });

      for (const cand of filtered) {
        const result = await tryPair(uid, cand, mode);
        if (result && result.sessionId) {
          return { status: 'paired', sessionId: result.sessionId };
        }
      }

      return { status: 'waiting' };
    } catch (e) {
      console.error('matchUser failed', e);
      // Surface context back to client for easier debugging
      throw new functions.https.HttpsError('internal', 'match-failed', {
        message: e && e.message ? String(e.message) : String(e),
        stack: e && e.stack ? String(e.stack) : undefined,
      });
    }
  });

async function tryPair(uid, candidateDoc, mode) {
  const candRef = candidateDoc.ref;
  const sessionRef = db.collection('sessions').doc();
  const myQueueRef = db.collection('matchQueue').doc(uid);

  try {
    await db.runTransaction(async (tx) => {
      const candSnap = await tx.get(candRef);
      if (!candSnap.exists) throw new Error('candidate-missing');
      const cand = candSnap.data();
      if (!cand || cand.status !== 'waiting' || !cand.uid) {
        throw new Error('candidate-not-waiting');
      }

      const mySnap = await tx.get(myQueueRef);
      const my = mySnap.exists ? mySnap.data() : { uid };

      const participants = [uid, cand.uid];
      tx.set(sessionRef, {
        participants,
        mode,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(myQueueRef, {
        status: 'paired',
        sessionId: sessionRef.id,
        partner: cand.uid,
      });

      tx.update(candRef, {
        status: 'paired',
        sessionId: sessionRef.id,
        partner: uid,
      });
    });

    return { sessionId: sessionRef.id };
  } catch (e) {
    console.error('tryPair failed', e);
    // Transaction conflict or permission denied; skip this candidate
    return null;
  }
}

// Callable: delete a user's account and associated top-level documents.
// This performs a best-effort server-side cleanup and deletes the Auth user.
// Input: { dryRun: boolean }
exports.deleteUserAccount = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    try {
      const uid = context.auth && context.auth.uid;
      if (!uid) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
      }

      const dryRun = data && data.dryRun === true;
      const results = { deleted: [], errors: [] };

      // Delete the users/{uid} document (recursive delete if available)
      const userRef = db.collection('users').doc(uid);
      try {
        if (typeof admin.firestore().recursiveDelete === 'function') {
          if (!dryRun) {
            await admin.firestore().recursiveDelete(userRef);
            results.deleted.push(`users/${uid}`);
          } else {
            const exists = (await userRef.get()).exists;
            if (exists) results.deleted.push(`users/${uid}`);
          }
        } else {
          // Fallback: delete the doc only
          const snap = await userRef.get();
          if (snap.exists) {
            if (!dryRun) await userRef.delete();
            results.deleted.push(`users/${uid}`);
          }
        }
      } catch (e) {
        console.error('failed deleting user doc', e);
        results.errors.push({ path: `users/${uid}`, error: String(e) });
      }

      // Delete matching reports where the user is reporter or reported
      try {
        const queries = [
          db.collection('reports').where('reporterUid', '==', uid),
          db.collection('reports').where('reportedUid', '==', uid),
        ];
        for (const q of queries) {
          const snap = await q.get();
          const docs = snap.docs;
          if (docs.length === 0) continue;
          // Batch deletes in chunks of 500
          for (let i = 0; i < docs.length; i += 500) {
            const batch = db.batch();
            const chunk = docs.slice(i, i + 500);
            for (const d of chunk) batch.delete(d.ref);
            if (!dryRun) await batch.commit();
          }
          results.deleted.push(`reports (${docs.length})`);
        }
      } catch (e) {
        console.error('failed deleting reports', e);
        results.errors.push({ path: 'reports', error: String(e) });
      }

      // Add more collection cleanups here as needed (posts, messages, etc.)

      // Finally delete the auth user
      try {
        if (!dryRun) {
          await admin.auth().deleteUser(uid);
          results.deleted.push(`auth/${uid}`);
        } else {
          results.deleted.push(`auth/${uid}`);
        }
      } catch (e) {
        console.error('failed deleting auth user', e);
        results.errors.push({ path: `auth/${uid}`, error: String(e) });
      }

      return { success: true, dryRun: !!dryRun, results };
    } catch (e) {
      console.error('deleteUserAccount failed', e);
      throw new functions.https.HttpsError('internal', 'delete-failed', {
        message: e && e.message ? String(e.message) : String(e),
      });
    }
  });
