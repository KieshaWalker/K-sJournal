-- The custom_access_token_hook runs as supabase_auth_admin. public.users has
-- FORCE ROW LEVEL SECURITY, so a GRANT alone is not enough — without this
-- policy the hook's SELECT returns no rows and every JWT gets null
-- tier/admin/username claims (symptom: members bounce back to tier selection
-- forever). Idempotent because it was applied to production manually on
-- 2026-06-11 before this file existed.
DROP POLICY IF EXISTS "auth_admin_read_users" ON public.users;
CREATE POLICY "auth_admin_read_users" ON public.users
  FOR SELECT TO supabase_auth_admin USING (true);
