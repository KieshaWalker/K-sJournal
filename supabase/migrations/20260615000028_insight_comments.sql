-- Member comments/questions on insights — the same thread model trades use,
-- so a member can ask K about a macro take or a ticker note the same way
-- they ask about a position.
CREATE TABLE public.insight_comments (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  insight_id        uuid NOT NULL REFERENCES public.insights(id) ON DELETE CASCADE,
  user_id           uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  parent_comment_id uuid REFERENCES public.insight_comments(id) ON DELETE CASCADE,
  body              text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  is_question       boolean NOT NULL DEFAULT false,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_insight_comments_insight ON public.insight_comments(insight_id, created_at);
CREATE INDEX idx_insight_comments_user    ON public.insight_comments(user_id);

ALTER TABLE public.insight_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insight_comments FORCE ROW LEVEL SECURITY;

CREATE TRIGGER set_insight_comments_updated_at
  BEFORE UPDATE ON public.insight_comments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Read: any member tier, on a published insight.
CREATE POLICY "members_read_insight_comments" ON public.insight_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.insights i
      WHERE i.id = insight_comments.insight_id
        AND i.is_published = true
        AND auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle')
    )
  );

-- Post: Inner Circle only, as themselves, on a published insight.
CREATE POLICY "inner_circle_post_insight_comments" ON public.insight_comments FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND auth.jwt() ->> 'membership_tier' = 'inner_circle'
    AND EXISTS (
      SELECT 1 FROM public.insights i
      WHERE i.id = insight_comments.insight_id
        AND i.is_published = true
    )
  );

-- Edit/delete own comment within 48 hours of posting.
CREATE POLICY "author_update_own_insight_comment" ON public.insight_comments FOR UPDATE
  USING (user_id = auth.uid() AND created_at > now() - interval '48 hours')
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "author_delete_own_insight_comment" ON public.insight_comments FOR DELETE
  USING (user_id = auth.uid() AND created_at > now() - interval '48 hours');

CREATE POLICY "admin_all_insight_comments" ON public.insight_comments FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ----

-- The "most active" rail counts a member by where they show up in the room.
-- Insight questions and comments are that same activity, so fold them into
-- the trailing-30-day tally alongside wall posts and trade comments.
CREATE OR REPLACE VIEW public.public_profiles AS
  SELECT
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.bio,
    u.location,
    date_part('year', age(u.birth_date))::int AS age,
    u.membership_tier,
    u.is_admin,
    u.created_at AS member_since,
    (SELECT count(*)::int
       FROM public.tracked_trades tt
      WHERE tt.user_id = u.id) AS trades_followed,
    (SELECT count(*)::int
       FROM public.community_posts p
      WHERE p.user_id = u.id
        AND p.created_at > now() - interval '30 days')
    + (SELECT count(*)::int
         FROM public.trade_comments c
        WHERE c.user_id = u.id
          AND c.created_at > now() - interval '30 days')
    + (SELECT count(*)::int
         FROM public.insight_comments ic
        WHERE ic.user_id = u.id
          AND ic.created_at > now() - interval '30 days') AS recent_activity
  FROM public.users u;
