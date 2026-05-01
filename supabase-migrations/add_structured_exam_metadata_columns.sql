BEGIN;

ALTER TABLE public.tests
    ADD COLUMN IF NOT EXISTS institute text,
    ADD COLUMN IF NOT EXISTS program_id text,
    ADD COLUMN IF NOT EXISTS program_name text,
    ADD COLUMN IF NOT EXISTS subject_test text,
    ADD COLUMN IF NOT EXISTS exam_year integer;

ALTER TABLE public.questions
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

DO $$
DECLARE
    tests_has_source boolean;
    tests_has_indexing boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'tests' AND column_name = 'source'
    ) INTO tests_has_source;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'tests' AND column_name = 'indexing'
    ) INTO tests_has_indexing;

    IF tests_has_source AND tests_has_indexing THEN
        EXECUTE $sql$
            UPDATE public.tests
            SET
                institute = COALESCE(NULLIF(institute, ''), NULLIF(provider, '')),
                program_id = COALESCE(
                    NULLIF(program_id, ''),
                    NULLIF(indexing ->> 'facet_program_id', ''),
                    NULLIF(source ->> 'program_id', '')
                ),
                program_name = COALESCE(
                    NULLIF(program_name, ''),
                    NULLIF(source ->> 'program_name', '')
                ),
                subject_test = COALESCE(
                    NULLIF(subject_test, ''),
                    NULLIF(source ->> 'subject_test', '')
                ),
                exam_year = COALESCE(
                    exam_year,
                    NULLIF(source ->> 'year', '')::integer
                )
        $sql$;
    ELSIF tests_has_source THEN
        EXECUTE $sql$
            UPDATE public.tests
            SET
                institute = COALESCE(NULLIF(institute, ''), NULLIF(provider, '')),
                program_id = COALESCE(
                    NULLIF(program_id, ''),
                    NULLIF(source ->> 'program_id', '')
                ),
                program_name = COALESCE(
                    NULLIF(program_name, ''),
                    NULLIF(source ->> 'program_name', '')
                ),
                subject_test = COALESCE(
                    NULLIF(subject_test, ''),
                    NULLIF(source ->> 'subject_test', '')
                ),
                exam_year = COALESCE(
                    exam_year,
                    NULLIF(source ->> 'year', '')::integer
                )
        $sql$;
    ELSIF tests_has_indexing THEN
        EXECUTE $sql$
            UPDATE public.tests
            SET
                institute = COALESCE(NULLIF(institute, ''), NULLIF(provider, '')),
                program_id = COALESCE(
                    NULLIF(program_id, ''),
                    NULLIF(indexing ->> 'facet_program_id', '')
                )
        $sql$;
    ELSE
        EXECUTE $sql$
            UPDATE public.tests
            SET
                institute = COALESCE(NULLIF(institute, ''), NULLIF(provider, ''))
        $sql$;
    END IF;
END $$;

DO $$
DECLARE
    questions_has_source boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'questions' AND column_name = 'source'
    ) INTO questions_has_source;

    IF questions_has_source THEN
        EXECUTE $sql$
            UPDATE public.questions
            SET
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
                    NULLIF(source -> 'exam_info' ->> 'exam', ''),
                    NULLIF(source ->> 'exam', '')
                ),
                exam_group = COALESCE(
                    NULLIF(exam_group, ''),
                    NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'group', ''),
                    NULLIF(source -> 'exam_info' ->> 'group', ''),
                    NULLIF(source ->> 'group', '')
                ),
                exam_year = COALESCE(
                    exam_year,
                    NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'year', '')::integer,
                    NULLIF(source -> 'exam_info' ->> 'year', '')::integer,
                    NULLIF(source ->> 'year', '')::integer
                ),
                exam_category = COALESCE(
                    NULLIF(exam_category, ''),
                    NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'exam_category', ''),
                    NULLIF(source -> 'exam_info' ->> 'exam_category', ''),
                    NULLIF(source ->> 'exam_category', '')
                ),
                specific_exam = COALESCE(
                    NULLIF(specific_exam, ''),
                    NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'specific_exam', ''),
                    NULLIF(source -> 'exam_info' ->> 'specific_exam', ''),
                    NULLIF(source ->> 'specific_exam', '')
                ),
                exam_stage = COALESCE(
                    NULLIF(exam_stage, ''),
                    NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'stage', ''),
                    NULLIF(source -> 'exam_info' ->> 'stage', ''),
                    NULLIF(source ->> 'stage', '')
                ),
                exam_paper = COALESCE(
                    NULLIF(exam_paper, ''),
                    NULLIF(source -> '__vaultMeta' -> 'exam_info' ->> 'paper', ''),
                    NULLIF(source -> 'exam_info' ->> 'paper', ''),
                    NULLIF(source ->> 'paper', '')
                )
        $sql$;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_questions_is_pyq ON public.questions (is_pyq);
CREATE INDEX IF NOT EXISTS idx_questions_is_ncert ON public.questions (is_ncert);
CREATE INDEX IF NOT EXISTS idx_questions_is_allied ON public.questions (is_allied);
CREATE INDEX IF NOT EXISTS idx_questions_is_others ON public.questions (is_others);
CREATE INDEX IF NOT EXISTS idx_questions_exam_group ON public.questions (exam_group);
CREATE INDEX IF NOT EXISTS idx_questions_exam_stage ON public.questions (exam_stage);
CREATE INDEX IF NOT EXISTS idx_questions_exam_paper ON public.questions (exam_paper);
CREATE INDEX IF NOT EXISTS idx_tests_institute ON public.tests (institute);
CREATE INDEX IF NOT EXISTS idx_tests_program_id ON public.tests (program_id);

COMMIT;
