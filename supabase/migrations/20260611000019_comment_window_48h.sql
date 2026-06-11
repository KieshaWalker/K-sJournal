-- Authors get 48 hours (was 15 minutes) to edit or delete their own comments.
DROP POLICY "author_update_own_comment" ON public.trade_comments;
DROP POLICY "author_delete_own_comment" ON public.trade_comments;

CREATE POLICY "author_update_own_comment" ON public.trade_comments FOR UPDATE
  USING (user_id = auth.uid() AND created_at > now() - interval '48 hours')
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "author_delete_own_comment" ON public.trade_comments FOR DELETE
  USING (user_id = auth.uid() AND created_at > now() - interval '48 hours');
