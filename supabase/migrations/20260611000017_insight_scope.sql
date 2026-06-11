-- Insights graduate from one-per-day macro journal to scoped notes:
-- either on a specific ticker or on a macro theme, several per day allowed.
ALTER TABLE public.insights
  ADD COLUMN scope  text NOT NULL DEFAULT 'macro'
    CHECK (scope IN ('ticker','macro')),
  ADD COLUMN ticker text;

ALTER TABLE public.insights
  ADD CONSTRAINT ticker_required_when_ticker_scope
    CHECK (scope != 'ticker' OR ticker IS NOT NULL);

ALTER TABLE public.insights
  DROP CONSTRAINT IF EXISTS insights_insight_date_key;

CREATE INDEX idx_insights_ticker ON public.insights(ticker)
  WHERE scope = 'ticker' AND is_published = true;
