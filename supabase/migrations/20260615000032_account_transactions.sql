-- The cash ledger: every deposit into the book, withdrawal out of it, and
-- transfer between accounts. A tracking record first — but the figures feed
-- the account balances, so a withdrawal genuinely lowers what's there and a
-- transfer moves capital from one account to the other. Admin-only on every
-- verb; no member policy exists on purpose.
--
-- Shape is pinned per kind so a row can't half-describe a movement:
--   * deposit    — money in from outside: to_account only.
--   * withdrawal — money out of the book: from_account only.
--   * transfer   — between two distinct accounts: both, and different.
--
-- Both account references cascade: deleting an account takes its movements
-- with it, which also keeps the per-kind CHECK from being violated by a
-- reference going NULL.
CREATE TABLE public.account_transactions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind         text NOT NULL CHECK (kind IN ('deposit', 'withdrawal', 'transfer')),
  from_account uuid REFERENCES public.accounts(id) ON DELETE CASCADE,
  to_account   uuid REFERENCES public.accounts(id) ON DELETE CASCADE,
  amount       numeric(14,2) NOT NULL CHECK (amount > 0),
  occurred_on  date NOT NULL DEFAULT current_date,
  note         text CHECK (note IS NULL OR char_length(note) <= 280),
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT account_transactions_shape CHECK (
    (kind = 'deposit'    AND to_account   IS NOT NULL AND from_account IS NULL) OR
    (kind = 'withdrawal' AND from_account IS NOT NULL AND to_account   IS NULL) OR
    (kind = 'transfer'   AND from_account IS NOT NULL AND to_account IS NOT NULL
                         AND from_account <> to_account)
  )
);

CREATE INDEX account_transactions_occurred_on
  ON public.account_transactions (occurred_on DESC);

ALTER TABLE public.account_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_transactions FORCE ROW LEVEL SECURITY;

CREATE POLICY "admin_all_account_transactions"
  ON public.account_transactions FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);
