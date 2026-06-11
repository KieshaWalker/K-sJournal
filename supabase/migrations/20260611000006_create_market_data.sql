CREATE TABLE public.watchlist_tickers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker        text UNIQUE NOT NULL,
  label         text NOT NULL,
  asset_class   text NOT NULL
                  CHECK (asset_class IN ('index','etf','commodity','crypto','volatility')),
  display_order integer NOT NULL DEFAULT 0,
  is_active     boolean NOT NULL DEFAULT true,
  source_symbol text,  -- symbol as it appears in the external market-data Supabase project
  notes         text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.watchlist_tickers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.watchlist_tickers FORCE ROW LEVEL SECURITY;

-- ----

CREATE TABLE public.market_snapshots (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker           text NOT NULL,
  snapshot_date    date NOT NULL,
  open             numeric(12,4),
  high             numeric(12,4),
  low              numeric(12,4),
  close            numeric(12,4),
  adj_close        numeric(12,4),
  volume           bigint,
  volume_avg_30d   bigint,
  volume_change_pct numeric(8,4),
  price_change     numeric(12,4),
  price_change_pct numeric(8,4),
  market_cap       numeric(20,2),
  sector           text,
  industry         text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ticker, snapshot_date)
);

CREATE INDEX idx_market_snapshots_ticker_date
  ON public.market_snapshots(ticker, snapshot_date DESC);
CREATE INDEX idx_market_snapshots_date
  ON public.market_snapshots(snapshot_date DESC);

ALTER TABLE public.market_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.market_snapshots FORCE ROW LEVEL SECURITY;

-- ----

CREATE TABLE public.volatility_data (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker        text NOT NULL,
  snapshot_date date NOT NULL,
  iv_current    numeric(8,4),
  iv_30d        numeric(8,4),
  iv_60d        numeric(8,4),
  iv_1y_high    numeric(8,4),
  iv_1y_low     numeric(8,4),
  iv_rank       numeric(6,2),
  iv_percentile numeric(6,2),
  hv_10d        numeric(8,4),
  hv_20d        numeric(8,4),
  hv_30d        numeric(8,4),
  rv_daily      numeric(8,4),
  iv_hv_spread  numeric(8,4),
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ticker, snapshot_date)
);

CREATE INDEX idx_volatility_ticker_date
  ON public.volatility_data(ticker, snapshot_date DESC);

ALTER TABLE public.volatility_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.volatility_data FORCE ROW LEVEL SECURITY;
