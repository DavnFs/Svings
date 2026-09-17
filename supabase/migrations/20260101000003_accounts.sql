-- =====================================================================
-- Migration: 20260101000003_accounts.sql
-- Purpose : multi-source money accounts ("Sumber Dana") + transfers.
-- Order    : Run after 20260101000002_rls_policies.sql.
-- =====================================================================

-- Transfer moves money between two accounts of the same user. It must never
-- count toward income/expense totals: every aggregate query filters
-- type in ('income', 'expense'), never "all types".
do $$ begin
  alter type transaction_type add value if not exists 'transfer';
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- accounts — named, color-coded balance containers per user
-- ---------------------------------------------------------------------
-- Balance is DERIVED (sum of the account's transactions), never stored:
-- income adds, expense subtracts, transfer-out subtracts, transfer-in adds.
-- Storing a separate balance column would drift; the view below is truth.
create table if not exists public.accounts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid        not null references public.profiles(id) on delete cascade,
  name         text        not null,
  -- 'bank' | 'e-wallet' | 'cash' | 'other'. Free text, not an enum: adding a
  -- kind later must not need a migration.
  kind         text        not null default 'other',
  -- Emoji or short glyph shown on the card, e.g. '🏦'. No asset pipeline.
  icon         text        not null default '💰',
  -- ARGB hex string, e.g. '#7C5CFF'. Stored as text so no new type is needed.
  color        text        not null default '#7C5CFF',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (user_id, name)
);

create index if not exists idx_accounts_user on public.accounts (user_id);

drop trigger if exists trg_accounts_updated_at on public.accounts;
create trigger trg_accounts_updated_at
  before update on public.accounts
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- transactions: account links
-- ---------------------------------------------------------------------
-- account_id: the account this entry belongs to (income/expense).
-- For transfers, account_id is the SOURCE and transfer_to_account_id the
-- DESTINATION. Nullable + backfilled so existing rows survive the migration.
alter table public.transactions
  add column if not exists account_id uuid references public.accounts(id) on delete set null;
alter table public.transactions
  add column if not exists transfer_to_account_id uuid references public.accounts(id) on delete set null;

create index if not exists idx_transactions_account on public.transactions (account_id);
create index if not exists idx_transactions_transfer_to on public.transactions (transfer_to_account_id);

-- Every user gets exactly one default account; pre-existing transactions
-- (which predate accounts) are assigned to it. Idempotent: safe to re-run.
do $$
declare
  u uuid;
  default_id uuid;
begin
  for u in select id from public.profiles loop
    select id into default_id from public.accounts
      where user_id = u and name = 'Lainnya' limit 1;
    if default_id is null then
      insert into public.accounts (user_id, name, kind, icon, color)
        values (u, 'Lainnya', 'other', '💰', '#7C5CFF')
        returning id into default_id;
    end if;
    update public.transactions
      set account_id = default_id
      where user_id = u and account_id is null;
  end loop;
end $$;

-- =====================================================================
-- Done.
-- =====================================================================
