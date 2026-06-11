CREATE TABLE public.memberships (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  tier                   text NOT NULL CHECK (tier IN ('observer','analyst','inner_circle')),
  payment_status         text NOT NULL DEFAULT 'pending'
                           CHECK (payment_status IN ('pending','active','past_due','cancelled','paused')),
  plaid_item_id          text,
  plaid_payment_id       text,
  billing_cycle_start    date,
  next_billing_date      date,
  promo_code_id          uuid REFERENCES public.promo_codes(id) ON DELETE SET NULL,
  promo_discount_applied numeric(10,2),
  free_months_remaining  integer NOT NULL DEFAULT 0,
  monthly_amount         numeric(10,2) NOT NULL,
  pending_tier           text CHECK (pending_tier IN ('observer','analyst','inner_circle')),
  downgrade_scheduled    boolean NOT NULL DEFAULT false,
  cancelled_at           timestamptz,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT one_membership_per_user UNIQUE (user_id)
);

CREATE INDEX idx_memberships_billing_date
  ON public.memberships(next_billing_date)
  WHERE payment_status = 'active';

ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships FORCE ROW LEVEL SECURITY;

-- ----

CREATE TABLE public.billing_events (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membership_id uuid NOT NULL REFERENCES public.memberships(id) ON DELETE CASCADE,
  event_type    text NOT NULL CHECK (event_type IN (
                  'initiated','executed','failed','settled','cancelled',
                  'refunded','free_month_consumed','renewal_initiated',
                  'upgrade_charged','downgrade_scheduled'
                )),
  payment_id    text,
  amount        numeric(10,2),
  notes         text,
  occurred_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_billing_events_membership
  ON public.billing_events(membership_id, occurred_at DESC);

ALTER TABLE public.billing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_events FORCE ROW LEVEL SECURITY;
