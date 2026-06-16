-- Two dated histories on a trade:
--   * trade_photos  — many photos, each stamped with a (pickable) date, so the
--     chart history builds up instead of one overwriteable cover. The cover
--     stays on trades.image_url.
--   * trade_greeks  — one greeks/IV/price snapshot per day. ONLY today's row is
--     mutable: re-saving in the admin UI or re-running the market pull replaces
--     today's snapshot; once the day turns over the row is frozen forever and
--     becomes part of the history list.
--
-- The snapshot is fed automatically from trades.current_* by a sync trigger, so
-- admin_pull_market_data needs no change — its existing current_* write records
-- (and, same-day, replaces) the snapshot. A lock trigger freezes past days.

-- ---- trade_photos ----

CREATE TABLE public.trade_photos (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id   uuid NOT NULL REFERENCES public.trades(id) ON DELETE CASCADE,
  image_url  text NOT NULL,
  photo_date date NOT NULL DEFAULT current_date,
  caption    text CHECK (caption IS NULL OR char_length(caption) <= 200),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_trade_photos_trade
  ON public.trade_photos(trade_id, photo_date DESC);

ALTER TABLE public.trade_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_photos FORCE ROW LEVEL SECURITY;

-- ---- trade_greeks ----

CREATE TABLE public.trade_greeks (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id       uuid NOT NULL REFERENCES public.trades(id) ON DELETE CASCADE,
  snapshot_date  date NOT NULL,
  delta          numeric(8,6),
  gamma          numeric(8,6),
  theta          numeric(8,6),
  vega           numeric(8,6),
  iv             numeric(8,4),
  price          numeric(12,4),
  unrealized_pnl numeric(12,2),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (trade_id, snapshot_date)
);
CREATE INDEX idx_trade_greeks_trade
  ON public.trade_greeks(trade_id, snapshot_date DESC);

ALTER TABLE public.trade_greeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_greeks FORCE ROW LEVEL SECURITY;

CREATE TRIGGER set_trade_greeks_updated_at
  BEFORE UPDATE ON public.trade_greeks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Freeze the past: a snapshot can only be edited on its own day. Only UPDATE
-- is locked, not DELETE — cascade deletes (when a trade is removed) must still
-- clean up frozen rows.
CREATE OR REPLACE FUNCTION public.lock_past_trade_greeks()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.snapshot_date < current_date THEN
    RAISE EXCEPTION
      'Greeks snapshot for % is frozen; only today''s snapshot can change.',
      OLD.snapshot_date;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER lock_past_trade_greeks
  BEFORE UPDATE ON public.trade_greeks
  FOR EACH ROW EXECUTE FUNCTION public.lock_past_trade_greeks();

-- Record/replace a trade's snapshot for the date its live figures are "as of"
-- whenever the current_* greeks change (the market pull and the admin greeks
-- editor both just write current_*). Today's row is overwritten; a conflict on
-- a past date is skipped, leaving the frozen history intact.
CREATE OR REPLACE FUNCTION public.sync_trade_greeks()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.current_as_of IS NULL THEN
    RETURN NULL;
  END IF;
  INSERT INTO public.trade_greeks AS g
         (trade_id, snapshot_date, delta, gamma, theta, vega, iv, price,
          unrealized_pnl)
  VALUES (NEW.id, NEW.current_as_of, NEW.current_delta, NEW.current_gamma,
          NEW.current_theta, NEW.current_vega, NEW.current_iv,
          NEW.current_price, NEW.unrealized_pnl)
  ON CONFLICT (trade_id, snapshot_date) DO UPDATE
     SET delta = excluded.delta,
         gamma = excluded.gamma,
         theta = excluded.theta,
         vega  = excluded.vega,
         iv    = excluded.iv,
         price = excluded.price,
         unrealized_pnl = excluded.unrealized_pnl
   WHERE g.snapshot_date = current_date;
  RETURN NULL;
END;
$$;

CREATE TRIGGER sync_trade_greeks
  AFTER UPDATE ON public.trades
  FOR EACH ROW
  WHEN (
    NEW.current_as_of   IS DISTINCT FROM OLD.current_as_of
    OR NEW.current_delta IS DISTINCT FROM OLD.current_delta
    OR NEW.current_gamma IS DISTINCT FROM OLD.current_gamma
    OR NEW.current_theta IS DISTINCT FROM OLD.current_theta
    OR NEW.current_vega  IS DISTINCT FROM OLD.current_vega
    OR NEW.current_iv    IS DISTINCT FROM OLD.current_iv
    OR NEW.current_price IS DISTINCT FROM OLD.current_price
    OR NEW.unrealized_pnl IS DISTINCT FROM OLD.unrealized_pnl
  )
  EXECUTE FUNCTION public.sync_trade_greeks();

-- ---- RLS: both tables mirror the parent trade's visibility ----
-- (in-flight/landed → all tiers; pre-flight → analyst+inner_circle;
--  idea → inner_circle), exactly like trade_underlying_legs.

CREATE POLICY "members_read_trade_photos" ON public.trade_photos FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.trades t
      WHERE t.id = trade_photos.trade_id
        AND (
          (t.status IN ('in_flight', 'landed')
            AND auth.jwt() ->> 'membership_tier'
              IN ('observer', 'analyst', 'inner_circle'))
          OR (t.status = 'pre_flight'
            AND auth.jwt() ->> 'membership_tier'
              IN ('analyst', 'inner_circle'))
          OR (t.status = 'idea'
            AND auth.jwt() ->> 'membership_tier' = 'inner_circle')
        )
    )
  );

CREATE POLICY "admin_all_trade_photos" ON public.trade_photos FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

CREATE POLICY "members_read_trade_greeks" ON public.trade_greeks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.trades t
      WHERE t.id = trade_greeks.trade_id
        AND (
          (t.status IN ('in_flight', 'landed')
            AND auth.jwt() ->> 'membership_tier'
              IN ('observer', 'analyst', 'inner_circle'))
          OR (t.status = 'pre_flight'
            AND auth.jwt() ->> 'membership_tier'
              IN ('analyst', 'inner_circle'))
          OR (t.status = 'idea'
            AND auth.jwt() ->> 'membership_tier' = 'inner_circle')
        )
    )
  );

CREATE POLICY "admin_all_trade_greeks" ON public.trade_greeks FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);
