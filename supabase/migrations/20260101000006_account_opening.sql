-- =====================================================================
-- Migration: 20260101000006_account_opening.sql
-- Purpose : a "Saldo Awal" (opening balance) for new accounts, written
--           atomically with the account itself.
-- Order    : Run after 20260101000005_account_icons.sql.
--
-- Why a transaction type rather than a column on accounts: balance is DERIVED
-- from the ledger everywhere in this app (SourceAccount.balances, the Home
-- total, the account cards). A stored balance column would drift from the
-- ledger the first time a write half-succeeded, with no way to say which of the
-- two is right. An opening balance is therefore just the account's first
-- ledger entry, and every balance rule keeps working unchanged.
--
-- 'opening' counts toward that account's balance and toward nothing else: it is
-- absent from every income/expense aggregate (those query
-- type in ('income','expense')), exactly like 'transfer'.
-- =====================================================================

do $$ begin
  alter type transaction_type add value if not exists 'opening';
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- create_account_with_opening — one account, and its opening entry, or
-- neither.
--
-- A function body is one transaction, so a failure between the two inserts
-- rolls both back: there can be no account whose balance has no entry behind
-- it, and no entry pointing at an account that does not exist.
--
-- security invoker: the inserts run as the caller, so the accounts and
-- transactions RLS policies still apply. No security definer shortcut.
-- ---------------------------------------------------------------------
create or replace function public.create_account_with_opening(
  p_user    uuid,
  p_name    text,
  p_kind    text default 'other',
  p_icon    text default 'other',
  p_color   text default '#7C5CFF',
  p_opening numeric default 0,
  p_date    date default current_date
) returns public.accounts
language plpgsql
security invoker
as $$
declare
  created public.accounts;
begin
  insert into public.accounts (user_id, name, kind, icon, color)
    values (p_user, p_name, p_kind, p_icon, p_color)
    returning * into created;

  -- Only a real opening balance writes an entry. A zero would leave a
  -- meaningless row in the ledger that the user never asked for.
  if p_opening is not null and p_opening > 0 then
    insert into public.transactions
      (user_id, type, date, total, items, source, account_id)
      values (
        p_user,
        'opening',
        p_date,
        p_opening,
        jsonb_build_array(
          jsonb_build_object('name', 'Saldo Awal', 'price', p_opening::text)
        ),
        'manual',
        created.id
      );
  end if;

  return created;
end $$;

-- =====================================================================
-- Done.
-- =====================================================================
