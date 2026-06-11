-- Social features: schema lands in Phase 1, UI ships in a later phase.

-- Member comments/questions on trades ("insta thread" style).
CREATE TABLE public.trade_comments (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id          uuid NOT NULL REFERENCES public.trades(id) ON DELETE CASCADE,
  user_id           uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  parent_comment_id uuid REFERENCES public.trade_comments(id) ON DELETE CASCADE,
  body              text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  is_question       boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_trade_comments_trade ON public.trade_comments(trade_id, created_at);
CREATE INDEX idx_trade_comments_user  ON public.trade_comments(user_id);

ALTER TABLE public.trade_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_comments FORCE ROW LEVEL SECURITY;

CREATE TRIGGER set_trade_comments_updated_at
  BEFORE UPDATE ON public.trade_comments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Read: any member who can see the parent trade
CREATE POLICY "members_read_trade_comments" ON public.trade_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.trades t
      WHERE t.id = trade_comments.trade_id
        AND t.status IN ('in_flight','landed')
        AND auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle')
    )
  );

-- Post: Inner Circle only, as themselves, on visible trades
CREATE POLICY "inner_circle_post_comments" ON public.trade_comments FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND auth.jwt() ->> 'membership_tier' = 'inner_circle'
    AND EXISTS (
      SELECT 1 FROM public.trades t
      WHERE t.id = trade_comments.trade_id
        AND t.status IN ('in_flight','landed')
    )
  );

-- Edit/delete own comment within 15 minutes of posting
CREATE POLICY "author_update_own_comment" ON public.trade_comments FOR UPDATE
  USING (user_id = auth.uid() AND created_at > now() - interval '15 minutes')
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "author_delete_own_comment" ON public.trade_comments FOR DELETE
  USING (user_id = auth.uid() AND created_at > now() - interval '15 minutes');

CREATE POLICY "admin_all_trade_comments" ON public.trade_comments FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ----

-- A member pins a trade to their own dashboard ("track this trade").
CREATE TABLE public.tracked_trades (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  trade_id   uuid NOT NULL REFERENCES public.trades(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, trade_id)
);

CREATE INDEX idx_tracked_trades_user ON public.tracked_trades(user_id);

ALTER TABLE public.tracked_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracked_trades FORCE ROW LEVEL SECURITY;

CREATE POLICY "own_tracked_trades_read" ON public.tracked_trades FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "own_tracked_trades_insert" ON public.tracked_trades FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.trades t
      WHERE t.id = tracked_trades.trade_id
        AND t.status IN ('in_flight','landed')
        AND auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle')
    )
  );

CREATE POLICY "own_tracked_trades_delete" ON public.tracked_trades FOR DELETE
  USING (user_id = auth.uid());

CREATE POLICY "admin_read_tracked_trades" ON public.tracked_trades FOR SELECT
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);
