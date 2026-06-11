CREATE TABLE public.price_band_stats (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  price_band     text NOT NULL
                   CHECK (price_band IN ('0_25','25_50','50_100','100_200','200_plus')),
  stat_window    text NOT NULL
                   CHECK (stat_window IN ('all_time','rolling_90d','rolling_1y')),
  total_trades   integer NOT NULL DEFAULT 0,
  winning_trades integer NOT NULL DEFAULT 0,
  losing_trades  integer NOT NULL DEFAULT 0,
  scratch_trades integer NOT NULL DEFAULT 0,
  win_rate       numeric(6,4),
  avg_win_pnl    numeric(12,2),
  avg_loss_pnl   numeric(12,2),
  avg_pnl        numeric(12,2),
  total_pnl      numeric(12,2),
  profit_factor  numeric(8,4),
  avg_days_held  numeric(6,2),
  computed_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (price_band, stat_window)
);

ALTER TABLE public.price_band_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_band_stats FORCE ROW LEVEL SECURITY;
