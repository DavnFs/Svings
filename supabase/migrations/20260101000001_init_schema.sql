-- =====================================================================
-- Migration: 20260101000001_init_schema.sql
-- Purpose : Create the full Uangku + academic tracking schema.
-- Order    : Run first. Defines all tables, types, functions, triggers.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Enumerated types
-- ---------------------------------------------------------------------
do $$ begin
  create type transaction_type as enum ('income', 'expense');
exception when duplicate_object then null; end $$;

do $$ begin
  create type academic_status as enum (
    'active',          -- currently enrolled
    'on_leave',        -- cuti
    'probation',       -- peringatan / akademik
    'graduated',       -- lulus
    'dropped_out'      -- DO / mengundurkan diri
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type attendance_status as enum ('present', 'absent', 'permission', 'sick');
exception when duplicate_object then null; end $$;

do $$ begin
  create type day_of_week as enum (
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type grade_letter as enum ('A', 'B', 'C', 'D', 'E');
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
-- 2. faculties
-- =====================================================================
create table if not exists public.faculties (
  id          uuid primary key default gen_random_uuid(),
  code        text        not null unique,            -- e.g. 'FK', 'FT', 'FE'
  name        text        not null,                   -- e.g. 'Fakultas Komputer'
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists idx_faculties_code on public.faculties (code);

drop trigger if exists trg_faculties_updated_at on public.faculties;
create trigger trg_faculties_updated_at
  before update on public.faculties
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 3. study_programs — prodi
-- =====================================================================
create table if not exists public.study_programs (
  id            uuid primary key default gen_random_uuid(),
  faculty_id    uuid        not null references public.faculties(id) on delete restrict,
  code          text        not null unique,           -- e.g. 'IF', 'SI', 'AK'
  name          text        not null,                  -- e.g. 'Teknik Informatika'
  degree        text        not null default 'S1',     -- D3, S1, S2
  accreditation text,                                  -- A / B / C / Unggul
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_study_programs_faculty on public.study_programs (faculty_id);

drop trigger if exists trg_study_programs_updated_at on public.study_programs;
create trigger trg_study_programs_updated_at
  before update on public.study_programs
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 4. lecturers — dosen
-- =====================================================================
create table if not exists public.lecturers (
  id            uuid primary key default gen_random_uuid(),
  nidn          text        not null unique,           -- Nomor Induk Dosen Nasional
  full_name     text        not null,                  -- include 'S.Kom., M.Kom.' etc.
  email         text        unique,
  phone         text,
  expertise     text,                                  -- bidang keahlian
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_lecturers_nidn on public.lecturers (nidn);
create index if not exists idx_lecturers_name on public.lecturers (full_name);

drop trigger if exists trg_lecturers_updated_at on public.lecturers;
create trigger trg_lecturers_updated_at
  before update on public.lecturers
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 5. courses — mata kuliah
-- =====================================================================
create table if not exists public.courses (
  id              uuid primary key default gen_random_uuid(),
  code            text        not null unique,           -- e.g. 'IF101'
  name            text        not null,                  -- e.g. 'Algoritma dan Pemrograman'
  credits         smallint    not null check (credits > 0 and credits <= 8),
  semester_target smallint    not null check (semester_target between 1 and 14),
  description     text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_courses_code on public.courses (code);
create index if not exists idx_courses_semester on public.courses (semester_target);

drop trigger if exists trg_courses_updated_at on public.courses;
create trigger trg_courses_updated_at
  before update on public.courses
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 6. students — extends profiles with academic info
-- =====================================================================
create table if not exists public.students (
  id              uuid primary key default gen_random_uuid(),        -- surrogate PK
  user_id         uuid        unique references public.profiles(id) on delete set null,
  nim             text        not null unique,                        -- NIM: e.g. '21010111120001'
  full_name       text        not null,
  email           text        not null,
  gender          text        check (gender in ('M', 'F')),
  birth_date      date,
  address         text,
  phone           text,
  study_program_id uuid       not null references public.study_programs(id) on delete restrict,
  cohort_year     smallint    not null check (cohort_year between 2000 and 2100),
  current_semester smallint   not null default 1 check (current_semester between 1 and 14),
  gpa             numeric(3,2) not null default 0.00 check (gpa between 0 and 4),
  total_credits   smallint    not null default 0 check (total_credits >= 0),
  status          academic_status not null default 'active',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_students_nim on public.students (nim);
create index if not exists idx_students_user_id on public.students (user_id);
create index if not exists idx_students_program on public.students (study_program_id);
create index if not exists idx_students_status on public.students (status);

drop trigger if exists trg_students_updated_at on public.students;
create trigger trg_students_updated_at
  before update on public.students
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 7. class_sections — penawaran mata kuliah per semester
--    (a course offered in a specific semester, taught by a lecturer)
-- =====================================================================
create table if not exists public.class_sections (
  id            uuid primary key default gen_random_uuid(),
  course_id     uuid        not null references public.courses(id) on delete cascade,
  lecturer_id   uuid        not null references public.lecturers(id) on delete restrict,
  study_program_id uuid     not null references public.study_programs(id) on delete cascade,
  semester      smallint    not null check (semester between 1 and 14),
  academic_year text        not null,                   -- e.g. '2025/2026'
  section_label text        not null default 'A',       -- kelas A/B/C
  capacity      smallint    not null default 40 check (capacity > 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (course_id, study_program_id, semester, academic_year, section_label)
);

create index if not exists idx_class_sections_course on public.class_sections (course_id);
create index if not exists idx_class_sections_lecturer on public.class_sections (lecturer_id);
create index if not exists idx_class_sections_program_semester
  on public.class_sections (study_program_id, semester, academic_year);

drop trigger if exists trg_class_sections_updated_at on public.class_sections;
create trigger trg_class_sections_updated_at
  before update on public.class_sections
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 8. schedules — when a class_section meets
-- =====================================================================
create table if not exists public.schedules (
  id              uuid primary key default gen_random_uuid(),
  class_section_id uuid       not null references public.class_sections(id) on delete cascade,
  day             day_of_week not null,
  start_time      time        not null,
  end_time        time        not null,
  room            text        not null,                -- e.g. 'Gedung A - R.301'
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (end_time > start_time)
);

create index if not exists idx_schedules_class_section on public.schedules (class_section_id);
create index if not exists idx_schedules_day on public.schedules (day);

drop trigger if exists trg_schedules_updated_at on public.schedules;
create trigger trg_schedules_updated_at
  before update on public.schedules
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 9. enrollments — student ↔ class_section (KRS)
-- =====================================================================
create table if not exists public.enrollments (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid        not null references public.students(id) on delete cascade,
  class_section_id uuid       not null references public.class_sections(id) on delete cascade,
  enrolled_at     timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (student_id, class_section_id)
);

create index if not exists idx_enrollments_student on public.enrollments (student_id);
create index if not exists idx_enrollments_section on public.enrollments (class_section_id);

drop trigger if exists trg_enrollments_updated_at on public.enrollments;
create trigger trg_enrollments_updated_at
  before update on public.enrollments
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 10. grades — assignment, UTS, UAS, final, letter
-- =====================================================================
create table if not exists public.grades (
  id                 uuid primary key default gen_random_uuid(),
  enrollment_id      uuid     not null unique references public.enrollments(id) on delete cascade,
  assignment_score   numeric(5,2) check (assignment_score between 0 and 100),
  midterm_score      numeric(5,2) check (midterm_score between 0 and 100),     -- UTS
  final_score        numeric(5,2) check (final_score between 0 and 100),       -- UAS
  final_numeric      numeric(4,2) check (final_numeric between 0 and 4),       -- nilai akhir (0-4)
  letter_grade       grade_letter,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  -- Final numeric is computed from components if not supplied
  check (
    (assignment_score is null and midterm_score is null and final_score is null)
    or (final_numeric is not null)
  )
);

create index if not exists idx_grades_enrollment on public.grades (enrollment_id);
create index if not exists idx_grades_letter on public.grades (letter_grade);

drop trigger if exists trg_grades_updated_at on public.grades;
create trigger trg_grades_updated_at
  before update on public.grades
  for each row execute function public.set_updated_at();

-- Auto-compute final_numeric + letter_grade from components on insert/update
create or replace function public.compute_final_grade()
returns trigger
language plpgsql
as $$
declare
  a numeric(5,2) := coalesce(new.assignment_score, 0);
  m numeric(5,2) := coalesce(new.midterm_score, 0);
  f numeric(5,2) := coalesce(new.final_score, 0);
  -- Common Indonesian weighting: Tugas 30% + UTS 30% + UAS 40%
  weighted numeric(5,2);
begin
  if new.assignment_score is not null
     and new.midterm_score is not null
     and new.final_score is not null
  then
    weighted := (a * 0.30) + (m * 0.30) + (f * 0.40);

    new.final_numeric := case
      when weighted >= 85 then 4.00
      when weighted >= 80 then 3.75
      when weighted >= 75 then 3.50
      when weighted >= 70 then 3.00
      when weighted >= 65 then 2.50
      when weighted >= 60 then 2.00
      when weighted >= 55 then 1.50
      when weighted >= 40 then 1.00
      else 0.00
    end;

    new.letter_grade := case
      when weighted >= 85 then 'A'
      when weighted >= 80 then 'A'  -- some unis use A- = 80, A = 85; we use A for both
      when weighted >= 75 then 'B'
      when weighted >= 70 then 'B'
      when weighted >= 65 then 'C'
      when weighted >= 60 then 'C'
      when weighted >= 55 then 'D'
      else 'E'
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_grades_compute on public.grades;
create trigger trg_grades_compute
  before insert or update on public.grades
  for each row execute function public.compute_final_grade();

-- =====================================================================
-- 11. attendance — rekap kehadiran per enrollment per pertemuan
-- =====================================================================
create table if not exists public.attendance (
  id             uuid primary key default gen_random_uuid(),
  enrollment_id  uuid        not null references public.enrollments(id) on delete cascade,
  meeting_date   date        not null,
  meeting_number smallint    not null check (meeting_number > 0),
  status         attendance_status not null,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (enrollment_id, meeting_date)
);

create index if not exists idx_attendance_enrollment on public.attendance (enrollment_id);
create index if not exists idx_attendance_date on public.attendance (meeting_date);
create index if not exists idx_attendance_status on public.attendance (status);

drop trigger if exists trg_attendance_updated_at on public.attendance;
create trigger trg_attendance_updated_at
  before update on public.attendance
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 12. transactions — money tracker (Pemasukan / Pengeluaran)
-- =====================================================================
create table if not exists public.transactions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid        not null references public.profiles(id) on delete cascade,
  type         transaction_type not null,
  date         date        not null,
  total        numeric(14,2) not null check (total >= 0),
  notes        text,
  items        jsonb       not null default '[]'::jsonb,  -- [{name, price}]
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists idx_transactions_user_date on public.transactions (user_id, date desc);
create index if not exists idx_transactions_type on public.transactions (type);
create index if not exists idx_transactions_user_type_date on public.transactions (user_id, type, date);

drop trigger if exists trg_transactions_updated_at on public.transactions;
create trigger trg_transactions_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 13. View: v_student_summary — denormalized summary per student
-- =====================================================================
create or replace view public.v_student_summary as
select
  s.id              as student_id,
  s.nim,
  s.full_name,
  s.email,
  s.current_semester,
  s.gpa,
  s.status,
  s.cohort_year,
  sp.id             as program_id,
  sp.code           as program_code,
  sp.name           as program_name,
  f.id              as faculty_id,
  f.code            as faculty_code,
  f.name            as faculty_name,
  (select count(*) from public.enrollments e where e.student_id = s.id) as total_courses,
  (select count(*) from public.enrollments e
     join public.grades g on g.enrollment_id = e.id
     where e.student_id = s.id and g.letter_grade in ('A','B','C')) as courses_passed,
  (select count(*) from public.attendance a
     join public.enrollments e on e.id = a.enrollment_id
     where e.student_id = s.id and a.status = 'present') as total_attended,
  (select count(*) from public.attendance a
     join public.enrollments e on e.id = a.enrollment_id
     where e.student_id = s.id) as total_meetings
from public.students s
join public.study_programs sp on sp.id = s.study_program_id
join public.faculties f on f.id = sp.faculty_id;

-- =====================================================================
-- Done.
-- =====================================================================
