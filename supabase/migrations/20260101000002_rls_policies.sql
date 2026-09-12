-- =====================================================================
-- Migration: 20260101000002_rls_policies.sql
-- Purpose : Enable RLS and define access policies.
-- =====================================================================

-- Helper: get the current authenticated user
create or replace function public.current_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid();
$$;

-- Helper: does the current user own a given student record?
create or replace function public.is_current_student(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.students s
    where s.id = p_student_id
      and s.user_id = auth.uid()
  );
$$;

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
-- Reference tables (faculties, programs, lecturers, courses, schedules)
-- Public read-only for all authenticated users.
-- ---------------------------------------------------------------------
alter table public.faculties         enable row level security;
alter table public.study_programs    enable row level security;
alter table public.lecturers         enable row level security;
alter table public.courses           enable row level security;
alter table public.class_sections    enable row level security;
alter table public.schedules         enable row level security;

drop policy if exists "ref_read_all_authenticated" on public.faculties;
create policy "ref_read_all_authenticated"
  on public.faculties for select to authenticated using (true);

drop policy if exists "ref_read_all_authenticated" on public.study_programs;
create policy "ref_read_all_authenticated"
  on public.study_programs for select to authenticated using (true);

drop policy if exists "ref_read_all_authenticated" on public.lecturers;
create policy "ref_read_all_authenticated"
  on public.lecturers for select to authenticated using (true);

drop policy if exists "ref_read_all_authenticated" on public.courses;
create policy "ref_read_all_authenticated"
  on public.courses for select to authenticated using (true);

drop policy if exists "ref_read_all_authenticated" on public.class_sections;
create policy "ref_read_all_authenticated"
  on public.class_sections for select to authenticated using (true);

drop policy if exists "ref_read_all_authenticated" on public.schedules;
create policy "ref_read_all_authenticated"
  on public.schedules for select to authenticated using (true);

-- ---------------------------------------------------------------------
-- Students — users can read their own student record; everyone authenticated
-- can read the public student roster (for the demo).
-- ---------------------------------------------------------------------
alter table public.students enable row level security;

drop policy if exists "students_read_authenticated" on public.students;
create policy "students_read_authenticated"
  on public.students for select to authenticated using (true);

drop policy if exists "students_update_own" on public.students;
create policy "students_update_own"
  on public.students for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- enrollments / grades / attendance
-- A user can see records linked to their own student record.
-- ---------------------------------------------------------------------
alter table public.enrollments enable row level security;
alter table public.grades     enable row level security;
alter table public.attendance enable row level security;

drop policy if exists "enrollments_read_own" on public.enrollments;
create policy "enrollments_read_own"
  on public.enrollments for select
  using (public.is_current_student(student_id));

drop policy if exists "grades_read_own" on public.grades;
create policy "grades_read_own"
  on public.grades for select
  using (
    exists (
      select 1 from public.enrollments e
      where e.id = grades.enrollment_id
        and public.is_current_student(e.student_id)
    )
  );

drop policy if exists "attendance_read_own" on public.attendance;
create policy "attendance_read_own"
  on public.attendance for select
  using (
    exists (
      select 1 from public.enrollments e
      where e.id = attendance.enrollment_id
        and public.is_current_student(e.student_id)
    )
  );

-- For the demo we relax to read-by-all-authenticated so demo accounts can
-- see each other's rosters. Comment out the policies above and keep these
-- open-read policies if you want full public read for the demo:
--
-- create policy "enrollments_read_all"  on public.enrollments  for select to authenticated using (true);
-- create policy "grades_read_all"      on public.grades       for select to authenticated using (true);
-- create policy "attendance_read_all"  on public.attendance   for select to authenticated using (true);

-- ---------------------------------------------------------------------
-- v_student_summary view — re-grant select to authenticated
-- ---------------------------------------------------------------------
grant select on public.v_student_summary to authenticated;
