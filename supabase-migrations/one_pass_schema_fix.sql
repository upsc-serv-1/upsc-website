-- One-pass Supabase fix script for:
-- 1) Notes hierarchy tables (server-only folder/notebook/note persistence)
-- 2) Metadata summary RPC using JSON schema keys:
--    isPyq, is_allied, is_others, exam_info.group
-- 3) Indexed server search RPC

BEGIN;

DO $$
BEGIN
    BEGIN
        CREATE EXTENSION IF NOT EXISTS pg_trgm;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'pg_trgm extension could not be created; continuing without trigram indexes.';
    END;
END $$;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

CREATE INDEX IF NOT EXISTS idx_user_notes_user_id ON public.user_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notes_subject ON public.user_notes(subject);
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notes" ON public.user_notes;
CREATE POLICY "Users can view own notes" ON public.user_notes FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own notes" ON public.user_notes;
CREATE POLICY "Users can insert own notes" ON public.user_notes FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own notes" ON public.user_notes;
CREATE POLICY "Users can update own notes" ON public.user_notes FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own notes" ON public.user_notes;
CREATE POLICY "Users can delete own notes" ON public.user_notes FOR DELETE USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_user_notes_updated_at ON public.user_notes;
CREATE TRIGGER update_user_notes_updated_at
BEFORE UPDATE ON public.user_notes
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notes TO authenticated;

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

CREATE INDEX IF NOT EXISTS idx_note_nodes_user_id ON public.user_note_nodes(user_id);
CREATE INDEX IF NOT EXISTS idx_note_nodes_parent_id ON public.user_note_nodes(parent_id);
CREATE INDEX IF NOT EXISTS idx_note_nodes_type ON public.user_note_nodes(type);
CREATE INDEX IF NOT EXISTS idx_note_nodes_note_id ON public.user_note_nodes(note_id);
ALTER TABLE public.user_note_nodes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users can view own note nodes" ON public.user_note_nodes FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users can insert own note nodes" ON public.user_note_nodes FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users can update own note nodes" ON public.user_note_nodes FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users can delete own note nodes" ON public.user_note_nodes FOR DELETE USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_user_note_nodes_updated_at ON public.user_note_nodes;
CREATE TRIGGER update_user_note_nodes_updated_at
BEFORE UPDATE ON public.user_note_nodes
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_note_nodes TO authenticated;

CREATE INDEX IF NOT EXISTS idx_questions_test_subject_section_micro
ON public.questions (test_id, subject, section_group, micro_topic);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_opclass
        WHERE opcname = 'gin_trgm_ops'
    ) THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_questions_question_text_trgm ON public.questions USING gin (question_text gin_trgm_ops)';
        EXECUTE 'CREATE INDEX IF NOT EXISTS idx_questions_options_trgm ON public.questions USING gin ((options::text) gin_trgm_ops)';
    ELSE
        RAISE NOTICE 'gin_trgm_ops not available; skipped trigram indexes.';
    END IF;
END $$;

DROP FUNCTION IF EXISTS public.question_metadata_summary(uuid[]);
DROP FUNCTION IF EXISTS public.question_metadata_summary(text[]);

CREATE FUNCTION public.question_metadata_summary(p_test_ids text[])
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
            LOWER(COALESCE(q.source->'__vaultMeta'->>'isPyq', q.source->>'isPyq', '')) AS is_pyq_raw,
            LOWER(COALESCE(q.source->'__vaultMeta'->>'is_allied', q.source->>'is_allied', '')) AS is_allied_raw,
            LOWER(COALESCE(q.source->'__vaultMeta'->>'is_others', q.source->>'is_others', '')) AS is_others_raw,
            COALESCE(
                NULLIF(btrim(q.source->'__vaultMeta'->'exam_info'->>'group'), ''),
                NULLIF(btrim(q.source->'exam_info'->>'group'), ''),
                NULLIF(btrim(q.source->>'group'), ''),
                '(unknown)'
            ) AS exam_group
        FROM public.questions q
        WHERE (p_test_ids IS NULL OR cardinality(p_test_ids) = 0 OR q.test_id::text = ANY(p_test_ids))
    )
    SELECT
        b.test_id,
        b.subject,
        b.section_group,
        b.micro_topic,
        (b.is_pyq_raw IN ('true', 't', '1', 'yes', 'y')) AS is_pyq,
        (b.is_allied_raw IN ('true', 't', '1', 'yes', 'y')) AS is_allied,
        (b.is_others_raw IN ('true', 't', '1', 'yes', 'y')) AS is_others,
        b.exam_group,
        COUNT(*)::bigint AS question_count
    FROM base b
    GROUP BY
        b.test_id,
        b.subject,
        b.section_group,
        b.micro_topic,
        (b.is_pyq_raw IN ('true', 't', '1', 'yes', 'y')),
        (b.is_allied_raw IN ('true', 't', '1', 'yes', 'y')),
        (b.is_others_raw IN ('true', 't', '1', 'yes', 'y')),
        b.exam_group;
$$;

DROP FUNCTION IF EXISTS public.search_questions_indexed(text, uuid[], text, text, integer, integer);
DROP FUNCTION IF EXISTS public.search_questions_indexed(text, text[], text, text, integer, integer);

CREATE FUNCTION public.search_questions_indexed(
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
            OR similarity(q.options::text, p_query) > 0.18
        )
    ORDER BY
        GREATEST(similarity(q.question_text, p_query), similarity(q.options::text, p_query)) DESC,
        q.updated_at DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 120), 1), 250)
    OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

GRANT EXECUTE ON FUNCTION public.question_metadata_summary(text[]) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_questions_indexed(text, text[], text, text, integer, integer) TO authenticated, anon;

COMMIT;
