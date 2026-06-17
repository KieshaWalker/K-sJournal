-- K's conviction grade for a setup: how much confidence she's putting behind
-- the name, and by inversion how much risk it carries. Set pre-execution on
-- ideas/pre-flight and carried through the trade's life. Null = ungraded
-- (every trade landed before this column existed reads as ungraded).
--
-- Idempotent: the column and its check constraint are each added only when
-- absent, so a re-push after a partial apply is safe.
ALTER TABLE public.trades
  ADD COLUMN IF NOT EXISTS confidence text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'trades_confidence_check'
  ) THEN
    ALTER TABLE public.trades
      ADD CONSTRAINT trades_confidence_check
      CHECK (confidence IN ('low','medium','high'));
  END IF;
END $$;

COMMENT ON COLUMN public.trades.confidence IS
  'K''s conviction grade: low (low confidence / high risk), medium, high. Null = ungraded.';

-- Row-level RLS already governs trade reads; the new column rides the existing
-- members_read_* policies, so no policy change is needed.
