-- Helper predicates read claims injected by custom_access_token_hook.
-- No policy = no access (RLS default-deny); service role bypasses RLS.

-- ---- users ----

CREATE POLICY "own_profile_read" ON public.users FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "own_profile_update" ON public.users FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    -- Cannot self-promote: tier/admin must match the JWT-claimed values
    AND is_admin = coalesce((auth.jwt() ->> 'is_admin')::boolean, false)
    AND membership_tier IS NOT DISTINCT FROM (auth.jwt() ->> 'membership_tier')
  );

CREATE POLICY "admin_read_all_users" ON public.users FOR SELECT
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

CREATE POLICY "admin_write_users" ON public.users FOR UPDATE
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- invitation_codes (no member read — prevents enumeration) ----

CREATE POLICY "admin_all_invite_codes" ON public.invitation_codes FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- promo_codes (no member read — prevents discount fishing) ----

CREATE POLICY "admin_all_promo_codes" ON public.promo_codes FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- memberships ----

CREATE POLICY "own_membership_read" ON public.memberships FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "admin_all_memberships" ON public.memberships FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- billing_events ----

CREATE POLICY "own_billing_events_read" ON public.billing_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.id = billing_events.membership_id AND m.user_id = auth.uid()
    )
  );

CREATE POLICY "admin_all_billing_events" ON public.billing_events FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- trades ----

CREATE POLICY "members_read_trades" ON public.trades FOR SELECT
  USING (
    auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle')
    AND status IN ('in_flight','landed')
  );

CREATE POLICY "analyst_read_preflight" ON public.trades FOR SELECT
  USING (
    auth.jwt() ->> 'membership_tier' IN ('analyst','inner_circle')
    AND status = 'pre_flight'
  );

CREATE POLICY "admin_all_trades" ON public.trades FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- trade_legs ----

CREATE POLICY "members_read_trade_legs" ON public.trade_legs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.trades t
      WHERE t.id = trade_legs.trade_id
        AND t.status IN ('in_flight','landed')
        AND auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle')
    )
  );

CREATE POLICY "admin_all_trade_legs" ON public.trade_legs FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- positions (writes via service role / admin only) ----

CREATE POLICY "members_read_positions" ON public.positions FOR SELECT
  USING (auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle'));

CREATE POLICY "admin_all_positions" ON public.positions FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- insights ----

CREATE POLICY "members_read_insights" ON public.insights FOR SELECT
  USING (auth.role() = 'authenticated' AND is_published = true);

CREATE POLICY "admin_read_all_insights" ON public.insights FOR SELECT
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

CREATE POLICY "admin_insert_insights" ON public.insights FOR INSERT
  WITH CHECK ((auth.jwt() ->> 'is_admin')::boolean = true);

CREATE POLICY "admin_update_insights" ON public.insights FOR UPDATE
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

CREATE POLICY "admin_delete_insights" ON public.insights FOR DELETE
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- market data (all authenticated members) ----

CREATE POLICY "members_read_market_snapshots" ON public.market_snapshots FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "members_read_volatility" ON public.volatility_data FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "members_read_watchlist" ON public.watchlist_tickers FOR SELECT
  USING (auth.role() = 'authenticated' AND is_active = true);

CREATE POLICY "admin_all_watchlist" ON public.watchlist_tickers FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ---- price_band_stats ----

CREATE POLICY "members_read_band_stats" ON public.price_band_stats FOR SELECT
  USING (auth.role() = 'authenticated');
