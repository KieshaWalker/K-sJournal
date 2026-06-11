-- Comment threads need to show other members' usernames, but users rows are
-- owner-read-only under RLS. Expose just the public fields through a
-- definer-rights view (owned by postgres, which bypasses RLS).
CREATE VIEW public.public_profiles AS
  SELECT id, username, display_name
  FROM public.users;

REVOKE ALL ON public.public_profiles FROM anon, authenticated;
GRANT SELECT ON public.public_profiles TO authenticated;
