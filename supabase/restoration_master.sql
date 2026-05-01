-- MASTER RESTORATION SCRIPT for Dr. UPSC Website
-- This script recreates all tables, indexes, and functions required for the application.
-- Run this in the Supabase SQL Editor (https://app.supabase.com/project/_/sql)

BEGIN;

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 1. FUNCTIONS
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. CORE TABLES

-- admin_users
CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'editor',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- tests
CREATE TABLE IF NOT EXISTS public.tests (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    provider TEXT,
    institute TEXT,
    program_id TEXT,
    program_name TEXT,
    launch_year INTEGER,
    series TEXT,
    level TEXT,
    year INTEGER,
    subject TEXT,
    subject_test TEXT,
    section_group TEXT,
    paper_type TEXT,
    question_count INTEGER DEFAULT 0,
    default_minutes INTEGER,
    source_mode TEXT,
    is_demo_available BOOLEAN DEFAULT FALSE,
    exam_year INTEGER,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- questions
DROP TABLE IF EXISTS public.questions CASCADE;
CREATE TABLE IF NOT EXISTS public.questions (
    id TEXT PRIMARY KEY,
    test_id TEXT NOT NULL REFERENCES public.tests(id) ON DELETE CASCADE,
    question_number INTEGER,
    question_text TEXT NOT NULL DEFAULT '',
    statement_lines JSONB DEFAULT '[]'::jsonb,
    question_blocks JSONB DEFAULT '[]'::jsonb,
    options JSONB DEFAULT '{}'::jsonb,
    correct_answer TEXT,
    explanation_markdown TEXT DEFAULT '',
    source_attribution_label TEXT,
    source JSONB DEFAULT '{}'::jsonb,
    subject TEXT,
    section_group TEXT,
    micro_topic text,
    is_pyq BOOLEAN DEFAULT FALSE,
    is_ncert BOOLEAN DEFAULT FALSE,
    is_upsc_cse BOOLEAN DEFAULT FALSE,
    is_allied BOOLEAN DEFAULT FALSE,
    is_others BOOLEAN DEFAULT FALSE,
    is_cancelled BOOLEAN DEFAULT FALSE,
    exam TEXT,
    exam_group TEXT,
    exam_year INTEGER,
    exam_category TEXT,
    specific_exam TEXT,
    exam_stage TEXT,
    exam_paper TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- question_states (User progress/bookmarks/notes on specific questions)
DROP TABLE IF EXISTS public.question_states CASCADE;
CREATE TABLE IF NOT EXISTS public.question_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    question_id TEXT NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
    test_id TEXT,
    selected_answer TEXT,
    confidence TEXT,
    note TEXT,
    highlight_text TEXT,
    saved_folders JSONB DEFAULT '[]'::jsonb,
    review_tags JSONB DEFAULT '[]'::jsonb,
    question_type_tags JSONB DEFAULT '[]'::jsonb,
    review_difficulty TEXT,
    is_incorrect_last_attempt BOOLEAN DEFAULT FALSE,
    marked_tough BOOLEAN DEFAULT FALSE,
    marked_must_revise BOOLEAN DEFAULT FALSE,
    attempts_history JSONB DEFAULT '[]'::jsonb,
    spaced_revision JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, question_id)
);


-- test_attempts
CREATE TABLE IF NOT EXISTS public.test_attempts (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    test_id TEXT REFERENCES public.tests(id) ON DELETE CASCADE,
    title TEXT,
    provider TEXT,
    subject TEXT,
    explanation_mode TEXT,
    timer_mode TEXT,
    timer_minutes INTEGER,
    started_at TIMESTAMPTZ,
    submitted_at TIMESTAMPTZ DEFAULT now(),
    score NUMERIC,
    attempt_payload JSONB DEFAULT '{}'::jsonb
);

-- draft_attempts
CREATE TABLE IF NOT EXISTS public.draft_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    test_id TEXT REFERENCES public.tests(id) ON DELETE CASCADE,
    payload JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, test_id)
);

-- user_settings
CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    display_name TEXT,
    deck_intervals JSONB DEFAULT '{"again": 0, "hard": 1, "good": 3, "easy": 7}'::jsonb,
    permissions JSONB DEFAULT '{"accessPdf": true, "accessNotes": true, "accessFlashcards": true, "accessTags": true, "isAdmin": false}'::jsonb,
    custom_tags JSONB DEFAULT '[]'::jsonb,
    folders JSONB DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. FLASHCARD SYSTEM

-- cards
CREATE TABLE IF NOT EXISTS public.cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id TEXT NOT NULL,
    test_id TEXT NOT NULL,
    question_text TEXT NOT NULL DEFAULT '',
    answer_text TEXT NOT NULL DEFAULT '',
    correct_answer TEXT,
    subject TEXT,
    section_group TEXT,
    microtopic TEXT,
    provider TEXT,
    source JSONB DEFAULT '{}'::jsonb,
    explanation_markdown TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(question_id, test_id)
);

