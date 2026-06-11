CREATE TABLE public.users (
  id                 uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username           text UNIQUE NOT NULL,
  display_name       text,
  avatar_url         text,
  email              text NOT NULL,
  membership_tier    text CHECK (membership_tier IN ('observer','analyst','inner_circle')),
  is_admin           boolean NOT NULL DEFAULT false,
  invitation_code_id uuid,  -- FK added after invitation_codes table created
  notification_prefs jsonb NOT NULL DEFAULT
    '{"email_insights":true,"email_trades":false,"email_billing":true}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users FORCE ROW LEVEL SECURITY;
