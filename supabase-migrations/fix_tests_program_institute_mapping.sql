BEGIN;

ALTER TABLE public.tests
    ADD COLUMN IF NOT EXISTS institute text,
    ADD COLUMN IF NOT EXISTS program_id text,
    ADD COLUMN IF NOT EXISTS program_name text,
    ADD COLUMN IF NOT EXISTS launch_year integer,
    ADD COLUMN IF NOT EXISTS subject_test text;

DO $$
DECLARE
    tests_has_source boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'tests' AND column_name = 'source'
    ) INTO tests_has_source;

    IF tests_has_source THEN
        EXECUTE $sql$
            UPDATE public.tests
            SET
                institute = COALESCE(
                    NULLIF(institute, ''),
                    NULLIF(source ->> 'institute', ''),
                    NULLIF(provider, '')
                ),
                program_id = COALESCE(
                    NULLIF(program_id, ''),
                    NULLIF(source ->> 'program_id', '')
                ),
                program_name = COALESCE(
                    NULLIF(program_name, ''),
                    NULLIF(source ->> 'program_name', '')
                ),
                launch_year = COALESCE(
                    launch_year,
                    NULLIF(source ->> 'launch_year', '')::integer
                ),
                subject_test = COALESCE(
                    NULLIF(subject_test, ''),
                    NULLIF(source ->> 'subject_test', '')
                )
        $sql$;
    ELSE
        EXECUTE $sql$
            UPDATE public.tests
            SET institute = COALESCE(NULLIF(institute, ''), NULLIF(provider, ''))
        $sql$;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_tests_institute ON public.tests (institute);
CREATE INDEX IF NOT EXISTS idx_tests_program_id ON public.tests (program_id);
CREATE INDEX IF NOT EXISTS idx_tests_program_name ON public.tests (program_name);
CREATE INDEX IF NOT EXISTS idx_tests_launch_year ON public.tests (launch_year);

COMMIT;
