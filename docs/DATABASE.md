# Database reference

Supabase Postgres schema for **svings** (money tracking + a campus academic dashboard).

Source of truth is the SQL, not this file:

| File | Contents |
|---|---|
| `supabase/migrations/20260101000001_init_schema.sql` | Enums, tables, indexes, triggers, `v_student_summary` |
| `supabase/migrations/20260101000002_rls_policies.sql` | Row Level Security |
| `supabase/seed/*.sql` | Reference + demo data |

> Rename note: `supabase/README.md` previously listed a `..._seed_reference_data.sql`
> migration and named the RLS file `..._000003_...`. Neither exists — there are two
> migrations, listed above.

## Two domains in one database

The money tracker and the academic dashboard share `profiles` as their identity anchor and
nothing else. They can be read independently.

```
auth.users ──1:1── profiles ──1:N── transactions          ← money tracker
                       │
                       └──0:1── students ──1:N── enrollments ──1:1── grades
                                                        └──1:N── attendance
                                                        └──1:1── class_sections
                                                                   ├─ courses
                                                                   ├─ lecturers
                                                                   └─ 1:N schedules
                          faculties ──1:N── study_programs ──1:N── students
                                                                   class_sections
```

## Enums

| Type | Values |
|---|---|
| `transaction_type` | `income`, `expense` |
| `academic_status` | `active`, `on_leave`, `probation`, `graduated`, `dropped_out` |
| `attendance_status` | `present`, `absent`, `permission`, `sick` |
| `day_of_week` | `monday` … `sunday` |
| `grade_letter` | `A`, `B`, `C`, `D`, `E` |

## Money tracker

### `profiles` — identity, extends `auth.users`

`id` is the Supabase Auth user id (1:1 with `auth.users`). A trigger creates the row on signup.

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | → `auth.users(id)`, `on delete cascade` |
| `full_name` | `text` | from `raw_user_meta_data.full_name`, else the email local-part |
| `email` | `text` | unique |
| `avatar_url`, `phone` | `text` | nullable |
| `is_active` | `boolean` | default `true` |
| `metadata` | `jsonb` | default `{}` |
| `created_at`, `updated_at` | `timestamptz` | |

Trigger `on_auth_user_created` → `handle_new_user()` inserts this row on every `auth.users` insert.

### `transactions` — the money entries

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | |
| `user_id` | `uuid` | → `profiles(id)`, `on delete cascade` |
| `type` | `transaction_type` | `income` / `expense` — **the UI shows `Pemasukan` / `Pengeluaran`** |
| `date` | `date` | |
| `total` | `numeric(14,2)` | `check (total >= 0)` |
| `notes` | `text` | nullable |
| `items` | `jsonb` | `[{name, price}]`, default `[]` |

Two things worth knowing:

- **`items[].price` is a string**, not a number. The seed writes it as text
  (`jsonb_build_object('price', (... )::text)`) and aggregates with `x->>'price'`, so the
  Dart model keeps `HistoryItem.price` as `String` and converts at the display edge.
- **There is no unique constraint on `(user_id, date, type)`.** Multiple transactions may
  share a date, which is why the app looks entries up by `id` rather than by date.

Indexes: `(user_id, date desc)`, `(type)`, `(user_id, type, date)`.

## Academic data

| Table | Purpose | Keys |
|---|---|---|
| `faculties` | Faculties (`code` e.g. `FK`) | unique `code` |
| `study_programs` | Prodi under a faculty | → `faculties`, unique `code` |
| `lecturers` | Dosen | unique `nidn` |
| `courses` | Mata kuliah | unique `code`; `credits` 1–8; `semester_target` 1–14 |
| `students` | Extends `profiles` with academic info | unique `nim`; `user_id` → `profiles` (nullable) |
| `class_sections` | A course offered in a semester, taught by a lecturer | unique `(course_id, study_program_id, semester, academic_year, section_label)` |
| `schedules` | When a class section meets | → `class_sections`; `end_time > start_time` |
| `enrollments` | Student ↔ class section (KRS) | unique `(student_id, class_section_id)` |
| `grades` | One row per enrollment | → `enrollments`, **unique** `enrollment_id` |
| `attendance` | Per enrollment per meeting | unique `(enrollment_id, meeting_date)` |

`students.user_id` is nullable and is **not** selected by `v_student_summary` — the view joins
on `students.email`, so an account links to a student by email address, not by id.

### Derived values are computed in the database, not the app

`grades` has a trigger (`compute_final_grade`) that fills `final_numeric` and `letter_grade`
from the components whenever all three are present:

```
weighted = tugas*0.30 + uts*0.30 + uas*0.40
```

| weighted | `final_numeric` | `letter_grade` |
|---|---|---|
| ≥ 85 | 4.00 | A |
| ≥ 80 | 3.75 | A |
| ≥ 75 | 3.50 | B |
| ≥ 70 | 3.00 | B |
| ≥ 65 | 2.50 | C |
| ≥ 60 | 2.00 | C |
| ≥ 55 | 1.50 | D |
| ≥ 40 | 1.00 | E |
| else | 0.00 | E |

A `check` also enforces that a grade row with any component score set must carry a
`final_numeric`. Do not re-derive these in Dart — read them.

### `v_student_summary` — one row per student

Denormalised for the dashboard: student fields, program and faculty codes/names, plus
`total_courses`, `courses_passed` (letter grade A/B/C), `total_attended`, `total_meetings`.
Counts are correlated subqueries, so this view is for single-student reads, not bulk scans.

## Cross-cutting

- `public.set_updated_at()` is a `before update` trigger on **every** table with an
  `updated_at`. Never set `updated_at` from the client.
- `public.handle_new_user()` is `security definer` with `set search_path = public`.
- Row Level Security is enabled per table in `20260101000002_rls_policies.sql`. For
  `transactions` there are four policies (`select`/`insert`/`update`/`delete`), each
  `auth.uid() = user_id`. Reference tables (`courses`, `lecturers`, `faculties`, …) are
  readable by any authenticated user.

## Which tables the Flutter app touches

| Dart | Tables / views |
|---|---|
| `data/source/source_user.dart` | `profiles` (+ Supabase Auth) |
| `data/source/source_history.dart` | `transactions` |
| `data/source/source_student.dart` | `v_student_summary`, `enrollments`, `class_sections`, `courses`, `lecturers`, `schedules` |
| `data/model/history.dart` | maps `transactions` |
| `data/model/student.dart` | maps `v_student_summary`, `enrollments` + joins |

## Seeded demo accounts

`supabase/seed/99_demo_users.sql` creates two students with ~2 months of transactions:

| Email | Password |
|---|---|
| `demo@uangku.app` | `demo1234` |
| `demo2@uangku.app` | `demo1234` |

## Regenerating this doc

The tables above were read from `20260101000001_init_schema.sql`. If the schema changes, this
file is stale — update both together.
