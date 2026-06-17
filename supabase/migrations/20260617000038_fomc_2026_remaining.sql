-- Remaining 2026 FOMC rate decisions (2026-06-17)
--
-- The macro_events docket (see 20260616000036) shipped with the June 16-17
-- meeting seeded. This fills in the rest of the Fed's 2026 calendar so the
-- dashboard's catalyst feed carries every rate decision through year-end.
--
-- Dates are the second (decision) day of each two-day meeting, per the Fed's
-- published 2026 schedule. The statement releases at 2:00 PM ET with the
-- Chair's press conference at 2:30 PM ET. Quarterly meetings (Sep, Dec) also
-- carry an updated Summary of Economic Projections and a fresh dot plot.
--
-- Scenarios mirror the seeded June event: Cut -> bullish, Hold -> neutral,
-- Hike -> bearish, rendered as colour-coded chips. K can edit or remove any of
-- these from the Trade Workbench; each auto-hides from the dashboard once its
-- date passes.

INSERT INTO public.macro_events
  (title, detail, event_date, event_time, category, scenarios, display_order)
VALUES
  ('FOMC Rate Decision',
   'Statement and press conference, with no refreshed projections. The first policy read since June.',
   '2026-07-29', '2:00 PM ET', 'FOMC',
   '[{"label":"Cut","effect":"bullish"},
     {"label":"Hold","effect":"neutral"},
     {"label":"Hike","effect":"bearish"}]'::jsonb,
   0),

  ('FOMC Rate Decision',
   'A projection meeting. The updated Summary of Economic Projections and a new dot plot land with the statement.',
   '2026-09-16', '2:00 PM ET', 'FOMC',
   '[{"label":"Cut","effect":"bullish"},
     {"label":"Hold","effect":"neutral"},
     {"label":"Hike","effect":"bearish"}]'::jsonb,
   0),

  ('FOMC Rate Decision',
   'Statement and press conference, with no refreshed projections.',
   '2026-10-28', '2:00 PM ET', 'FOMC',
   '[{"label":"Cut","effect":"bullish"},
     {"label":"Hold","effect":"neutral"},
     {"label":"Hike","effect":"bearish"}]'::jsonb,
   0),

  ('FOMC Rate Decision',
   'Final meeting of 2026. New projections and the year-end dot plot frame the path into 2027.',
   '2026-12-09', '2:00 PM ET', 'FOMC',
   '[{"label":"Cut","effect":"bullish"},
     {"label":"Hold","effect":"neutral"},
     {"label":"Hike","effect":"bearish"}]'::jsonb,
   0);
