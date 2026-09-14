-- =====================================================================
-- Migration: 20260101000001_init_schema.sql
-- Purpose : Create the svings money-tracker schema.
-- Order    : Run first. Defines all types, tables, indexes, triggers.
--
-- Scope    : money tracking only. An earlier revision of this file also
--            defined a campus academic domain (faculties, programs,
--            lecturers, courses, students, enrollments, grades, attendance).
--            That was unrelated to this app and has been removed; it is in
--            git history if ever needed.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Enumerated types
-- ---------------------------------------------------------------------
do $$ begin
  create type transaction_type as enum ('income', 'expense');
exception when duplicate_object then null; end $$;

-- How a transaction got recorded. Lets the UI distinguish entries the user
-- typed from entries the email sync produced.
do $$ begin
  create type transaction_source as enum ('manual', 'email');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- updated_at trigger function
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- =====================================================================
-- 1. profiles — extends auth.users with app-specific fields
-- =====================================================================
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  full_name    text        not null,
  email        text        not null unique,
  avatar_url   text,
  phone        text,
  is_active    boolean     not null default true,
  metadata     jsonb       not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_profiles_email on public.profiles (email);

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Auto-create a profile row when a new user signs up via Supabase Auth
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- 2. raw_emails — fetched bank / e-wallet notification emails
--
-- Stored before parsing so that:
--   * a re-sync is idempotent — (user_id, message_id) is the dedupe key
--   * the parser can be improved later and re-run over the stored bodies
-- =====================================================================
create table if not exists public.raw_emails (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid        not null references public.profiles(id) on delete cascade,
  message_id   text        not null,        -- provider's message id (Gmail)
  thread_id    text,
  received_at  timestamptz,
  sender       text,
  subject      text,
  body         text        not null,
  parsed       boolean     not null default false,
  parse_error  text,                        -- why parsing failed, if it did
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (user_id, message_id)
);

create index if not exists idx_raw_emails_user_parsed on public.raw_emails (user_id, parsed);
create index if not exists idx_raw_emails_received on public.raw_emails (received_at desc);

drop trigger if exists trg_raw_emails_updated_at on public.raw_emails;
create trigger trg_raw_emails_updated_at
  before update on public.raw_emails
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 3. transactions — the money entries
-- =====================================================================
create table if not exists public.transactions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid        not null references public.profiles(id) on delete cascade,
  type         transaction_type not null,
  date         date        not null,
  total        numeric(14,2) not null check (total >= 0),
  notes        text,
  -- [{name, price}] where price is a STRING; see docs/DATABASE.md
  items        jsonb       not null default '[]'::jsonb,
  source       transaction_source not null default 'manual',
  raw_email_id uuid        references public.raw_emails(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_transactions_user_date on public.transactions (user_id, date desc);
create index if not exists idx_transactions_type on public.transactions (type);
create index if not exists idx_transactions_user_type_date on public.transactions (user_id, type, date);
create index if not exists idx_transactions_raw_email on public.transactions (raw_email_id);

drop trigger if exists trg_transactions_updated_at on public.transactions;
create trigger trg_transactions_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();

-- =====================================================================
-- Done.
-- =====================================================================
