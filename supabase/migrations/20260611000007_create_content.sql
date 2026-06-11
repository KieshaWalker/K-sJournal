CREATE TABLE public.insights (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  insight_date  date NOT NULL UNIQUE,
  title         text NOT NULL,
  body          text NOT NULL,
  macro_tags    text[],
  market_bias   text CHECK (market_bias IN ('bullish','bearish','neutral','cautious')),
  is_published  boolean NOT NULL DEFAULT false,
  published_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT published_at_required_when_published
    CHECK (NOT is_published OR published_at IS NOT NULL)
);

CREATE INDEX idx_insights_date
  ON public.insights(insight_date DESC)
  WHERE is_published = true;

ALTER TABLE public.insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insights FORCE ROW LEVEL SECURITY;
