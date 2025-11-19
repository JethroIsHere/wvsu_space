Delete expired Gratitude Wall posts

This file documents the admin script at `scripts/delete_expired_posts.js` which deletes expired `gratitude_posts` documents (those with `expiresAt` in the past).

Quick run (PowerShell):

```powershell
cd <repo-root>
# install dependency (once)
npm install firebase-admin

# set path to your service account JSON and run
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\service-account.json'
node .\scripts\delete_expired_posts.js
```

Why to use this:
- Removes expired express posts now (useful if TTL not yet enabled or if you want immediate cleanup).
- Safe to run multiple times; it will only delete documents with `expiresAt` earlier than the current time.

Recommended follow-up:
- Enable Firestore TTL on the `expiresAt` field in the Firebase Console for automatic server-side deletion.
