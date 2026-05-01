-- Flashcard server tables
-- Run this whole file in the Supabase SQL Editor for the current project.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

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

CREATE TABLE IF NOT EXISTS public.folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    microtopic TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, name)
);

CREATE TABLE IF NOT EXISTS public.card_folder_map (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,
    folder_id UUID NOT NULL REFERENCES public.folders(id) ON DELETE CASCADE,
    UNIQUE(card_id, folder_id)
);

CREATE INDEX IF NOT EXISTS idx_cards_question_id ON public.cards(question_id);
CREATE INDEX IF NOT EXISTS idx_cards_test_id ON public.cards(test_id);
CREATE INDEX IF NOT EXISTS idx_cards_subject ON public.cards(subject);
CREATE INDEX IF NOT EXISTS idx_cards_microtopic ON public.cards(microtopic);
CREATE INDEX IF NOT EXISTS idx_user_cards_user_id ON public.user_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_user_cards_card_id ON public.user_cards(card_id);
CREATE INDEX IF NOT EXISTS idx_user_cards_next_review ON public.user_cards(next_review) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_user_cards_learning_status ON public.user_cards(learning_status);
CREATE INDEX IF NOT EXISTS idx_study_sessions_user_date ON public.study_sessions(user_id, date);
CREATE INDEX IF NOT EXISTS idx_folders_user_id ON public.folders(user_id);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cards_updated_at ON public.cards;
CREATE TRIGGER trg_cards_updated_at
BEFORE UPDATE ON public.cards
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_user_cards_updated_at ON public.user_cards;
CREATE TRIGGER trg_user_cards_updated_at
BEFORE UPDATE ON public.user_cards
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_study_sessions_updated_at ON public.study_sessions;
CREATE TRIGGER trg_study_sessions_updated_at
BEFORE UPDATE ON public.study_sessions
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_folders_updated_at ON public.folders;
CREATE TRIGGER trg_folders_updated_at
BEFORE UPDATE ON public.folders
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_folder_map ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'cards' AND policyname = 'Cards are readable by all'
    ) THEN
        CREATE POLICY "Cards are readable by all" ON public.cards
            FOR SELECT USING (true);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'cards' AND policyname = 'Cards insert by authenticated users'
    ) THEN
        CREATE POLICY "Cards insert by authenticated users" ON public.cards
            FOR INSERT TO authenticated WITH CHECK (true);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'cards' AND policyname = 'Cards update by authenticated users'
    ) THEN
        CREATE POLICY "Cards update by authenticated users" ON public.cards
            FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_cards' AND policyname = 'Users read own cards'
    ) THEN
        CREATE POLICY "Users read own cards" ON public.user_cards
            FOR SELECT USING (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_cards' AND policyname = 'Users insert own cards'
    ) THEN
        CREATE POLICY "Users insert own cards" ON public.user_cards
            FOR INSERT WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_cards' AND policyname = 'Users update own cards'
    ) THEN
        CREATE POLICY "Users update own cards" ON public.user_cards
            FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'user_cards' AND policyname = 'Users delete own cards'
    ) THEN
        CREATE POLICY "Users delete own cards" ON public.user_cards
            FOR DELETE USING (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'study_sessions' AND policyname = 'Users read own sessions'
    ) THEN
        CREATE POLICY "Users read own sessions" ON public.study_sessions
            FOR SELECT USING (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'study_sessions' AND policyname = 'Users insert own sessions'
    ) THEN
        CREATE POLICY "Users insert own sessions" ON public.study_sessions
            FOR INSERT WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'study_sessions' AND policyname = 'Users update own sessions'
    ) THEN
        CREATE POLICY "Users update own sessions" ON public.study_sessions
            FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'folders' AND policyname = 'Users read own folders'
    ) THEN
        CREATE POLICY "Users read own folders" ON public.folders
            FOR SELECT USING (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'folders' AND policyname = 'Users insert own folders'
    ) THEN
        CREATE POLICY "Users insert own folders" ON public.folders
            FOR INSERT WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'folders' AND policyname = 'Users update own folders'
    ) THEN
        CREATE POLICY "Users update own folders" ON public.folders
            FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'folders' AND policyname = 'Users delete own folders'
    ) THEN
        CREATE POLICY "Users delete own folders" ON public.folders
            FOR DELETE USING (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'card_folder_map' AND policyname = 'Users read own card folders'
    ) THEN
        CREATE POLICY "Users read own card folders" ON public.card_folder_map
            FOR SELECT USING (
                EXISTS (
                    SELECT 1
                    FROM public.folders
                    WHERE folders.id = card_folder_map.folder_id
                      AND folders.user_id = auth.uid()
                )
            );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'card_folder_map' AND policyname = 'Users insert own card folders'
    ) THEN
        CREATE POLICY "Users insert own card folders" ON public.card_folder_map
            FOR INSERT WITH CHECK (
                EXISTS (
                    SELECT 1
                    FROM public.folders
                    WHERE folders.id = card_folder_map.folder_id
                      AND folders.user_id = auth.uid()
                )
            );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'card_folder_map' AND policyname = 'Users delete own card folders'
    ) THEN
        CREATE POLICY "Users delete own card folders" ON public.card_folder_map
            FOR DELETE USING (
                EXISTS (
                    SELECT 1
                    FROM public.folders
                    WHERE folders.id = card_folder_map.folder_id
                      AND folders.user_id = auth.uid()
                )
            );
    END IF;
END $$;
