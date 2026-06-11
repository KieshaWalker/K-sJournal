-- Universal updated_at function
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_memberships_updated_at
  BEFORE UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_trades_updated_at
  BEFORE UPDATE ON public.trades
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_trade_legs_updated_at
  BEFORE UPDATE ON public.trade_legs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_insights_updated_at
  BEFORE UPDATE ON public.insights
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ----

-- Auto-derive price_band from stock_price_at_entry (only if not already set)
CREATE OR REPLACE FUNCTION public.auto_set_price_band()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.stock_price_at_entry IS NOT NULL AND NEW.price_band IS NULL THEN
    NEW.price_band := CASE
      WHEN NEW.stock_price_at_entry <=  25 THEN '0_25'
      WHEN NEW.stock_price_at_entry <=  50 THEN '25_50'
      WHEN NEW.stock_price_at_entry <= 100 THEN '50_100'
      WHEN NEW.stock_price_at_entry <= 200 THEN '100_200'
      ELSE '200_plus'
    END;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trades_auto_price_band
  BEFORE INSERT OR UPDATE OF stock_price_at_entry ON public.trades
  FOR EACH ROW EXECUTE FUNCTION public.auto_set_price_band();

-- ----

-- Auto-create public.users on Supabase auth.users INSERT.
-- invite_code_id arrives via raw_user_meta_data; full invite validity is
-- re-checked server-side at membership activation (atomic decrement).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_username       text;
  v_invite_code_id uuid;
BEGIN
  v_username := lower(trim(NEW.raw_user_meta_data ->> 'username'));

  BEGIN
    v_invite_code_id := (NEW.raw_user_meta_data ->> 'invite_code_id')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_invite_code_id := NULL;
  END;

  INSERT INTO public.users (id, email, username, invitation_code_id)
  VALUES (NEW.id, NEW.email, v_username, v_invite_code_id);

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ----

-- Lock entry data once a trade is in_flight or landed
CREATE OR REPLACE FUNCTION public.prevent_entry_greek_overwrite()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.entry_delta IS NOT NULL AND NEW.entry_delta IS DISTINCT FROM OLD.entry_delta THEN
    RAISE EXCEPTION 'Entry Greeks are immutable once set.';
  END IF;
  IF OLD.entry_price IS NOT NULL AND NEW.entry_price IS DISTINCT FROM OLD.entry_price THEN
    RAISE EXCEPTION 'Entry price is immutable once set.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trades_lock_entry_data
  BEFORE UPDATE ON public.trades
  FOR EACH ROW
  WHEN (OLD.status IN ('in_flight','landed'))
  EXECUTE FUNCTION public.prevent_entry_greek_overwrite();
