-- =====================================================================
-- Seed: 99_demo_users.sql
-- Purpose: Create 2 demo auth users for the app + sample transactions.
--
-- IMPORTANT: Passwords are stored as bcrypt hashes. The plain-text
-- passwords are documented in supabase/README.md — these are DEMO
-- credentials, do NOT use in production.
-- =====================================================================

-- 1. Create demo users in auth.users (triggers will create profiles).
--    Bcrypt hash of "demo1234" generated with cost=10.
do $$
declare
  v_user1_id uuid := '99999999-9999-9999-9999-999999999901';
  v_user2_id uuid := '99999999-9999-9999-9999-999999999902';
  -- bcrypt cost 10 of 'demo1234'. Checked with bcryptjs: this hash accepts
  -- 'demo1234' and rejects 'password', 'demo123', 'demo12345'.
  -- (The previous constant was the widely-copied example hash and matched none
  -- of those, so the demo accounts could not be signed into.)
  v_bcrypt   text := '$2a$10$2f4vxsLXeQqoQ8AuQq91pO6ZHDflPlNddDnOLlYOmt6POkqSuzoZq';
begin
  -- Delete if previously seeded (so re-running is idempotent)
  delete from auth.users where id in (v_user1_id, v_user2_id);

  insert into auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values
    (
      '00000000-0000-0000-0000-000000000000',
      v_user1_id,
      'authenticated',
      'authenticated',
      'demo@uangku.app',
      v_bcrypt,
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Ahmad Fauzan Ramadhani"}'::jsonb,
      now(), now(),
      '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      v_user2_id,
      'authenticated',
      'authenticated',
      'demo2@uangku.app',
      v_bcrypt,
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Putri Maharani"}'::jsonb,
      now(), now(),
      '', '', '', ''
    );

  raise notice 'Demo users created: demo@uangku.app / demo2@uangku.app (password: demo1234)';
end $$;

-- 3. Sample transactions so the home screen has data on first login.
--    Mix of income (allowance, freelance) and expense (food, transport, etc.)
--
--    Accounts: each demo user gets "Cash" + "Bank", all transactions tagged.
--    The accounts migration backfills real users to "Lainnya"; the seed creates
--    named accounts directly so the demo shows the multi-account UI.
do $$
declare
  v_user1_id uuid := '99999999-9999-9999-9999-999999999901';
  v_user2_id uuid := '99999999-9999-9999-9999-999999999902';
  v_today date := current_date;
  v_d date;
  v_items jsonb;
  v_cash1 uuid;
  v_bank1 uuid;
  v_cash2 uuid;
  v_bank2 uuid;
