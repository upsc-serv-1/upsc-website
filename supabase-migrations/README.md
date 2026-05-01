# Supabase Database Migrations

This folder contains SQL migrations for your Supabase database.

## How to Run Migrations

### Option 1: Using Supabase SQL Editor (Easiest)

1. Go to your Supabase Dashboard: https://app.supabase.io
2. Select your project
3. Click on "SQL Editor" in the left sidebar
4. Click "New query"
5. Copy and paste the contents of `create_user_notes_table.sql`
6. Click "Run" to execute the SQL

### Option 2: Using Supabase CLI

If you have the Supabase CLI installed:

```bash
supabase db push
```

### Option 3: Auto-Create from App (Coming Soon)

We'll add an "Initialize Database" button in the admin panel that runs these migrations automatically.

## Tables Created

### user_notes
Stores user-created notes with highlights:
- `id`: Unique identifier (UUID)
- `user_id`: Reference to auth.users (who owns the note)
- `subject`: Subject category (e.g., "Economy", "Geography")
- `title`: Note title
- `content`: Note content/text
- `items`: JSON array of note items
- `highlights`: JSON array of highlighted text from questions
- `created_at`: When the note was created
- `updated_at`: When the note was last updated

## Row Level Security (RLS)

All tables have RLS enabled, meaning:
- Users can ONLY see their own notes
- Users can ONLY create/update/delete their own notes
- Data is completely isolated between users

## Troubleshooting

If you get errors about missing tables:
1. Make sure you're connected to the correct Supabase project
2. Check that you're running SQL as the postgres user or service_role
3. Verify that the `auth.users` table exists (it should be created automatically by Supabase Auth)
