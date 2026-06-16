-- Admin can write market_snapshots directly (2026-06-16)
--
-- market_snapshots was, until now, only ever written by
-- admin_pull_market_data() — a SECURITY DEFINER function that bypasses RLS —
-- so the table carried just a member SELECT policy. The manual VIX entry in
-- the Trade Workbench upserts a row as the signed-in admin, which RLS
-- default-denied (42501: new row violates row-level security policy). Grant
-- admin full access, mirroring watchlist_tickers' admin_all policy. (FOR ALL
-- with only USING reuses that predicate as the INSERT/UPDATE WITH CHECK.)

CREATE POLICY "admin_all_market_snapshots" ON public.market_snapshots FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);
