-- The community wall: short member posts on the Community page. Replies
-- nest one level through parent_post_id; likes live in their own table so
-- the heart count and "did I like it" both fall out of a single embed.
CREATE TABLE public.community_posts (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  parent_post_id uuid REFERENCES public.community_posts(id) ON DELETE CASCADE,
  body           text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 280),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_community_posts_created ON public.community_posts(created_at DESC);
CREATE INDEX idx_community_posts_user    ON public.community_posts(user_id);
CREATE INDEX idx_community_posts_parent  ON public.community_posts(parent_post_id);

ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_posts FORCE ROW LEVEL SECURITY;

CREATE TRIGGER set_community_posts_updated_at
  BEFORE UPDATE ON public.community_posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Read and post: every member tier, as themselves. Unlike trade comments
-- (Inner Circle only), the wall is the whole room's.
CREATE POLICY "members_read_posts" ON public.community_posts FOR SELECT
  USING (auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle'));

CREATE POLICY "members_write_posts" ON public.community_posts FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle')
  );

-- Edit within the same 15-minute window as trade comments; delete any time —
-- members keep the right to take their own words down.
CREATE POLICY "author_update_own_post" ON public.community_posts FOR UPDATE
  USING (user_id = auth.uid() AND created_at > now() - interval '15 minutes')
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "author_delete_own_post" ON public.community_posts FOR DELETE
  USING (user_id = auth.uid());

CREATE POLICY "admin_all_posts" ON public.community_posts FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ----

CREATE TABLE public.post_likes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX idx_post_likes_post ON public.post_likes(post_id);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes FORCE ROW LEVEL SECURITY;

CREATE POLICY "members_read_likes" ON public.post_likes FOR SELECT
  USING (auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle'));

CREATE POLICY "own_like_insert" ON public.post_likes FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND auth.jwt() ->> 'membership_tier' IN ('observer','analyst','inner_circle')
  );

CREATE POLICY "own_like_delete" ON public.post_likes FOR DELETE
  USING (user_id = auth.uid());

CREATE POLICY "admin_all_likes" ON public.post_likes FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);

-- ----

-- The "most active" rail orders members by who is actually in the room:
-- wall posts plus trade comments over the trailing 30 days. Appended as the
-- last column so the view replace stays legal.
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
          AND c.created_at > now() - interval '30 days') AS recent_activity
  FROM public.users u;
