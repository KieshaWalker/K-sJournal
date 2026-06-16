-- K's book of accounts: every account that makes up the ledger, admin-only
-- on every verb — no member policy exists on purpose, so members can never
-- read the account names, sizes, or tax posture. Replaces the earlier
-- single-row account_settings: there can now be many accounts, each choosing
-- how it relates to the running totals.
--
--   * affects_balance — does this account's balance count toward the
--     aggregate current/total balance.
--   * affects_pnl     — does the global trading P&L land in this account.
--     The book keeps one trade ledger, so at most ONE account may hold it
--     (the trading account); the partial unique index enforces that.
CREATE TABLE public.accounts (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name             text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 60),
  starting_balance numeric(14,2) NOT NULL DEFAULT 0,
  tax_rate         numeric(5,4) NOT NULL DEFAULT 0.40
                     CHECK (tax_rate >= 0 AND tax_rate <= 1),
  affects_balance  boolean NOT NULL DEFAULT true,
  affects_pnl      boolean NOT NULL DEFAULT false,
  sort_order       integer NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

-- At most one trading account may hold the global realized P&L.
CREATE UNIQUE INDEX accounts_one_trading
  ON public.accounts (affects_pnl) WHERE affects_pnl;

-- Seed the first account: the trading account, where the P&L lands and which
-- counts toward the total. Seeded before RLS is forced on.
INSERT INTO public.accounts
  (name, starting_balance, tax_rate, affects_balance, affects_pnl, sort_order)
VALUES ('Main', 0, 0.40, true, true, 0);

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts FORCE ROW LEVEL SECURITY;

CREATE TRIGGER set_accounts_updated_at
  BEFORE UPDATE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY "admin_all_accounts" ON public.accounts FOR ALL
  USING ((auth.jwt() ->> 'is_admin')::boolean = true);
