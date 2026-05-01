BEGIN;

ALTER TABLE public.questions
    ADD COLUMN IF NOT EXISTS source_attribution_label text,
    ADD COLUMN IF NOT EXISTS is_pyq boolean,
    ADD COLUMN IF NOT EXISTS is_ncert boolean,
    ADD COLUMN IF NOT EXISTS is_upsc_cse boolean,
    ADD COLUMN IF NOT EXISTS is_allied boolean,
    ADD COLUMN IF NOT EXISTS is_others boolean,
    ADD COLUMN IF NOT EXISTS exam text,
    ADD COLUMN IF NOT EXISTS exam_group text,
    ADD COLUMN IF NOT EXISTS exam_year integer,
    ADD COLUMN IF NOT EXISTS exam_category text,
    ADD COLUMN IF NOT EXISTS specific_exam text,
    ADD COLUMN IF NOT EXISTS exam_stage text,
    ADD COLUMN IF NOT EXISTS exam_paper text;

UPDATE public.questions
SET
    source_attribution_label = COALESCE(
        NULLIF(source_attribution_label, ''),
        NULLIF(source ->> 'source_attribution_label', '')
    ),
    is_pyq = COALESCE(
        is_pyq,
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'isPyq', '')::boolean,
        NULLIF(source -> '__vaultMeta' ->> 'isPyq', '')::boolean,
        NULLIF(source -> 'exam_info' ->> 'isPyq', '')::boolean,
        NULLIF(source ->> 'isPyq', '')::boolean
    ),
    is_ncert = COALESCE(
        is_ncert,
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'is_ncert', '')::boolean,
        NULLIF(source -> 'exam_info' ->> 'is_ncert', '')::boolean,
        NULLIF(source ->> 'is_ncert', '')::boolean
    ),
    is_upsc_cse = COALESCE(
        is_upsc_cse,
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'is_upsc_cse', '')::boolean,
        NULLIF(source -> 'exam_info' ->> 'is_upsc_cse', '')::boolean,
        NULLIF(source ->> 'is_upsc_cse', '')::boolean
    ),
    is_allied = COALESCE(
        is_allied,
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'is_allied', '')::boolean,
        NULLIF(source -> '__vaultMeta' ->> 'is_allied', '')::boolean,
        NULLIF(source -> 'exam_info' ->> 'is_allied', '')::boolean,
        NULLIF(source ->> 'is_allied', '')::boolean
    ),
    is_others = COALESCE(
        is_others,
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'is_others', '')::boolean,
        NULLIF(source -> '__vaultMeta' ->> 'is_others', '')::boolean,
        NULLIF(source -> 'exam_info' ->> 'is_others', '')::boolean,
        NULLIF(source ->> 'is_others', '')::boolean
    ),
    exam = COALESCE(
        NULLIF(exam, ''),
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'exam', ''),
        NULLIF(source -> 'exam_info' ->> 'exam', '')
    ),
    exam_group = COALESCE(
        NULLIF(exam_group, ''),
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'group', ''),
        NULLIF(source -> 'exam_info' ->> 'group', '')
    ),
    exam_year = COALESCE(
        exam_year,
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'year', '')::integer,
        NULLIF(source -> 'exam_info' ->> 'year', '')::integer
    ),
    exam_category = COALESCE(
        NULLIF(exam_category, ''),
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'exam_category', ''),
        NULLIF(source -> 'exam_info' ->> 'exam_category', '')
    ),
    specific_exam = COALESCE(
        NULLIF(specific_exam, ''),
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'specific_exam', ''),
        NULLIF(source -> 'exam_info' ->> 'specific_exam', '')
    ),
    exam_stage = COALESCE(
        NULLIF(exam_stage, ''),
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'stage', ''),
        NULLIF(source -> 'exam_info' ->> 'stage', '')
    ),
    exam_paper = COALESCE(
        NULLIF(exam_paper, ''),
        NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'paper', ''),
        NULLIF(source -> 'exam_info' ->> 'paper', '')
    );

CREATE INDEX IF NOT EXISTS idx_questions_is_pyq ON public.questions (is_pyq);
CREATE INDEX IF NOT EXISTS idx_questions_exam_group ON public.questions (exam_group);
CREATE INDEX IF NOT EXISTS idx_questions_exam_year ON public.questions (exam_year);
CREATE INDEX IF NOT EXISTS idx_questions_exam_stage ON public.questions (exam_stage);
CREATE INDEX IF NOT EXISTS idx_questions_exam_paper ON public.questions (exam_paper);

COMMIT;
