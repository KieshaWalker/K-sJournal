-- Custom JWT claims hook — register in Dashboard → Authentication → Hooks
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  claims jsonb;
  user_tier text;
  user_is_admin boolean;
  user_username text;
BEGIN
  SELECT membership_tier, is_admin, username
  INTO user_tier, user_is_admin, user_username
  FROM public.users
  WHERE id = (event ->> 'user_id')::uuid;

  claims := event -> 'claims';
  claims := jsonb_set(claims, '{membership_tier}', coalesce(to_jsonb(user_tier), 'null'::jsonb));
  claims := jsonb_set(claims, '{is_admin}', coalesce(to_jsonb(user_is_admin), 'false'::jsonb));
  claims := jsonb_set(claims, '{username}', coalesce(to_jsonb(user_username), 'null'::jsonb));

  RETURN jsonb_set(event, '{claims}', claims);
END;
$$;

-- The auth hook runs as supabase_auth_admin
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin;
GRANT SELECT ON public.users TO supabase_auth_admin;

-- ----

-- Check if username is taken (anonymous callable during registration)
CREATE OR REPLACE FUNCTION public.check_username_taken(p_username text)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE username = lower(trim(p_username))
  );
$$;

-- ----

-- Atomic invite code decrement (race-condition safe)
CREATE OR REPLACE FUNCTION public.decrement_invite_use(p_code_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  rows_updated integer;
BEGIN
  UPDATE public.invitation_codes
  SET
    uses_remaining = uses_remaining - 1,
    status = CASE
      WHEN uses_remaining - 1 <= 0 THEN 'depleted'
      ELSE status
    END
  WHERE id = p_code_id
    AND uses_remaining > 0
    AND status = 'active'
    AND (expires_at IS NULL OR expires_at > now());

  GET DIAGNOSTICS rows_updated = ROW_COUNT;
  RETURN rows_updated > 0;
END;
$$;

-- ----

-- Atomic promo code increment
CREATE OR REPLACE FUNCTION public.increment_promo_use(p_promo_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.promo_codes
  SET
    uses_count = uses_count + 1,
    status = CASE
      WHEN max_uses IS NOT NULL AND uses_count + 1 >= max_uses THEN 'depleted'
      ELSE status
    END
  WHERE id = p_promo_id
    AND (max_uses IS NULL OR uses_count < max_uses);
$$;

-- ----

-- Price band stats aggregation (called by compute_price_band_stats Edge Function)
CREATE OR REPLACE FUNCTION public.compute_band_stats(
  p_band text,
  p_since date DEFAULT NULL
)
RETURNS TABLE (
  total_trades   bigint,
  winning_trades bigint,
  losing_trades  bigint,
  scratch_trades bigint,
  win_rate       numeric,
  avg_win_pnl    numeric,
  avg_loss_pnl   numeric,
  avg_pnl        numeric,
  total_pnl      numeric,
  profit_factor  numeric,
  avg_days_held  numeric
)
LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT
    COUNT(*)                                              AS total_trades,
    COUNT(*) FILTER (WHERE outcome = 'win')               AS winning_trades,
    COUNT(*) FILTER (WHERE outcome = 'loss')              AS losing_trades,
    COUNT(*) FILTER (WHERE outcome = 'scratch')           AS scratch_trades,
    ROUND(
      COUNT(*) FILTER (WHERE outcome = 'win')::numeric /
      NULLIF(COUNT(*), 0), 4
    )                                                     AS win_rate,
    ROUND(AVG(realized_pnl) FILTER (WHERE outcome = 'win'), 2)   AS avg_win_pnl,
    ROUND(AVG(realized_pnl) FILTER (WHERE outcome = 'loss'), 2)  AS avg_loss_pnl,
    ROUND(AVG(realized_pnl), 2)                                  AS avg_pnl,
    ROUND(SUM(realized_pnl), 2)                                  AS total_pnl,
    ROUND(
      NULLIF(SUM(realized_pnl) FILTER (WHERE outcome = 'win'), 0) /
      NULLIF(ABS(SUM(realized_pnl) FILTER (WHERE outcome = 'loss')), 0)
    , 4)                                                  AS profit_factor,
    ROUND(AVG(exit_date - entry_date), 2)                 AS avg_days_held
  FROM public.trades
  WHERE status     = 'landed'
    AND price_band = p_band
    AND (p_since IS NULL OR exit_date >= p_since);
$$;
