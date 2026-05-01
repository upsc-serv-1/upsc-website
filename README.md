# UPSC Vault Test Practice

Separate multi-file test-practice site scaffold for `upsc-vault-test-v1`.

## Purpose

- Keep the main UPSC Vault site untouched.
- Build a dedicated practice engine for tests, review, notes, and analytics.
- Use the same design language while isolating Firebase data paths from `upsc-vault-v5`.

## Current Status

- Project scaffold created
- Theme and taxonomy preview added
- Firestore namespace model drafted
- Forum SFG Level 1 Polity Test 1 selected as the first import target
- Forum SFG Level 1 Polity Test 1 JSON dataset generated from the SOL PDF
- Email/password auth shell, practice flow, review flow, and analytics starter screens added

## Next Build Steps

1. Fill `src/firebase-config.js` with the real Firebase web app keys for this app.
2. Build email/password auth UI and role handling.
3. Build the practice page shell.
4. Build the review page shell.
5. Build analytics cards and charts.
6. Import `Forum SFG Level 1 -> Polity -> Test 1`.
