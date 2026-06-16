-- Early ideas (status = 'idea') are the rawest stage of the trade lifecycle,
-- one step ahead of pre-flight. They're the Inner Circle's "+ Early ideas"
-- perk, so expose them to that tier only — observers and analysts keep seeing
-- nothing until a setup is refined into pre-flight. Admin already reads every
-- status via admin_all_trades.
CREATE POLICY "inner_circle_read_ideas" ON public.trades FOR SELECT
  USING (
    auth.jwt() ->> 'membership_tier' = 'inner_circle'
    AND status = 'idea'
  );
