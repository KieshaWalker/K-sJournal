-- Macro calendar + VIX (2026-06-16)
--
-- Two additions that live with the Macro Pulse on the dashboard:
--
--   1. macro_events — K's hand-kept docket of market-moving catalysts (FOMC,
--      CPI, jobs prints, big earnings) shown beneath the Macro Pulse tiles.
--      Each event can carry a set of directional scenarios
--      ("Cut -> bullish, Hold -> neutral, Hike -> bearish") rendered as
--      colour-coded chips. Authored and edited in the Trade Workbench.
--
--   2. VIX back on the watchlist. The external market-data project does not
--      carry VIX, so it rides on a manual entry K sets from the Workbench.
--      The value lands in market_snapshots like every other macro tile, so
--      the dashboard reads it with no special case.

-- ---- macro_events ----

CREATE TABLE public.macro_events (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title         text NOT NULL,
  detail        text,
  event_date    date NOT NULL,
  event_time    text,          -- free-form local label, e.g. '1:00 PM ET'
  category      text,          -- short tag, e.g. 'FOMC', 'CPI', 'Earnings'
  -- [{ "label": "Cut", "effect": "bullish" }, ...]; effect is one of
  -- bullish | neutral | bearish, rendered as colour-coded chips.
  scenarios     jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_active     boolean NOT NULL DEFAULT true,
  display_order integer NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_macro_events_active_date
  ON public.macro_events(event_date) WHERE is_active;

ALTER TABLE public.macro_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.macro_events FORCE ROW LEVEL SECURITY;

CREATE TRIGGER set_macro_events_updated_at
  BEFORE UPDATE ON public.macro_events
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Members read live events; admin does everything.
CREATE POLICY "members_read_macro_events" ON public.macro_events FOR SELECT
  USING (auth.role() = 'authenticated' AND is_active = true);

CREATE POLICY "admin_all_macro_events" ON public.macro_events FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- Starter event: the catalyst K described. K can edit or remove it from the
-- Workbench; it auto-hides from the dashboard once the date passes.
INSERT INTO public.macro_events
  (title, detail, event_date, event_time, category, scenarios, display_order)
VALUES
  ('FOMC Rate Decision',
   'Kevin Warsh''s first call as Fed chair. The tape is leaning on how he reads the cutting path from here.',
   '2026-06-17', '1:00 PM ET', 'FOMC',
   '[{"label":"Cut","effect":"bullish"},
     {"label":"Hold","effect":"neutral"},
     {"label":"Hike","effect":"bearish"}]'::jsonb,
   0);

-- ---- VIX back on the macro pulse (manual entry) ----

INSERT INTO public.watchlist_tickers
  (ticker, label, asset_class, display_order, is_active, source_symbol, notes)
VALUES
  ('VIX', 'Volatility Index', 'volatility', 0, true, NULL,
   'Manual entry — set from the Trade Workbench; not carried by the market-data project.')
ON CONFLICT (ticker) DO UPDATE
  SET label         = EXCLUDED.label,
      asset_class   = EXCLUDED.asset_class,
      display_order = EXCLUDED.display_order,
      is_active     = true,
      source_symbol = EXCLUDED.source_symbol,
      notes         = EXCLUDED.notes;
