# Supabase

This directory contains the Supabase backend configuration for **Uangku** (a money-tracking app for Indonesian college students).

## Layout

```
supabase/
├── config.toml              # Supabase CLI config (start/stop/migration settings)
├── migrations/              # Versioned SQL migrations (run in lexicographic order)
│   ├── 20260101000001_init_schema.sql
│   ├── 20260101000002_seed_reference_data.sql
│   └── 20260101000003_rls_policies.sql
└── seed/                    # Idempotent seed data (dummy records for development)
    ├── 01_faculties_programs.sql
    ├── 02_lecturers.sql
    ├── 03_courses.sql
    ├── 04_students.sql
    ├── 05_schedules_grades_attendance.sql
    └── 99_demo_users.sql
```

## Quick start

```bash
# 1. Install the Supabase CLI
brew install supabase/tap/supabase           # macOS
# or scoop install supabase                   # Windows
# or curl -fsSL https://supabase.com/install.sh | sh  # Linux

# 2. Login & link your project
supabase login
supabase link --project-ref <your-project-ref>

# 3. Push all migrations
supabase db push

# 4. Run the seed scripts (in order, after migrations)
psql "$DATABASE_URL" -f supabase/seed/01_faculties_programs.sql
psql "$DATABASE_URL" -f supabase/seed/02_lecturers.sql
psql "$DATABASE_URL" -f supabase/seed/03_courses.sql
psql "$DATABASE_URL" -f supabase/seed/04_students.sql
psql "$DATABASE_URL" -f supabase/seed/05_schedules_grades_attendance.sql
psql "$DATABASE_URL" -f supabase/seed/99_demo_users.sql
```

## Local development

```bash
supabase start          # boots Postgres + GoTrue + PostgREST + Storage in Docker
supabase db reset       # drops, re-runs migrations, then re-runs seed/*
supabase stop           # shuts everything down
```

## What is in this database?

See [../docs/DATABASE.md](../docs/DATABASE.md) for the full schema, ERD, and table-by-table reference.

In short:
- **Auth** — `auth.users` (Supabase managed) + `public.profiles` (extended user data)
- **Money tracker** — `public.transactions` (replaces the old `history` table)
- **Academic data** — `faculties`, `study_programs`, `lecturers`, `courses`, `class_sections`, `schedules`, `enrollments`, `grades`, `attendance`
- **Indexes & RLS** — see migration files

## Demo accounts (created by `99_demo_users.sql`)

| Email                | Password   | Role            |
|----------------------|------------|-----------------|
| demo@uangku.app      | demo1234   | student (Budi)  |
| demo2@uangku.app     | demo1234   | student (Siti)  |

These accounts live in `auth.users` and `profiles`. Use them to test the login flow and view pre-seeded transactions.
