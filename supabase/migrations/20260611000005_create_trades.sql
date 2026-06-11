CREATE TABLE public.trades (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker           text NOT NULL,
  company_name     text,
  sector           text,
  industry         text,
  strategy_type    text NOT NULL CHECK (strategy_type IN (
                     'long_call','long_put','short_call','short_put',
                     'call_spread','put_spread','iron_condor','iron_butterfly',
                     'straddle','strangle','covered_call','cash_secured_put',
                     'butterfly','calendar','diagonal'
                   )),
  direction        text NOT NULL CHECK (direction IN ('bullish','bearish','neutral')),
  price_band       text CHECK (price_band IN ('0_25','25_50','50_100','100_200','200_plus')),
  status           text NOT NULL DEFAULT 'idea'
                     CHECK (status IN ('idea','pre_flight','in_flight','landed')),
  outcome          text CHECK (outcome IN ('win','loss','scratch')),

  -- Entry fields
  entry_date            date,
  entry_price           numeric(12,4),
  quantity              integer,
  position_size_usd     numeric(12,2),
  stock_price_at_entry  numeric(10,4),

  -- Entry Greeks (immutable after setting)
  entry_delta    numeric(8,6),
  entry_gamma    numeric(8,6),
  entry_theta    numeric(8,6),
  entry_vega     numeric(8,6),
  entry_iv       numeric(8,4),
  entry_iv_rank  numeric(6,2),
  entry_iv_pct   numeric(6,2),

  -- Live Greeks (mutable; maintained by K via admin UI)
  current_delta    numeric(8,6),
  current_gamma    numeric(8,6),
  current_theta    numeric(8,6),
  current_vega     numeric(8,6),
  current_iv       numeric(8,4),
  current_price    numeric(12,4),
  unrealized_pnl   numeric(12,2),

  -- Exit fields
  exit_date      date,
  exit_price     numeric(12,4),
  realized_pnl   numeric(12,2),
  pnl_percent    numeric(8,4),

  -- Metadata
  thesis_notes        text,
  exit_notes          text,
  tags                text[],
  is_visible_observer boolean NOT NULL DEFAULT false,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  -- Business rule constraints
  CONSTRAINT outcome_required_when_landed
    CHECK (status != 'landed' OR outcome IS NOT NULL),
  CONSTRAINT entry_required_when_inflight
    CHECK (status NOT IN ('in_flight','landed') OR entry_date IS NOT NULL),
  CONSTRAINT exit_required_when_landed
    CHECK (status != 'landed' OR exit_date IS NOT NULL),
  CONSTRAINT exit_after_entry
    CHECK (exit_date IS NULL OR entry_date IS NULL OR exit_date >= entry_date)
);
-- Member questions/comments on trades live in trade_comments (013_create_social).

CREATE INDEX idx_trades_status     ON public.trades(status);
CREATE INDEX idx_trades_ticker     ON public.trades(ticker);
CREATE INDEX idx_trades_updated    ON public.trades(updated_at DESC);
CREATE INDEX idx_trades_price_band ON public.trades(price_band)
  WHERE status = 'landed';
CREATE INDEX idx_trades_status_created ON public.trades(status, created_at DESC);

ALTER TABLE public.trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trades FORCE ROW LEVEL SECURITY;

-- ----

CREATE TABLE public.trade_legs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id    uuid NOT NULL REFERENCES public.trades(id) ON DELETE CASCADE,
  leg_number  integer NOT NULL,
  action      text NOT NULL CHECK (action IN ('buy','sell')),
  option_type text NOT NULL CHECK (option_type IN ('call','put')),
  strike      numeric(10,2) NOT NULL,
  expiry_date date NOT NULL,
  quantity    integer NOT NULL CHECK (quantity > 0),
  entry_price numeric(10,4) NOT NULL,
  exit_price  numeric(10,4),
  occ_symbol  text,
  delta       numeric(8,6),
  gamma       numeric(8,6),
  theta       numeric(8,6),
  vega        numeric(8,6),
  rho         numeric(8,6),
  iv          numeric(8,4),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (trade_id, leg_number)
);

CREATE INDEX idx_trade_legs_trade ON public.trade_legs(trade_id);

ALTER TABLE public.trade_legs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_legs FORCE ROW LEVEL SECURITY;

-- ----

CREATE TABLE public.positions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id           uuid REFERENCES public.trades(id) ON DELETE SET NULL,
  ticker             text NOT NULL,
  occ_symbol         text UNIQUE,
  position_type      text NOT NULL CHECK (position_type IN ('equity','option')),
  quantity           integer NOT NULL,
  avg_cost           numeric(12,4),
  current_price      numeric(12,4),
  market_value       numeric(12,2),
  unrealized_pnl     numeric(12,2),
  unrealized_pnl_pct numeric(8,4),
  day_pnl            numeric(12,2),
  delta_exposure     numeric(10,4),
  theta_decay_daily  numeric(10,4),
  last_synced_at     timestamptz NOT NULL DEFAULT now(),
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_positions_ticker  ON public.positions(ticker);
CREATE INDEX idx_positions_trade   ON public.positions(trade_id);

ALTER TABLE public.positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.positions FORCE ROW LEVEL SECURITY;
