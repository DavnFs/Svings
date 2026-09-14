# Database reference

Supabase Postgres schema for **svings**, a money tracker.

Source of truth is the SQL, not this file:

| File | Contents |
|---|---|
| `supabase/migrations/20260101000001_init_schema.sql` | Types, tables, indexes, triggers |
| `supabase/migrations/20260101000002_rls_policies.sql` | Row Level Security |
| `supabase/seed/99_demo_users.sql` | Two demo accounts + sample transactions |
| `supabase/apply_all.sql` | Generated: all of the above, one paste. Do not edit. |

> An earlier revision also defined a campus academic domain (faculties, programs,
> lecturers, courses, students, enrollments, grades, attendance and a
> `v_student_summary` view). It was unrelated to this app and has been removed.
> It is in git history if ever needed.

## Shape

Three tables. Everything is private to one user.

```
auth.users ──1:1── profiles ──1:N── transactions
                       │                  │
                       │                  └── raw_email_id ──0:1──┐
                       └──1:N── raw_emails ───────────────────────┘
```

## Types

| Type | Values | Used by |
|---|---|---|
| `transaction_type` | `income`, `expense` | `transactions.type` |
| `transaction_source` | `manual`, `email` | `transactions.source` |

The UI labels `income` as **Pemasukan** and `expense` as **Pengeluaran**.

## `profiles` — identity, extends `auth.users`

`id` is the Supabase Auth user id (1:1 with `auth.users`).

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | → `auth.users(id)`, `on delete cascade` |
| `full_name` | `text` | from `raw_user_meta_data.full_name`, else the email local-part |
| `email` | `text` | unique |
| `avatar_url`, `phone` | `text` | nullable |
| `is_active` | `boolean` | default `true` |
| `metadata` | `jsonb` | default `{}` |
| `created_at`, `updated_at` | `timestamptz` | |

Trigger `on_auth_user_created` → `handle_new_user()` inserts this row on every
`auth.users` insert. You never create a profile by hand.

## `transactions` — the money entries

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `user_id` | `uuid` | → `profiles(id)`, `on delete cascade` |
| `type` | `transaction_type` | `income` / `expense` |
| `date` | `date` | **not null** — the app cannot record an entry without one |
| `total` | `numeric(14,2)` | `check (total >= 0)` |
| `notes` | `text` | nullable |
| `items` | `jsonb` | `[{name, price}]`, default `[]` |
| `source` | `transaction_source` | `manual` (default) or `email` |
| `raw_email_id` | `uuid` | → `raw_emails(id)`, `on delete set null` |

Three things worth knowing:

- **`items[].price` is a string**, not a number. The seed writes it as text and
  aggregates with `x->>'price'`, so the Dart model keeps `HistoryItem.price` as
  `String` and converts only at the display edge.
- **There is no unique constraint on `(user_id, date, type)`.** Several
  transactions may share a date, which is why the app looks entries up by `id`.
- **`source` is how you tell an auto-parsed entry from a typed one.** Nothing
  before this had that distinction.

Indexes: `(user_id, date desc)`, `(type)`, `(user_id, type, date)`, `(raw_email_id)`.

## `raw_emails` — fetched notification emails

Stored **before** parsing, for two reasons: a re-sync must be idempotent, and the
parser will improve, so keeping the original body lets you re-parse without
re-fetching.

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `user_id` | `uuid` | → `profiles(id)`, `on delete cascade` |
| `message_id` | `text` | the provider's id (Gmail) — the dedupe key |
| `thread_id` | `text` | |
| `received_at` | `timestamptz` | the email's own timestamp |
| `sender`, `subject` | `text` | |
| `body` | `text` | not null — the text the parser reads |
| `parsed` | `boolean` | default `false` |
| `parse_error` | `text` | why parsing failed, if it did |
| `created_at`, `updated_at` | `timestamptz` | |

**`unique (user_id, message_id)`** is the constraint that makes sync safe to
re-run: inserting an already-seen message conflicts instead of duplicating a
transaction.

Indexes: `(user_id, parsed)`, `(received_at desc)`.

## Cross-cutting

- `public.set_updated_at()` is a `before update` trigger on every table with an
  `updated_at`. **Never set `updated_at` from the client.**
- `public.handle_new_user()` is `security definer` with `set search_path = public`.
- Row Level Security: all three tables are per-user. `profiles` has select/insert/
  update; `transactions` and `raw_emails` have all four verbs, each
  `auth.uid() = user_id`. There are no shared or public tables.
- `raw_emails.body` is the most sensitive data here, so it is scoped exactly as
  tightly as `transactions` — not looser.

## Which tables the Flutter app touches

| Dart | Tables |
|---|---|
| `data/source/source_user.dart` | `profiles` (+ Supabase Auth) |
| `data/source/source_history.dart` | `transactions` |
| `data/model/history.dart` | maps `transactions` |
| `data/model/user.dart` | maps `profiles` |
| `data/email/email_transaction_parser.dart` | nothing — pure function over an email body |

## Seeded demo accounts

`supabase/seed/99_demo_users.sql` creates two users and ~2 months of transactions:

| Email | Password |
|---|---|
| `demo@uangku.app` | `demo1234` |
| `demo2@uangku.app` | `demo1234` |

The password hash is bcrypt cost 10 and has been verified to accept `demo1234`.

## Demo data is not idempotent

The migrations are safe to re-run. The seed is not — it deletes and recreates the
demo users' rows, cascading to their transactions. Only run it against data you
are happy to reset.
