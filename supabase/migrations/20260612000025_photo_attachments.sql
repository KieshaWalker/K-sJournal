-- Photos wherever words go: members attach a shot to wall posts; the
-- admin attaches charts to trades (idea through landed) and insights.
-- Files go browser-to-bucket like avatars; public read so feeds render
-- plain URLs without signing.
ALTER TABLE public.community_posts ADD COLUMN image_url text;
ALTER TABLE public.trades          ADD COLUMN image_url text;
ALTER TABLE public.insights        ADD COLUMN image_url text;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('media', 'media', true, 10485760,
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']);

CREATE POLICY "Media is publicly readable"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'media');

-- Everyone writes inside a folder named by their own uid; the admin may
-- write anywhere in the bucket.
CREATE POLICY "Members add media in their folder"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'media'
    AND ((storage.foldername(name))[1] = auth.uid()::text
         OR (auth.jwt() ->> 'is_admin')::boolean = true)
  );

CREATE POLICY "Members remove their own media"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'media'
    AND ((storage.foldername(name))[1] = auth.uid()::text
         OR (auth.jwt() ->> 'is_admin')::boolean = true)
  );
