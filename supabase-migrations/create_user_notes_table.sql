-- Create user_notes table for storing user-created notes
-- Run this in Supabase SQL Editor: https://app.supabase.io/project/_/sql

-- Create the table
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

-- Add index for faster queries by user
CREATE INDEX IF NOT EXISTS idx_user_notes_user_id ON public.user_notes(user_id);

-- Add index for subject filtering
CREATE INDEX IF NOT EXISTS idx_user_notes_subject ON public.user_notes(subject);

-- Enable Row Level Security
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can only see their own notes
CREATE POLICY "Users can view own notes" 
    ON public.user_notes 
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Create policy: Users can only insert their own notes
CREATE POLICY "Users can insert own notes" 
    ON public.user_notes 
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can only update their own notes
CREATE POLICY "Users can update own notes" 
    ON public.user_notes 
    FOR UPDATE 
    USING (auth.uid() = user_id);

-- Create policy: Users can only delete their own notes
CREATE POLICY "Users can delete own notes" 
    ON public.user_notes 
    FOR DELETE 
    USING (auth.uid() = user_id);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to auto-update updated_at
CREATE TRIGGER update_user_notes_updated_at 
    BEFORE UPDATE ON public.user_notes 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notes TO authenticated;
