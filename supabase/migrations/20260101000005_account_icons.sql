-- =====================================================================
-- Migration: 20260101000005_account_icons.sql
-- Purpose : account icons become stable identifiers instead of emoji glyphs.
-- Order    : Run after 20260101000004_accounts_rls.sql.
--
-- Only the icon REPRESENTATION changes. name, kind, color, created_at and the
-- derived balances are untouched, and no row is deleted: a value the app does
-- not recognise falls back to the generic mark for that account's kind.
--
-- The same mapping lives in Dart (AccountIcon.fromStored), so rows read
-- correctly even against a database where this migration has not run yet.
-- =====================================================================

-- Step 1: the emoji this app used to store -> its identifier.
update public.accounts
   set icon = case icon
                when '🏦' then 'bank'
                when '👛' then 'wallet'
                when '💵' then 'cash'
                when '💰' then 'savings'
                when '💳' then 'card'
                when '🐷' then 'savings'
                else icon
              end
 where icon in ('🏦', '👛', '💵', '💰', '💳', '🐷');

-- Step 2: anything left that is neither a known emoji nor a current key
-- (a glyph from an older build, a hand-edited row) falls back by kind.
update public.accounts
   set icon = case kind
                when 'bank' then 'bank'
                when 'e-wallet' then 'wallet'
                when 'cash' then 'cash'
                else 'other'
              end
 where icon not in (
   -- brands
   'gojek', 'shopee', 'grab', 'visa', 'mastercard', 'paypal', 'blibli',
   'bukalapak',
   -- generics
   'cash', 'bank', 'wallet', 'card', 'savings', 'other'
 );

-- New rows get a valid key by default too, instead of the old emoji.
alter table public.accounts alter column icon set default 'wallet';

comment on column public.accounts.icon is
  'Account icon identifier key (see AccountIcon in the app), not a glyph.';

-- =====================================================================
-- Done.
-- =====================================================================
