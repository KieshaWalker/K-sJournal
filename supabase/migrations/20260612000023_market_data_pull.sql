-- Admin "Pull Market Data" button. K's separate market-data app snapshots
-- her real positions and the macro picture in its own Supabase project;
-- this function reaches over (URL + secret key live in Vault, never in the
-- client) and passes the numbers through on demand — no scheduled job.
--
-- Sources, in order of authority:
--   * position_legs + position_leg_snapshots — her actual contracts with
--     exact greeks, IV and mark per leg. Matched to trade_legs on
--     ticker/type/strike/expiry; no nearest-strike guessing.
--   * iv_snapshots → volatility_data and (with economy_quote_snapshots
--     for futures/macro symbols) → market_snapshots, for the dashboard
--     macro pulse. Equity closes ride on iv_snapshots.underlying_price;
--     day-change is computed against the prior stored close when the
--     source has none, so it self-heals as history accumulates.
--   * greek_grid_snapshots ATM cell — IV context for ideas with no legs.
--
-- Vault setup (one-time, NOT in this migration — secrets stay out of git):
--   select vault.create_secret('<url>',  'market_data_url');
--   select vault.create_secret('<key>',  'market_data_key');

CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- GET one REST path from the market-data project; NULL on any non-200.
-- Locked down: only the pull function (running as owner) may call it.
CREATE OR REPLACE FUNCTION public.market_data_fetch(
  p_url text, p_key text, p_path text)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v jsonb;
BEGIN
  SELECT r.content::jsonb INTO v
    FROM extensions.http((
           'GET', p_url || p_path,
           ARRAY[extensions.http_header('apikey', p_key),
                 extensions.http_header('Authorization', 'Bearer ' || p_key)],
           NULL, NULL)::extensions.http_request) r
   WHERE r.status = 200;
  RETURN v;
END;
$$;

