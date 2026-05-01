-- Flashcard System Tables
-- Run this migration in Supabase SQL Editor

-- 1. cards table (static card content derived from questions)
CREATE TABLE IF NOT EXISTS cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id TEXT NOT NULL,       -- references the original question id
    test_id TEXT NOT NULL,           -- references the original test id
    question_text TEXT NOT NULL DEFAULT '',
    answer_text TEXT NOT NULL DEFAULT '',
    correct_answer TEXT,
    subject TEXT,
    section_group TEXT,
    microtopic TEXT,
    provider TEXT,
    source JSONB DEFAULT '{}',
    explanation_markdown TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. user_cards table (user-specific progress — THE MOST IMPORTANT TABLE)
CREATE TABLE IF NOT EXISTS user_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'frozen')),
    
    -- SM-2 algorithm fields
    repetitions INTEGER NOT NULL DEFAULT 0,
    interval_days INTEGER NOT NULL DEFAULT 0,
    ease_factor FLOAT NOT NULL DEFAULT 2.5,
    next_review TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_reviewed TIMESTAMPTZ,
    
    -- Learning tracking
    learning_status TEXT NOT NULL DEFAULT 'not_studied' CHECK (learning_status IN ('not_studied', 'learning', 'mastered')),
    again_count INTEGER NOT NULL DEFAULT 0,
    
    -- User personalization
    user_note TEXT DEFAULT '',
    
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(user_id, card_id)
);

-- 3. study_sessions table (for heatmap and tracking)
CREATE TABLE IF NOT EXISTS study_sessions (
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

-- 4. folders table (for move card feature)
CREATE TABLE IF NOT EXISTS folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    microtopic TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    UNIQUE(user_id, name)
);

-- 5. card_folder_map table (many-to-many)
CREATE TABLE IF NOT EXISTS card_folder_map (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    folder_id UUID NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    
    UNIQUE(card_id, folder_id)
);

-- INDEXES for performance
CREATE INDEX IF NOT EXISTS idx_user_cards_user_id ON user_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_user_cards_next_review ON user_cards(next_review) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_user_cards_status ON user_cards(status);
CREATE INDEX IF NOT EXISTS idx_user_cards_learning_status ON user_cards(learning_status);
CREATE INDEX IF NOT EXISTS idx_cards_microtopic ON cards(microtopic);
CREATE INDEX IF NOT EXISTS idx_cards_subject ON cards(subject);
CREATE INDEX IF NOT EXISTS idx_cards_question_id ON cards(question_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_user_date ON study_sessions(user_id, date);
CREATE INDEX IF NOT EXISTS idx_folders_user_id ON folders(user_id);

-- ROW LEVEL SECURITY
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_folder_map ENABLE ROW LEVEL SECURITY;

-- Cards: anyone can read, only admins can write
CREATE POLICY "Cards are readable by all" ON cards FOR SELECT USING (true);
CREATE POLICY "Cards insert by service" ON cards FOR INSERT WITH CHECK (true);

-- User cards: users can only access their own
CREATE POLICY "Users read own cards" ON user_cards FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users insert own cards" ON user_cards FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users update own cards" ON user_cards FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users delete own cards" ON user_cards FOR DELETE USING (user_id = auth.uid());

-- Study sessions: users can only access their own
CREATE POLICY "Users read own sessions" ON study_sessions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users insert own sessions" ON study_sessions FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users update own sessions" ON study_sessions FOR UPDATE USING (user_id = auth.uid());

-- Folders: users can only access their own
CREATE POLICY "Users read own folders" ON folders FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users insert own folders" ON folders FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users update own folders" ON folders FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users delete own folders" ON folders FOR DELETE USING (user_id = auth.uid());

-- Card folder map: users can only access their own (via folder ownership)
CREATE POLICY "Users read own card folders" ON card_folder_map FOR SELECT USING (
    EXISTS (SELECT 1 FROM folders WHERE folders.id = card_folder_map.folder_id AND folders.user_id = auth.uid())
);
CREATE POLICY "Users insert own card folders" ON card_folder_map FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM folders WHERE folders.id = card_folder_map.folder_id AND folders.user_id = auth.uid())
);
CREATE POLICY "Users delete own card folders" ON card_folder_map FOR DELETE USING (
    EXISTS (SELECT 1 FROM folders WHERE folders.id = card_folder_map.folder_id AND folders.user_id = auth.uid())
);
