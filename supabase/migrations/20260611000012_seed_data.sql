-- Watchlist tickers (fixed macro dashboard symbols).
-- source_symbol = symbol as named in the external market-data Supabase project;
-- update these once the external project's symbol naming is confirmed.
INSERT INTO public.watchlist_tickers
  (ticker, label, asset_class, display_order, is_active, source_symbol)
VALUES
  ('VIX', 'VIX Index',          'volatility', 1, true, 'VIX'),
  ('SPY', 'S&P 500 ETF',        'etf',        2, true, 'SPY'),
  ('QQQ', 'Nasdaq ETF',         'etf',        3, true, 'QQQ'),
  ('IGV', 'Software ETF',       'etf',        4, true, 'IGV'),
  ('SMH', 'Semiconductors ETF', 'etf',        5, true, 'SMH'),
  ('USO', 'Crude Oil ETF',      'commodity',  6, true, 'USO'),
  ('BTC', 'Bitcoin',            'crypto',     7, true, 'BTCUSD'),
  ('ETH', 'Ethereum',           'crypto',     8, true, 'ETHUSD')
ON CONFLICT (ticker) DO NOTHING;

-- Seed price_band_stats rows for all band/window combinations (zeros until first compute)
INSERT INTO public.price_band_stats (price_band, stat_window, total_trades)
SELECT b.band, w.win, 0
FROM
  (VALUES ('0_25'),('25_50'),('50_100'),('100_200'),('200_plus')) AS b(band),
  (VALUES ('all_time'),('rolling_90d'),('rolling_1y'))            AS w(win)
ON CONFLICT (price_band, stat_window) DO NOTHING;

-- Admin user is created manually via Supabase Auth dashboard, then promoted:
-- UPDATE public.users SET is_admin = true WHERE email = 'k@kjsjournal.com';
