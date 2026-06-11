CREATE TABLE public.invitation_codes (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code           text UNIQUE NOT NULL,
  created_by     uuid REFERENCES public.users(id) ON DELETE SET NULL,
  approved_by_k  boolean NOT NULL DEFAULT true,  -- false for member-requested codes pending K's approval
  default_tier   text CHECK (default_tier IN ('observer','analyst','inner_circle')),
  max_uses       integer NOT NULL DEFAULT 1,
  uses_remaining integer NOT NULL DEFAULT 1,
  status         text NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active','expired','depleted','revoked')),
  expires_at     timestamptz,
  notes          text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uses_non_negative CHECK (uses_remaining >= 0)
);

ALTER TABLE public.invitation_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitation_codes FORCE ROW LEVEL SECURITY;

ALTER TABLE public.users
  ADD CONSTRAINT fk_users_invite_code
  FOREIGN KEY (invitation_code_id)
  REFERENCES public.invitation_codes(id)
  ON DELETE SET NULL;

-- ----

CREATE TABLE public.promo_codes (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code             text UNIQUE NOT NULL,
  discount_type    text NOT NULL CHECK (discount_type IN ('percent','fixed_amount','free_months')),
  discount_value   numeric(10,2) NOT NULL CHECK (discount_value > 0),
  applicable_tiers text[] NOT NULL DEFAULT ARRAY['observer','analyst','inner_circle'],
  max_uses         integer,
  uses_count       integer NOT NULL DEFAULT 0,
  valid_from       timestamptz NOT NULL DEFAULT now(),
  valid_until      timestamptz,
  status           text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','depleted')),
  created_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_codes FORCE ROW LEVEL SECURITY;
