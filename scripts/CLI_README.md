# CLI scripts for Gratitude Wall maintenance

These scripts are designed to be copied to a safe folder (outside the repo if you prefer) and run with a Firebase service-account JSON file.

Common requirements

- Node.js (>=14)
- `npm install firebase-admin minimist` (the scripts use `firebase-admin` and `minimist`)

Recommended: create a small folder, copy the script(s) you need, run `npm init -y && npm install firebase-admin minimist`.

Examples

1) Dry-run deletion (no deletions):

```powershell
node .\delete_old_posts_cli.js --key C:\path\to\service-account.json --minutes 30
```

2) Actually delete matching documents:

```powershell
node .\delete_old_posts_cli.js --key C:\path\to\service-account.json --minutes 30 --force
```

3) Check for missing `expiresAt` values:

```powershell
node .\check_expires_field_cli.js --key C:\path\to\service-account.json
```

Using with GitHub Actions

- Add your service account JSON as a repository secret named `FIREBASE_SERVICE_ACCOUNT` (do not commit the file to the repo).
- The workflow at `.github/workflows/delete-expired-posts.yml` will write the secret to `./scripts/service-account.json` and run `delete_old_posts_cli.js` on the schedule or via manual dispatch.

Safety notes

- Dry-run is the default: don't pass `--force` until you've verified the set of documents returned by the dry-run.
- Keep service account keys out of source control.
