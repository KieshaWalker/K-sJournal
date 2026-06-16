-- Underlying stock positions held alongside a trade's options — the long
-- stock of a covered call, a delta hedge, or any share position K runs with the
-- setup. A trade may carry several (scaling in/out at different prices), and a
-- position can exist at any stage: ideas/pre-flight capture the planned side,
-- shares, and reference entry; in-flight adds a live mark; landed adds the
-- close. The underlying P&L blends into the trade's combined realized and
-- unrealized totals on the read side.
CREATE TABLE public.trade_underlying_legs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id      uuid NOT NULL REFERENCES public.trades(id) ON DELETE CASCADE,
  side          text NOT NULL CHECK (side IN ('long', 'short')),
  shares        integer NOT NULL CHECK (shares > 0),
  entry_price   numeric(12,4) NOT NULL CHECK (entry_price > 0),
  current_price numeric(12,4),   -- in-flight: live mark for unrealized P&L
  exit_price    numeric(12,4),   -- landed: realized close
  note          text CHECK (note IS NULL OR char_length(note) <= 280),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_trade_underlying_legs_trade
  ON public.trade_underlying_legs(trade_id);

ALTER TABLE public.trade_underlying_legs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_underlying_legs FORCE ROW LEVEL SECURITY;

CREATE TRIGGER set_trade_underlying_legs_updated_at
  BEFORE UPDATE ON public.trade_underlying_legs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Visibility mirrors the parent trade exactly: in-flight/landed to every tier,
-- pre-flight to analyst and inner_circle, ideas to inner_circle only.
CREATE POLICY "members_read_underlying" ON public.trade_underlying_legs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.trades t
      WHERE t.id = trade_underlying_legs.trade_id
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

CREATE POLICY "admin_all_underlying" ON public.trade_underlying_legs FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);