REVOKE ALL ON FUNCTION public.market_data_fetch(text, text, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_pull_market_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_url    text;
  v_key    text;
  v_watch  text[];
  v_idea_tickers text[];
  v_ticker text;
  v_body   jsonb;
  v_quotes int := 0;
  v_vol    int := 0;
  v_legs   int := 0;
  v_trades int := 0;
  v_ideas  int := 0;
  v_unmatched text[];
  v_failed text[] := '{}';
BEGIN
  IF coalesce((auth.jwt() ->> 'is_admin')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'Admins only.';
  END IF;

  SELECT decrypted_secret INTO v_url
    FROM vault.decrypted_secrets WHERE name = 'market_data_url';
  SELECT decrypted_secret INTO v_key
    FROM vault.decrypted_secrets WHERE name = 'market_data_key';
  IF v_url IS NULL OR v_key IS NULL THEN
    RAISE EXCEPTION 'market_data_url / market_data_key not found in Vault.';
  END IF;

  -- ------------------------------------------------------------------
  -- Macro pulse: latest close/change and IV stats per watchlist ticker.
  -- ------------------------------------------------------------------
  SELECT array_agg(ticker) INTO v_watch
    FROM public.watchlist_tickers WHERE is_active;

  CREATE TEMP TABLE _quotes (
    ticker text, qdate date, close numeric, chg numeric
  ) ON COMMIT DROP;

  IF v_watch IS NOT NULL THEN
    -- Futures/macro symbols (/CL, /GC, $DXY, …) live in economy quotes.
    -- Every date the source has comes over, not just the latest — the
    -- stored history is what day-changes are computed from.
    v_body := public.market_data_fetch(v_url, v_key,
      '/rest/v1/economy_quote_snapshots'
      || '?select=symbol,date,price,change_percent'
      || '&symbol=in.(' || array_to_string(v_watch, ',') || ')'
      || '&order=date.desc&limit=' || cardinality(v_watch) * 10);
    IF v_body IS NOT NULL THEN
      INSERT INTO _quotes
      SELECT symbol, date, price, change_percent
        FROM jsonb_to_recordset(v_body) AS x(
               symbol text, date date, price numeric, change_percent numeric);
    END IF;

    v_body := public.market_data_fetch(v_url, v_key,
      '/rest/v1/iv_snapshots'
      || '?select=ticker,date,atm_iv,iv_rank,iv_rank_26w,iv_rank_4w,'
      || 'iv_percentile,underlying_price'
      || '&ticker=in.(' || array_to_string(v_watch, ',') || ')'
      || '&order=date.desc&limit=' || cardinality(v_watch) * 10);
    IF v_body IS NULL THEN
      v_failed := v_failed || 'iv_snapshots';
    ELSE
      WITH src AS (
        SELECT ticker, date, atm_iv, iv_rank, iv_rank_26w, iv_rank_4w,
               iv_percentile, underlying_price
          FROM jsonb_to_recordset(v_body) AS x(
                 ticker text, date date, atm_iv numeric, iv_rank numeric,
                 iv_rank_26w numeric, iv_rank_4w numeric,
                 iv_percentile numeric, underlying_price numeric)
      ), up AS (
        INSERT INTO public.volatility_data
               (ticker, snapshot_date, iv_current, iv_rank, iv_percentile,
                underlying_price)
        -- Longest-window rank the source has computed so far; the 52-week
        -- rank arrives once the market-data app has enough history.
        SELECT ticker, date, atm_iv,
               coalesce(iv_rank, iv_rank_26w, iv_rank_4w),
               iv_percentile, underlying_price
          FROM src
        ON CONFLICT (ticker, snapshot_date) DO UPDATE
           SET iv_current = excluded.iv_current,
               iv_rank = excluded.iv_rank,
               iv_percentile = excluded.iv_percentile,
               underlying_price = excluded.underlying_price
        RETURNING 1
      ), equity AS (
        -- Equity closes ride on the IV snapshot's underlying price.
        INSERT INTO _quotes
        SELECT ticker, date, underlying_price, NULL
          FROM src
         WHERE underlying_price IS NOT NULL
        RETURNING 1
      )
      SELECT count(*) INTO v_vol FROM up;
    END IF;

    -- One row per ticker and day; a source that carries a day-change
    -- beats one that doesn't.
    DELETE FROM _quotes
     WHERE ctid NOT IN (
       SELECT DISTINCT ON (ticker, qdate) ctid FROM _quotes
        ORDER BY ticker, qdate, (chg IS NULL));

    WITH up AS (
      INSERT INTO public.market_snapshots
             (ticker, snapshot_date, close, price_change_pct)
      SELECT ticker, qdate, close, chg FROM _quotes
      ON CONFLICT (ticker, snapshot_date) DO UPDATE
         SET close = excluded.close,
             price_change_pct = coalesce(excluded.price_change_pct,
                                         market_snapshots.price_change_pct)
      RETURNING 1
    )
    SELECT count(*) INTO v_quotes FROM up;

    -- Close-over-close day change for any stored row still missing one;
    -- backfills the whole history in the same pass.
    WITH ordered AS (
      SELECT id, close,
             lag(close) OVER (PARTITION BY ticker ORDER BY snapshot_date)
               AS prev_close
        FROM public.market_snapshots
       WHERE ticker = ANY (v_watch) AND close IS NOT NULL
    )
    UPDATE public.market_snapshots m
       SET price_change_pct =
             round((o.close - o.prev_close) / o.prev_close * 100, 4)
      FROM ordered o
     WHERE m.id = o.id
       AND m.price_change_pct IS NULL
       AND o.prev_close IS NOT NULL
       AND o.prev_close <> 0;
  END IF;

  -- ------------------------------------------------------------------
  -- Positions: the market-data app's own legs, latest snapshot per leg.
  -- ------------------------------------------------------------------
  CREATE TEMP TABLE _src (
    src_leg_id text, ticker text, option_type text, strike numeric,
    expiry date, snap_date date, mark numeric, delta numeric, gamma numeric,
    theta numeric, vega numeric, rho numeric, iv numeric
  ) ON COMMIT DROP;

  v_body := public.market_data_fetch(v_url, v_key,
    '/rest/v1/position_legs'
    || '?select=id,ticker,type,strike,expiry,'
    || 'position_leg_snapshots(snapshot_date,created_at,market_price,'
    || 'delta,gamma,theta,vega,rho,implied_vol)'
    || '&status=eq.open');
  IF v_body IS NULL THEN
    v_failed := v_failed || 'position_legs';
  ELSE
    INSERT INTO _src
    SELECT src_leg_id, ticker, option_type, strike, expiry,
           snap_date, mark, delta, gamma, theta, vega, rho, iv
      FROM (
        SELECT l ->> 'id'                        AS src_leg_id,
               l ->> 'ticker'                    AS ticker,
               l ->> 'type'                      AS option_type,
               (l ->> 'strike')::numeric         AS strike,
               (l ->> 'expiry')::date            AS expiry,
               (s ->> 'snapshot_date')::date     AS snap_date,
               (s ->> 'market_price')::numeric   AS mark,
               (s ->> 'delta')::numeric          AS delta,
               (s ->> 'gamma')::numeric          AS gamma,
               (s ->> 'theta')::numeric          AS theta,
               (s ->> 'vega')::numeric           AS vega,
               (s ->> 'rho')::numeric            AS rho,
               (s ->> 'implied_vol')::numeric    AS iv,
               row_number() OVER (
                 PARTITION BY l ->> 'id'
                 ORDER BY (s ->> 'snapshot_date')::date DESC,
                          s ->> 'created_at' DESC) AS rn
          FROM jsonb_array_elements(v_body) AS l
          CROSS JOIN LATERAL
               jsonb_array_elements(l -> 'position_leg_snapshots') AS s
      ) z
     WHERE rn = 1;
  END IF;

  -- Exact contract match: same ticker, side, strike and expiry.
  CREATE TEMP TABLE _leg_pick ON COMMIT DROP AS
  SELECT DISTINCT ON (tl.id)
         tl.id AS leg_id, tl.trade_id, tl.action, tl.quantity,
         s.delta, s.gamma, s.theta, s.vega, s.rho, s.iv, s.mark
    FROM public.trade_legs tl
    JOIN public.trades t
      ON t.id = tl.trade_id AND t.status IN ('idea', 'pre_flight', 'in_flight')
    JOIN _src s
      ON s.ticker = t.ticker
     AND s.option_type = tl.option_type
     AND s.strike = tl.strike
     AND s.expiry = tl.expiry_date
   ORDER BY tl.id, s.snap_date DESC;

  UPDATE public.trade_legs tl
     SET delta = p.delta, gamma = p.gamma, theta = p.theta,
         vega = p.vega, rho = p.rho, iv = p.iv
    FROM _leg_pick p
   WHERE tl.id = p.leg_id;
  GET DIAGNOSTICS v_legs = ROW_COUNT;

  SELECT array_agg(t.ticker || ' ' || tl.option_type || ' ' || tl.strike
                   || ' ' || tl.expiry_date)
    INTO v_unmatched
    FROM public.trade_legs tl
    JOIN public.trades t
      ON t.id = tl.trade_id AND t.status IN ('idea', 'pre_flight', 'in_flight')
   WHERE NOT EXISTS (SELECT 1 FROM _leg_pick p WHERE p.leg_id = tl.id);

  -- Roll legs up to the trade, per strategy unit. Credit strategies store
  -- current_price as cost-to-close and P&L as entry minus exit, matching
  -- the admin land form's convention.
  WITH unit AS (
    SELECT p.trade_id,
           sum(CASE WHEN p.action = 'buy' THEN 1 ELSE -1 END * p.quantity * p.delta) AS d,
           sum(CASE WHEN p.action = 'buy' THEN 1 ELSE -1 END * p.quantity * p.gamma) AS g,
           sum(CASE WHEN p.action = 'buy' THEN 1 ELSE -1 END * p.quantity * p.theta) AS th,
           sum(CASE WHEN p.action = 'buy' THEN 1 ELSE -1 END * p.quantity * p.vega)  AS vg,
           sum(CASE WHEN p.action = 'buy' THEN 1 ELSE -1 END * p.quantity * p.mark)  AS net_mark,
           avg(p.iv) AS iv
      FROM _leg_pick p
     GROUP BY p.trade_id
  ), scaled AS (
    SELECT t.id,
           greatest(coalesce(t.quantity, 1), 1) AS tq,
           t.strategy_type IN ('iron_condor','iron_butterfly','short_put',
                               'short_call','covered_call','cash_secured_put') AS is_credit,
           u.d, u.g, u.th, u.vg, u.iv, u.net_mark
      FROM public.trades t
      JOIN unit u ON u.trade_id = t.id
  )
  UPDATE public.trades t
     SET current_delta = s.d  / s.tq,
         current_gamma = s.g  / s.tq,
         current_theta = s.th / s.tq,
         current_vega  = s.vg / s.tq,
         current_iv    = s.iv,
         current_price = CASE WHEN s.is_credit THEN -1 ELSE 1 END
                         * s.net_mark / s.tq,
         unrealized_pnl = CASE
           WHEN t.entry_price IS NULL OR s.net_mark IS NULL THEN t.unrealized_pnl
           WHEN s.is_credit
             THEN (t.entry_price - (-1 * s.net_mark / s.tq)) * s.tq * 100
           ELSE (s.net_mark / s.tq - t.entry_price) * s.tq * 100
         END
    FROM scaled s
   WHERE t.id = s.id;
  GET DIAGNOSTICS v_trades = ROW_COUNT;

  -- ------------------------------------------------------------------
  -- Ideas with no legs yet: ATM IV context from the banded greek grid.
  -- ------------------------------------------------------------------
  SELECT array_agg(DISTINCT t.ticker) INTO v_idea_tickers
    FROM public.trades t
   WHERE t.status IN ('idea', 'pre_flight')
     AND NOT EXISTS (SELECT 1 FROM public.trade_legs tl WHERE tl.trade_id = t.id);

  IF v_idea_tickers IS NOT NULL THEN
    FOREACH v_ticker IN ARRAY v_idea_tickers LOOP
      v_body := public.market_data_fetch(v_url, v_key,
        '/rest/v1/greek_grid_snapshots'
        || '?select=iv'
        || '&ticker=eq.' || extensions.urlencode(v_ticker)
        || '&strike_band=eq.atm'
        || '&order=obs_date.desc,expiry_date.asc&limit=1');
      IF v_body IS NOT NULL AND jsonb_array_length(v_body) > 0 THEN
        UPDATE public.trades t
           SET current_iv = (v_body -> 0 ->> 'iv')::numeric
         WHERE t.ticker = v_ticker
           AND t.status IN ('idea', 'pre_flight')
           AND NOT EXISTS
               (SELECT 1 FROM public.trade_legs tl WHERE tl.trade_id = t.id);
        v_ideas := v_ideas + 1;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'macro_quotes',   v_quotes,
    'macro_vol',      v_vol,
    'trades_updated', v_trades,
    'legs_updated',   v_legs,
    'ideas_updated',  v_ideas,
    'as_of',          (SELECT max(snap_date) FROM _src),
    'unmatched_legs', coalesce(to_jsonb(v_unmatched), '[]'::jsonb),
    'failed_sources', to_jsonb(v_failed));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_pull_market_data() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_pull_market_data() FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_pull_market_data() TO authenticated;
