-- =====================================================================
-- Migration: 20260101000004_accounts_rls.sql
-- Purpose : RLS for public.accounts (per-user private, like transactions).
-- Order    : Run after 20260101000003_accounts.sql.
-- =====================================================================

alter table public.accounts enable row level security;

drop policy if exists "accounts_select_own" on public.accounts;
create policy "accounts_select_own"
  on public.accounts for select
  using (user_id = auth.uid());

drop policy if exists "accounts_insert_own" on public.accounts;
create policy "accounts_insert_own"
  on public.accounts for insert
  with check (user_id = auth.uid());

drop policy if exists "accounts_update_own" on public.accounts;
create policy "accounts_update_own"
  on public.accounts for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "accounts_delete_own" on public.accounts;
create policy "accounts_delete_own"
  on public.accounts for delete
  using (user_id = auth.uid());

-- =====================================================================
-- Done.
-- =====================================================================
