# Supabase Setup Checklist

## What Supabase is in this app

Think of Supabase like this:

- Firestore collections -> Postgres tables
- Firebase Auth -> Supabase Auth
- Firestore rules -> Supabase RLS policies
- Firebase project config -> Supabase project URL + anon key

So your "Firestore-like" setup in Supabase is not a document tree. It is:

- `tests`
- `questions`
- `question_states`
- `test_attempts`
- `draft_attempts`
- `user_settings`

The security layer is RLS, which decides who can read or write each table.

## What I need from you

To finish the live cutover, I need these 4 things:

1. Supabase project URL
2. Supabase anon public key
3. Your admin email address
4. Your choice on old Firebase user data:
   - migrate old users later
   - or start fresh on Supabase

## What you need to do in Supabase

1. Create a new Supabase project.
2. Open SQL Editor.
3. Run [supabase-schema.sql](/C:/Users/Dr.%20Yogesh/Documents/supabase%20website%20file/upsc-vault-test-v1/docs/supabase-schema.sql).
4. In Authentication, enable Email login.
5. Sign up once in the app using your admin email.
6. In SQL Editor, run this after your first sign-in:

```sql
insert into public.admin_users (user_id)
select id
from auth.users
where email = 'YOUR_ADMIN_EMAIL_HERE'
on conflict (user_id) do nothing;
```

That makes your account able to upload/delete tests from the Admin section.

## How to connect this project

This project now reads Supabase config from either:

- `window.__SUPABASE_URL__` and `window.__SUPABASE_ANON_KEY__`
- or browser `localStorage`

If you want me to hardwire them into this folder, send me:

- project URL
- anon key

and I will add them in the current folder only.

## What happens to JSON test files

Your JSON files stay useful.

Use them in either of these two ways:

- Admin upload inside the app
- one-time script import later

For now, the easiest path is:

1. finish Supabase auth and tables
2. log in as admin
3. upload the same JSON test files from Admin
4. Supabase stores them into `tests` and `questions`

## Recommended first cut

Do not migrate old Firebase user history first.

First finish:

1. auth
2. schema
3. admin upload
4. public test reading

After that, if needed, we can import old attempts and notes.