-- user_cards
CREATE TABLE IF NOT EXISTS public.user_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    card_id UUID NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen')),
    repetitions INTEGER NOT NULL DEFAULT 0,
    interval_days INTEGER NOT NULL DEFAULT 0,
    ease_factor FLOAT NOT NULL DEFAULT 2.5,
    next_review TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_reviewed TIMESTAMPTZ,
    learning_status TEXT NOT NULL DEFAULT 'not_studied' CHECK (learning_status IN ('not_studied', 'learning', 'mastered')),
    again_count INTEGER NOT NULL DEFAULT 0,
    user_note TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, card_id)
);

-- study_sessions
CREATE TABLE IF NOT EXISTS public.study_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    cards_reviewed INTEGER NOT NULL DEFAULT 0,
    cards_correct INTEGER NOT NULL DEFAULT 0,
    duration_seconds INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, date)
);

-- folders (Flashcard folders)
CREATE TABLE IF NOT EXISTS public.folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    microtopic TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, name)
);

-- card_folder_map
CREATE TABLE IF NOT EXISTS public.card_folder_map (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,
    folder_id UUID NOT NULL REFERENCES public.folders(id) ON DELETE CASCADE,
    UNIQUE(card_id, folder_id)
);

-- 4. NOTES SYSTEM

-- user_notes
CREATE TABLE IF NOT EXISTS public.user_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT DEFAULT '',
    items JSONB DEFAULT '[]'::jsonb,
    highlights JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- user_note_nodes
