Backfill scripts

This folder contains admin scripts for backfilling report documents with display-friendly nicknames.

Important:
- Do NOT commit service account JSON to the repository.
- The script will prefer Application Default Credentials (ADC) or the environment variable `GOOGLE_APPLICATION_CREDENTIALS`.

Usage:

1. Install dependencies

   npm install

2. Dry run (safe):

   node backfill_reported_nicknames.js --dry-run

3. Run for real:

   node backfill_reported_nicknames.js --batch 200

You can also set `GOOGLE_APPLICATION_CREDENTIALS` to point to a service account JSON when running in CI or on a machine with a key file.
