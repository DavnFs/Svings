-- =====================================================================
-- Migration: 20260101000002_rls_policies.sql
-- Purpose : Enable RLS and define access policies.
--
-- Every table here is per-user private. There are no shared/reference tables
-- any more — the campus reference data they belonged to has been removed.
-- =====================================================================

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (id = auth.uid());

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
  on public.profiles for insert
  with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------
-- transactions — private to each user
-- ---------------------------------------------------------------------
alter table public.transactions enable row level security;

drop policy if exists "transactions_select_own" on public.transactions;
create policy "transactions_select_own"
  on public.transactions for select
  using (user_id = auth.uid());

drop policy if exists "transactions_insert_own" on public.transactions;
create policy "transactions_insert_own"
  on public.transactions for insert
  with check (user_id = auth.uid());

drop policy if exists "transactions_update_own" on public.transactions;
create policy "transactions_update_own"
  on public.transactions for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "transactions_delete_own" on public.transactions;
create policy "transactions_delete_own"
  on public.transactions for delete
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- raw_emails — private to each user
--
-- The email body is the most sensitive thing this app stores, so it gets the
-- same four-policy treatment as transactions rather than anything looser.
-- ---------------------------------------------------------------------
alter table public.raw_emails enable row level security;

drop policy if exists "raw_emails_select_own" on public.raw_emails;
create policy "raw_emails_select_own"
  on public.raw_emails for select
  using (user_id = auth.uid());

drop policy if exists "raw_emails_insert_own" on public.raw_emails;
create policy "raw_emails_insert_own"
  on public.raw_emails for insert
  with check (user_id = auth.uid());

drop policy if exists "raw_emails_update_own" on public.raw_emails;
create policy "raw_emails_update_own"
  on public.raw_emails for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "raw_emails_delete_own" on public.raw_emails;
create policy "raw_emails_delete_own"
  on public.raw_emails for delete
  using (user_id = auth.uid());
