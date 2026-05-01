-- Lightweight facet counts for filters without downloading full question bodies.
-- Call from the app via supabase.rpc('question_metadata_summary', { p_test_ids: [...] })

DROP FUNCTION IF EXISTS public.question_metadata_summary(uuid[]);
DROP FUNCTION IF EXISTS public.question_metadata_summary(text[]);

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
AS $$
    WITH base AS (
        SELECT
            q.test_id::text AS test_id,
            COALESCE(NULLIF(btrim(q.subject), ''), '(unknown)') AS subject,
            COALESCE(NULLIF(btrim(q.section_group), ''), '(none)') AS section_group,
            COALESCE(NULLIF(btrim(q.micro_topic), ''), '(untagged)') AS micro_topic,
            LOWER(COALESCE(
                q.source->'__vaultMeta'->>'isPyq',
                q.source->>'isPyq',
                ''
            )) AS is_pyq_raw,
            LOWER(COALESCE(
                q.source->'__vaultMeta'->>'is_allied',
                q.source->>'is_allied',
                ''
            )) AS is_allied_raw,
            LOWER(COALESCE(
                q.source->'__vaultMeta'->>'is_others',
                q.source->>'is_others',
                ''
            )) AS is_others_raw,
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

GRANT EXECUTE ON FUNCTION public.question_metadata_summary(text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.question_metadata_summary(text[]) TO anon;

