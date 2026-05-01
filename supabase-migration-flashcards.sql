-- Flashcard States Table for SM-2 Spaced Repetition
-- Run this in Supabase SQL Editor to create the table

CREATE TABLE IF NOT EXISTS flashcard_states (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    question_id TEXT NOT NULL,
    question_number INTEGER NOT NULL,
    
    -- SM-2 Algorithm Fields
    ease_factor DECIMAL(3, 2) DEFAULT 2.5,
    interval_days INTEGER DEFAULT 0,
    repetition_count INTEGER DEFAULT 0,
    next_review_date TIMESTAMP WITH TIME ZONE,
    last_review_date TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    due_at TIMESTAMP WITH TIME ZONE,
    difficulty TEXT CHECK (difficulty IN ('again', 'hard', 'good', 'easy')),
    review_count INTEGER DEFAULT 0,
    state TEXT CHECK (state IN ('new', 'learning', 'review', 'relearning', 'scheduled', 'frozen')) DEFAULT 'new',
    frozen BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(user_id, question_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_flashcard_states_user_id ON flashcard_states(user_id);
CREATE INDEX IF NOT EXISTS idx_flashcard_states_question_id ON flashcard_states(question_id);
CREATE INDEX IF NOT EXISTS idx_flashcard_states_next_review ON flashcard_states(next_review_date);
CREATE INDEX IF NOT EXISTS idx_flashcard_states_user_next_review ON flashcard_states(user_id, next_review_date);

-- Enable Row Level Security
ALTER TABLE flashcard_states ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own flashcard states
CREATE POLICY "Users can view own flashcard states"
  ON flashcard_states FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own flashcard states"
  ON flashcard_states FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own flashcard states"
  ON flashcard_states FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own flashcard states"
  ON flashcard_states FOR DELETE
  USING (auth.uid() = user_id);

-- Enable real-time
ALTER PUBLICATION supabase_realtime ADD TABLE flashcard_states;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER update_flashcard_states_updated_at
  BEFORE UPDATE ON flashcard_states
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