begin
  -- Wipe existing demo transactions (idempotent)
  delete from public.transactions where user_id in (v_user1_id, v_user2_id);
  delete from public.accounts where user_id in (v_user1_id, v_user2_id);

  insert into public.accounts (user_id, name, kind, icon, color)
    values (v_user1_id, 'Cash', 'cash', '💵', '#059669') returning id into v_cash1;
  insert into public.accounts (user_id, name, kind, icon, color)
    values (v_user1_id, 'Bank', 'bank', '🏦', '#0284C7') returning id into v_bank1;
  insert into public.accounts (user_id, name, kind, icon, color)
    values (v_user2_id, 'Cash', 'cash', '💵', '#059669') returning id into v_cash2;
  insert into public.accounts (user_id, name, kind, icon, color)
    values (v_user2_id, 'Bank', 'bank', '🏦', '#0284C7') returning id into v_bank2;

  -- User 1: Ahmad Fauzan - 30 days of realistic transactions
  for i in 0..29 loop
    v_d := v_today - i;

    -- expense: daily food (mostly), paid in cash
    if i % 3 <> 0 then
      v_items := jsonb_build_array(
        jsonb_build_object('name','Nasi + Lauk','price', (15000 + (random()*5000)::int)::text),
        jsonb_build_object('name','Es Teh/Air Mineral','price', (3000 + (random()*2000)::int)::text)
      );
      insert into public.transactions (user_id, account_id, type, date, total, items, notes)
      values (
        v_user1_id, v_cash1, 'expense', v_d,
        (select sum((x->>'price')::numeric) from jsonb_array_elements(v_items) x),
        v_items, 'Makan siang/kampus'
      );
    end if;

    -- expense: transport every other day, paid in cash
    if i % 2 = 0 then
      v_items := jsonb_build_array(
        jsonb_build_object('name','Bensin/Transport','price', (10000 + (random()*10000)::int)::text)
      );
      insert into public.transactions (user_id, account_id, type, date, total, items, notes)
      values (
        v_user1_id, v_cash1, 'expense', v_d,
        (select sum((x->>'price')::numeric) from jsonb_array_elements(v_items) x),
        v_items, 'Transport kampus'
      );
    end if;

    -- income: monthly allowance (1st of month), lands in the bank
    if extract(day from v_d) = 1 then
      v_items := jsonb_build_array(
        jsonb_build_object('name','Uang Saku Bulanan','price', '1500000')
      );
      insert into public.transactions (user_id, account_id, type, date, total, items, notes)
      values (
        v_user1_id, v_bank1, 'income', v_d, 1500000, v_items, 'Uang saku dari orang tua'
      );
    end if;

    -- income: freelance project every 10 days, lands in the bank
    if i % 10 = 5 then
      v_items := jsonb_build_array(
        jsonb_build_object('name','Freelance Web Project','price', (300000 + (random()*500000)::int)::text)
      );
      insert into public.transactions (user_id, account_id, type, date, total, items, notes)
      values (
        v_user1_id, v_bank1, 'income', v_d,
        (select sum((x->>'price')::numeric) from jsonb_array_elements(v_items) x),
        v_items, 'Project freelance'
      );
    end if;
  end loop;

  -- User 2: Putri Maharani - 30 days
  for i in 0..29 loop
    v_d := v_today - i;

    if i % 2 = 0 then
      v_items := jsonb_build_array(
        jsonb_build_object('name','Kopi & Snack','price', (12000 + (random()*8000)::int)::text),
        jsonb_build_object('name','Makan Siang','price', (18000 + (random()*7000)::int)::text)
      );
      insert into public.transactions (user_id, account_id, type, date, total, items, notes)
      values (
        v_user2_id, v_cash2, 'expense', v_d,
        (select sum((x->>'price')::numeric) from jsonb_array_elements(v_items) x),
        v_items, 'Jajan & makan'
      );
    end if;

    if extract(day from v_d) = 5 then
      v_items := jsonb_build_array(
        jsonb_build_object('name','Uang Saku','price', '2000000')
      );
      insert into public.transactions (user_id, account_id, type, date, total, items, notes)
      values (
        v_user2_id, v_bank2, 'income', v_d, 2000000, v_items, 'Transfer dari ortu'
      );
    end if;

    if i % 7 = 0 then
      v_items := jsonb_build_array(
        jsonb_build_object('name','Part-time Tutor','price', '150000')
      );
      insert into public.transactions (user_id, account_id, type, date, total, items, notes)
      values (
        v_user2_id, v_bank2, 'income', v_d, 150000, v_items, 'Les privat'
      );
    end if;
  end loop;
end $$;

-- 4. Summary
do $$
declare
  v_users int;
  v_profiles int;
  v_tx int;
begin
  select count(*) into v_users from auth.users where email like 'demo%@uangku.app';
  select count(*) into v_profiles from public.profiles where email like 'demo%@uangku.app';
  select count(*) into v_tx from public.transactions;

  raise notice 'Demo seed summary:';
  raise notice '  demo auth users     = %', v_users;
  raise notice '  demo profiles       = %', v_profiles;
  raise notice '  total transactions  = %', v_tx;
end $$;
