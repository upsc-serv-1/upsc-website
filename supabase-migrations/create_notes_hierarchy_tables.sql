-- Run this in Supabase SQL Editor.
-- It creates the server-side notes tables required for:
-- folder -> notebook -> note hierarchy

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
CREATE POLICY "Users can view own notes"
ON public.user_notes
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own notes" ON public.user_notes;
CREATE POLICY "Users can insert own notes"
ON public.user_notes
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notes" ON public.user_notes;
CREATE POLICY "Users can update own notes"
ON public.user_notes
FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notes" ON public.user_notes;
CREATE POLICY "Users can delete own notes"
ON public.user_notes
FOR DELETE
USING (auth.uid() = user_id);

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
CREATE POLICY "Users can view own note nodes"
ON public.user_note_nodes
FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users can insert own note nodes"
ON public.user_note_nodes
FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users can update own note nodes"
ON public.user_note_nodes
FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own note nodes" ON public.user_note_nodes;
CREATE POLICY "Users can delete own note nodes"
ON public.user_note_nodes
FOR DELETE
USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_user_note_nodes_updated_at ON public.user_note_nodes;
CREATE TRIGGER update_user_note_nodes_updated_at
BEFORE UPDATE ON public.user_note_nodes
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_note_nodes TO authenticated;
