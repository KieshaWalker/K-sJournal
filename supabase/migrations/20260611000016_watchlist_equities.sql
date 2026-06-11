-- Macro Pulse revision (2026-06-11): the external market-data project does
-- not track VIX/QQQ/IGV/BTC/ETH, so those tiles sat empty. New watchlist:
-- markets + big single names. Requires allowing 'equity' as an asset class.

ALTER TABLE public.watchlist_tickers
  DROP CONSTRAINT watchlist_tickers_asset_class_check;
ALTER TABLE public.watchlist_tickers
  ADD CONSTRAINT watchlist_tickers_asset_class_check
  CHECK (asset_class IN ('index','etf','commodity','crypto','volatility','equity'));

DELETE FROM public.watchlist_tickers
  WHERE ticker IN ('VIX','QQQ','IGV','BTC','ETH');

INSERT INTO public.watchlist_tickers
  (ticker, label, asset_class, display_order, is_active, source_symbol)
VALUES
  ('SPY',  'S&P 500 ETF',        'etf',       1, true, 'SPY'),
  ('SMH',  'Semiconductors ETF', 'etf',       2, true, 'SMH'),
  ('USO',  'Crude Oil ETF',      'commodity', 3, true, 'USO'),
  ('GLD',  'Gold ETF',           'commodity', 4, true, 'GLD'),
  ('NVDA', 'Nvidia',             'equity',    5, true, 'NVDA'),
  ('TSLA', 'Tesla',              'equity',    6, true, 'TSLA'),
  ('META', 'Meta',               'equity',    7, true, 'META'),
  ('MSTR', 'Strategy',           'equity',    8, true, 'MSTR')
ON CONFLICT (ticker) DO UPDATE
  SET label = EXCLUDED.label,
      asset_class = EXCLUDED.asset_class,
      display_order = EXCLUDED.display_order,
      is_active = true,
      source_symbol = EXCLUDED.source_symbol;
