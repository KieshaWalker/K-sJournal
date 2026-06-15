-- Drop the dead `is_visible_observer` column from trades.
--
-- It was never wired into anything: the app never set it, no index/trigger
-- referenced it, and the members_read_trades RLS policy gates on
-- membership_tier + status only (in_flight, landed) — never on this flag.
-- So it gave a false impression of a "stage privately" control that did not
-- exist. Member visibility is, and stays, defined purely by trade status:
-- in-flight and landed trades are visible to members the moment they reach
-- that status.

ALTER TABLE public.trades DROP COLUMN IF EXISTS is_visible_observer;
