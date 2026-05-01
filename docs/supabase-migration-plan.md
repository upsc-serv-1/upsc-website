# Firebase to Supabase Migration Plan

## Why this app is getting expensive on Firebase

The current app shape increases Firestore reads:

- `src/modules/firestore-data.js:145` loads every public test document with `getDocs(...)`.
- `src/modules/firestore-data.js:121-135` stores the full `questions` array inside each test document.
- `src/modules/firestore-data.js:212-220` loads all attempts for a user, then filters in the browser.
- `src/modules/firestore-data.js:230-233` loads all question states for a user.
- `src/app.js:939`, `src/app.js:975`, `src/app.js:1010`, `src/app.js:1557` write question-state changes frequently.
- `src/app.js:1569`, `src/app.js:1601`, `src/app.js:7170`, `src/app.js:7176` resave full attempt payloads repeatedly.

This means every shared visit can read a lot of data even before the user starts a test.

## Good news for this codebase

This app is a strong Supabase candidate because:

- Auth is basic email/password only.
- Most content is already available as local JSON imports.
- The public test library is mostly read-heavy and structured.
- User data maps cleanly to relational tables.

## Recommended migration approach

Use Supabase for:

- Auth
- Postgres database
- Row Level Security (RLS)
- Storage only if you later move PDFs or assets there

Do not copy the current Firestore nesting one-to-one.

Instead, normalize it into tables:

- `tests`
- `questions`
- `question_states`
- `test_attempts`
- `draft_attempts`
- `user_settings`
- `admin_users`

## Mapping from current Firebase paths

Current Firestore path to Supabase target:

- `artifacts/{appId}/public/shared/tests/{testId}` -> `public.tests` and `public.questions`
- `artifacts/{appId}/users/{uid}/questionStates/{questionId}` -> `public.question_states`
- `artifacts/{appId}/users/{uid}/testAttempts/{attemptId}` -> `public.test_attempts`
- `artifacts/{appId}/users/{uid}/draftAttempts/{testId}` -> `public.draft_attempts`
- `artifacts/{appId}/users/{uid}/settings/profile` -> `public.user_settings`
- Firestore rules based admin gating -> Supabase RLS policies plus `public.admin_users`

## Recommended data model

### `tests`

Store only test-level metadata here:

- `id`
- `title`
- `provider`
- `series`
- `level`
- `year`
- `subject`
- `section_group`
- `paper_type`
- `question_count`
- `default_minutes`
- `source_mode`
- `is_demo_available`

### `questions`

Store one row per question:

- `id`
- `test_id`
- `question_number`
- `question_text`
- `statement_lines`
- `question_blocks`
- `options`
- `correct_answer`
- `explanation_markdown`
- `source`
- `subject`
- `section_group`
- `micro_topic`

### `question_states`

One row per user and question:

- `user_id`
- `question_id`
- `test_id`
- `selected_answer`
- `confidence`
- `note`
- `highlight_text`
- `saved_folders`
- `review_tags`
- `question_type_tags`
- `review_difficulty`
- `is_incorrect_last_attempt`
- `marked_tough`
- `marked_must_revise`
- `attempts_history`
- `spaced_revision`
- `updated_at`

### `test_attempts`

Keep attempt metadata in columns and the detailed question snapshot in JSONB:

- `id`
- `user_id`
- `test_id`
- `title`
- `provider`
- `subject`
- `explanation_mode`
- `timer_mode`
- `timer_minutes`
- `started_at`
- `submitted_at`
- `score`
- `attempt_payload`

### `draft_attempts`

- `user_id`
- `test_id`
- `attempt_payload`
- `updated_at`

### `user_settings`

- `user_id`
- `full_name`
- `display_name`
- `deck_intervals`
- `custom_tags`
- `folders`
- `updated_at`

## Why Supabase is likely better for this app

- You are not billed per document read in the same Firestore way.
- Postgres handles filtered queries better for things like attempts by `test_id`, question states by `user_id`, and question search.
- You can move keyword search to SQL indexes later.
- Your public library can be split into light metadata reads and per-test question reads.

## What to change in the frontend

### Auth

Replace Firebase Auth with Supabase Auth:

- `createUserWithEmailAndPassword` -> `supabase.auth.signUp`
- `signInWithEmailAndPassword` -> `supabase.auth.signInWithPassword`
- `sendPasswordResetEmail` -> `supabase.auth.resetPasswordForEmail`
- `onAuthStateChanged` -> `supabase.auth.onAuthStateChange`
- `signOut` -> `supabase.auth.signOut`

### Data layer

Replace Firestore calls with table operations:

- `loadPublicTests()` should fetch only test metadata first.
- Questions should load only for the chosen test or filtered practice mode.
- `loadLatestAttempt(uid, testId)` should query `test_attempts` with a filter and descending `submitted_at`.
- `loadAllQuestionStates(uid)` should only run when that full dataset is truly needed.
- Frequent autosaves should be debounced.

## Migration order

1. Create a Supabase project.
2. Run the SQL schema in `docs/supabase-schema.sql`.
3. Enable email/password auth in Supabase.
4. Import public test JSON into `tests` and `questions`.
5. Switch the app auth module.
6. Switch public library reads.
7. Switch user state writes and reads.
8. Import or sunset old Firebase user history.
9. Turn Firebase into read-only for a short transition window.
10. Remove Firebase once Supabase production traffic is stable.

## Best way to copy the data

### Public tests and questions

For this codebase, the easiest path is:

1. Reuse the local JSON files already in `src/data/imports/`.
2. Transform them into two CSV or JSON streams:
   - tests
   - questions
3. Import those into Supabase.

This is better than exporting nested Firestore test documents because your source files are already cleaner.

### User data

For user attempts, drafts, settings, and question states:

1. Export Firestore collections with a one-time admin script.
2. Convert Firebase `uid` into Supabase `auth.users.id` mappings.
3. Insert into `question_states`, `test_attempts`, `draft_attempts`, and `user_settings`.

If this is still an internal or early-stage app, you may choose not to migrate old user history and just migrate public content first.

## When not to migrate old user history

Skip old user-data migration if:

- very few users exist
- most value is in the question bank, not past attempts
- you want the fastest cutover
- your current Firebase bill is mainly from public reads, not stored historical data

## Cost expectations

As of April 10, 2026, official Supabase docs indicate:

- Free plan: 2 active free projects, 500 MB database, 50,000 MAU, 5 GB egress included
- Pro plan: $25 per organization/month
- Pro includes 100,000 MAU, 250 GB egress, 8 GB database disk per project, and 100 GB storage before overages
- Additional active projects on paid orgs add compute cost; docs show micro compute at about $10/month per project before credits

This app likely fits well on:

- Free plan for development and testing
- Pro plan once real users start using it

For your type of app, Supabase is often easier to predict than Firestore when large public datasets are being repeatedly loaded by many visitors.

## Main tradeoffs and cons

- Supabase is not a drop-in replacement for Firestore. We must redesign the data access layer.
- RLS is powerful, but you must write policies carefully.
- If you rely heavily on realtime everywhere, careless subscriptions can still create usage and complexity.
- Large unindexed SQL queries can also get slow, so indexes matter.
- If you keep everything in giant JSONB blobs, you lose many of the relational benefits.

## Practical recommendation for this project

Do this, in order:

1. Migrate only public test content first.
2. Change the app to load test metadata separately from question payloads.
3. Move auth and new user progress to Supabase.
4. Decide later whether old Firebase user history is worth importing.

That gives you the biggest cost relief fastest.
