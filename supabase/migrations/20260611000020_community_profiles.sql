-- Community directory: members get a public face — photo, bio, where they
-- are from, age — plus how many of K's trades they follow.
ALTER TABLE public.users
  ADD COLUMN bio        text CHECK (char_length(bio) <= 280),
  ADD COLUMN location   text,
  ADD COLUMN birth_date date;

-- Rebuild the definer-rights view with the public profile fields. Age is
-- computed here so raw birth dates never leave the table, and the follow
-- count is an aggregate so individual tracked trades stay private.
CREATE OR REPLACE VIEW public.public_profiles AS
  SELECT
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.bio,
    u.location,
    date_part('year', age(u.birth_date))::int AS age,
    u.membership_tier,
    u.is_admin,
    u.created_at AS member_since,
    (SELECT count(*)::int
       FROM public.tracked_trades tt
      WHERE tt.user_id = u.id) AS trades_followed
  FROM public.users u;
