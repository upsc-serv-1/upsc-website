create extension if not exists pgcrypto;

create table if not exists public.admin_users (
    user_id uuid primary key references auth.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

create table if not exists public.tests (
    id text primary key,
    title text not null,
    provider text,
    series text,
    level text,
    year integer,
    subject text,
    section_group text,
    paper_type text,
    question_count integer not null default 0,
    default_minutes integer,
    source_mode text,
    is_demo_available boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.questions (
    id text primary key,
    test_id text not null references public.tests(id) on delete cascade,
    question_number integer,
    question_text text,
    statement_lines jsonb not null default '[]'::jsonb,
    question_blocks jsonb not null default '[]'::jsonb,
    options jsonb not null default '{}'::jsonb,
    correct_answer text,
    explanation_markdown text,
    source jsonb not null default '{}'::jsonb,
    subject text,
    section_group text,
    micro_topic text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.question_states (
    user_id uuid not null references auth.users(id) on delete cascade,
    question_id text not null references public.questions(id) on delete cascade,
    test_id text not null references public.tests(id) on delete cascade,
    selected_answer text,
    confidence text,
    note text not null default '',
    highlight_text text not null default '',
    saved_folders text[] not null default '{}',
    review_tags text[] not null default '{}',
    question_type_tags text[] not null default '{}',
    review_difficulty text,
    is_incorrect_last_attempt boolean not null default false,
    marked_tough boolean not null default false,
    marked_must_revise boolean not null default false,
    attempts_history jsonb not null default '[]'::jsonb,
    spaced_revision jsonb,
    updated_at timestamptz not null default now(),
    primary key (user_id, question_id)
);

create table if not exists public.test_attempts (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    test_id text not null references public.tests(id) on delete cascade,
    title text,
    provider text,
    subject text,
    explanation_mode text,
    timer_mode text,
    timer_minutes integer,
    started_at timestamptz,
    submitted_at timestamptz not null default now(),
    score numeric,
    attempt_payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists public.draft_attempts (
    user_id uuid not null references auth.users(id) on delete cascade,
    test_id text not null references public.tests(id) on delete cascade,
    attempt_payload jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now(),
    primary key (user_id, test_id)
);

create table if not exists public.user_settings (
    user_id uuid primary key references auth.users(id) on delete cascade,
    full_name text not null default '',
    display_name text not null default '',
    deck_intervals jsonb not null default '{"again":0,"hard":1,"good":3,"easy":7}'::jsonb,
    custom_tags jsonb not null default '[]'::jsonb,
    folders jsonb not null default '[]'::jsonb,
    updated_at timestamptz not null default now()
);

create index if not exists idx_tests_provider_subject_section
    on public.tests(provider, subject, section_group);

create index if not exists idx_questions_test_id
    on public.questions(test_id);

create index if not exists idx_questions_subject_section_micro
    on public.questions(subject, section_group, micro_topic);

create index if not exists idx_question_states_user_test
    on public.question_states(user_id, test_id);

create index if not exists idx_test_attempts_user_test_submitted
    on public.test_attempts(user_id, test_id, submitted_at desc);

alter table public.admin_users enable row level security;
alter table public.tests enable row level security;
alter table public.questions enable row level security;
alter table public.question_states enable row level security;
alter table public.test_attempts enable row level security;
alter table public.draft_attempts enable row level security;
alter table public.user_settings enable row level security;

create policy "public read tests"
on public.tests
for select
to anon, authenticated
using (true);

create policy "public read questions"
on public.questions
for select
to anon, authenticated
using (true);

create policy "admins manage tests"
on public.tests
for all
to authenticated
using (exists (
    select 1
    from public.admin_users admin_users
    where admin_users.user_id = (select auth.uid())
))
with check (exists (
    select 1
    from public.admin_users admin_users
    where admin_users.user_id = (select auth.uid())
));

create policy "admins manage questions"
on public.questions
for all
to authenticated
using (exists (
    select 1
    from public.admin_users admin_users
    where admin_users.user_id = (select auth.uid())
))
with check (exists (
    select 1
    from public.admin_users admin_users
    where admin_users.user_id = (select auth.uid())
));

create policy "users read own question states"
on public.question_states
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users write own question states"
on public.question_states
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "users read own attempts"
on public.test_attempts
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users write own attempts"
on public.test_attempts
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "users read own drafts"
on public.draft_attempts
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users write own drafts"
on public.draft_attempts
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "users read own settings"
on public.user_settings
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "users write own settings"
on public.user_settings
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
