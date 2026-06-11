-- Support for syncing from the external market-data project (iv_snapshots).
-- Core fields map onto volatility_data columns; the richer fields (GEX, vanna,
-- skew, vol trigger, ...) are retained losslessly in `extra` until the UI
-- decides which ones to surface as first-class columns.
ALTER TABLE public.volatility_data
  ADD COLUMN IF NOT EXISTS underlying_price numeric(10,2),
  ADD COLUMN IF NOT EXISTS extra jsonb;