CREATE TABLE IF NOT EXISTS public.user_note_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    parent_id UUID NULL REFERENCES public.user_note_nodes(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('folder', 'note')),
    title TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    note_id UUID NULL REFERENCES public.user_notes(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. INDEXES

CREATE INDEX IF NOT EXISTS idx_questions_test_id ON public.questions(test_id);
CREATE INDEX IF NOT EXISTS idx_questions_subject ON public.questions(subject);
CREATE INDEX IF NOT EXISTS idx_questions_exam_group ON public.questions(exam_group);
CREATE INDEX IF NOT EXISTS idx_questions_question_text_trgm ON public.questions USING gin (question_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_questions_options_trgm ON public.questions USING gin ((options::text) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_question_states_user_id ON public.question_states(user_id);
CREATE INDEX IF NOT EXISTS idx_question_states_test_id ON public.question_states(test_id);

CREATE INDEX IF NOT EXISTS idx_user_cards_user_id ON public.user_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_user_cards_next_review ON public.user_cards(next_review) WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_user_notes_user_id ON public.user_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notes_subject ON public.user_notes(subject);

CREATE INDEX IF NOT EXISTS idx_note_nodes_user_id ON public.user_note_nodes(user_id);
CREATE INDEX IF NOT EXISTS idx_note_nodes_parent_id ON public.user_note_nodes(parent_id);

-- 6. TRIGGERS

DROP TRIGGER IF EXISTS trg_tests_updated_at ON public.tests;
CREATE TRIGGER trg_tests_updated_at BEFORE UPDATE ON public.tests FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_questions_updated_at ON public.questions;
CREATE TRIGGER trg_questions_updated_at BEFORE UPDATE ON public.questions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_question_states_updated_at ON public.question_states;
CREATE TRIGGER trg_question_states_updated_at BEFORE UPDATE ON public.question_states FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_draft_attempts_updated_at ON public.draft_attempts;
CREATE TRIGGER trg_draft_attempts_updated_at BEFORE UPDATE ON public.draft_attempts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_settings_updated_at ON public.user_settings;
CREATE TRIGGER trg_user_settings_updated_at BEFORE UPDATE ON public.user_settings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_cards_updated_at ON public.cards;
CREATE TRIGGER trg_cards_updated_at BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_cards_updated_at ON public.user_cards;
CREATE TRIGGER trg_user_cards_updated_at BEFORE UPDATE ON public.user_cards FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_study_sessions_updated_at ON public.study_sessions;
CREATE TRIGGER trg_study_sessions_updated_at BEFORE UPDATE ON public.study_sessions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_folders_updated_at ON public.folders;
CREATE TRIGGER trg_folders_updated_at BEFORE UPDATE ON public.folders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_notes_updated_at ON public.user_notes;
CREATE TRIGGER trg_user_notes_updated_at BEFORE UPDATE ON public.user_notes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_user_note_nodes_updated_at ON public.user_note_nodes;
CREATE TRIGGER trg_user_note_nodes_updated_at BEFORE UPDATE ON public.user_note_nodes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- 7. RLS POLICIES

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.draft_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_folder_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_note_nodes ENABLE ROW LEVEL SECURITY;

-- Public read access for questions and tests
DROP POLICY IF EXISTS "Public read tests" ON public.tests;
CREATE POLICY "Public read tests" ON public.tests FOR SELECT USING (true);
DROP POLICY IF EXISTS "Manage tests" ON public.tests;
CREATE POLICY "Manage tests" ON public.tests FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read questions" ON public.questions;
CREATE POLICY "Public read questions" ON public.questions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Manage questions" ON public.questions;
CREATE POLICY "Manage questions" ON public.questions FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read cards" ON public.cards;
CREATE POLICY "Public read cards" ON public.cards FOR SELECT USING (true);
DROP POLICY IF EXISTS "Manage cards" ON public.cards;
CREATE POLICY "Manage cards" ON public.cards FOR ALL TO authenticated USING (true) WITH CHECK (true);



-- Authenticated user policies
DROP POLICY IF EXISTS "Users view own states" ON public.question_states;
CREATE POLICY "Users view own states" ON public.question_states FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users manage own states" ON public.question_states;
CREATE POLICY "Users manage own states" ON public.question_states FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own attempts" ON public.test_attempts;
CREATE POLICY "Users view own attempts" ON public.test_attempts FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users manage own attempts" ON public.test_attempts;
CREATE POLICY "Users manage own attempts" ON public.test_attempts FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own drafts" ON public.draft_attempts;
CREATE POLICY "Users manage own drafts" ON public.draft_attempts FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own cards" ON public.user_cards;
CREATE POLICY "Users view own cards" ON public.user_cards FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users manage own cards" ON public.user_cards;
CREATE POLICY "Users manage own cards" ON public.user_cards FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own sessions" ON public.study_sessions;
CREATE POLICY "Users view own sessions" ON public.study_sessions FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users manage own sessions" ON public.study_sessions;
CREATE POLICY "Users manage own sessions" ON public.study_sessions FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own folders" ON public.folders;
CREATE POLICY "Users view own folders" ON public.folders FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users manage own folders" ON public.folders;
CREATE POLICY "Users manage own folders" ON public.folders FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own notes" ON public.user_notes;
CREATE POLICY "Users view own notes" ON public.user_notes FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users manage own notes" ON public.user_notes;
CREATE POLICY "Users manage own notes" ON public.user_notes FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users view own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users view own note nodes" ON public.user_note_nodes FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users manage own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users manage own note nodes" ON public.user_note_nodes FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own settings" ON public.user_settings;
CREATE POLICY "Users manage own settings" ON public.user_settings FOR ALL USING (auth.uid() = user_id);


-- 8. RPC FUNCTIONS

CREATE OR REPLACE FUNCTION public.question_metadata_summary(p_test_ids text[])
RETURNS TABLE (
    test_id text,
    subject text,
    section_group text,
    micro_topic text,
    is_pyq boolean,
    is_allied boolean,
    is_others boolean,
    exam_group text,
    question_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH base AS (
        SELECT
            q.test_id::text AS test_id,
            COALESCE(NULLIF(btrim(q.subject), ''), '(unknown)') AS subject,
            COALESCE(NULLIF(btrim(q.section_group), ''), '(none)') AS section_group,
            COALESCE(NULLIF(btrim(q.micro_topic), ''), '(none)') AS micro_topic,
            q.is_pyq,
            q.is_allied,
            q.is_others,
            COALESCE(NULLIF(btrim(q.exam_group), ''), '(unknown)') AS exam_group
        FROM public.questions q
        WHERE (p_test_ids IS NULL OR cardinality(p_test_ids) = 0 OR q.test_id::text = ANY(p_test_ids))
    )
    SELECT
        b.test_id,
        b.subject,
        b.section_group,
        b.micro_topic,
        b.is_pyq,
        b.is_allied,
        b.is_others,
        b.exam_group,
        COUNT(*)::bigint AS question_count
    FROM base b
    GROUP BY 1,2,3,4,5,6,7,8;
$$;

CREATE OR REPLACE FUNCTION public.search_questions_indexed(
    p_query text,
    p_test_ids text[] DEFAULT NULL,
    p_subject text DEFAULT NULL,
    p_section_group text DEFAULT NULL,
    p_limit integer DEFAULT 120,
    p_offset integer DEFAULT 0
)
RETURNS SETOF public.questions
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT q.*
    FROM public.questions q
    WHERE
        NULLIF(trim(p_query), '') IS NOT NULL
        AND (p_test_ids IS NULL OR cardinality(p_test_ids) = 0 OR q.test_id::text = ANY(p_test_ids))
        AND (p_subject IS NULL OR p_subject = 'All' OR q.subject = p_subject)
        AND (p_section_group IS NULL OR p_section_group = 'All' OR q.section_group = p_section_group)
        AND (
            q.question_text ILIKE ('%' || p_query || '%')
            OR q.options::text ILIKE ('%' || p_query || '%')
            OR similarity(q.question_text, p_query) > 0.18
        )
    ORDER BY
        similarity(q.question_text, p_query) DESC,
        q.updated_at DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 120), 1), 250)
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

-- Permissions for RPC
GRANT EXECUTE ON FUNCTION public.question_metadata_summary(text[]) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_questions_indexed(text, text[], text, text, integer, integer) TO authenticated, anon;

COMMIT;
