-- Optional: add NCERT flag to questions for badge rendering in the app.
-- After running, you may extend `QUESTION_COLUMNS` in `src/modules/supabase-data.js`
-- to include `is_ncert` in the select list for faster reads.

ALTER TABLE public.questions
    ADD COLUMN IF NOT EXISTS is_ncert boolean DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_questions_is_ncert ON public.questions (is_ncert);
