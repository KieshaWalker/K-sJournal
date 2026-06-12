-- K's working notes: a private scratchpad on the admin workbench — levels
-- to watch, reminders, half-formed setups. Admin-only on every verb; no
-- member policy exists on purpose, so members can never read these.
CREATE TABLE public.admin_notes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  body       text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notes FORCE ROW LEVEL SECURITY;

CREATE TRIGGER set_admin_notes_updated_at
  BEFORE UPDATE ON public.admin_notes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY "admin_all_notes" ON public.admin_notes FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);
