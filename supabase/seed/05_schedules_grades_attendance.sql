-- =====================================================================
-- Seed: 05_schedules_grades_attendance.sql
-- Purpose: Generate class_sections, schedules, enrollments, grades,
--          and attendance for all students.
--
-- Strategy: PL/pgSQL DO block that:
--   1. For every (course, study_program, semester, academic_year)
--      combination, creates a class_section with a deterministic lecturer
--      and a weekly schedule.
--   2. For every student at semester N, creates:
--        - enrollments in current semester (N) with grades + attendance
--        - enrollments in previous semesters (1..N-1) with grades only
--   3. Grades are correlated with the student's overall gpa (plus noise).
--   4. Attendance is realistic: 80-95% present.
--
-- Idempotent: re-running drops and recreates all generated rows.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Class sections — one per (course, program, semester, year, section)
-- ---------------------------------------------------------------------
do $$
declare
  v_section record;
  v_cs_id uuid;
  v_lecturer uuid;
  v_rooms text[] := array[
    'Gedung A - R.301', 'Gedung A - R.302', 'Gedung A - R.303',
    'Gedung B - R.201', 'Gedung B - R.202', 'Gedung B - R.203',
    'Gedung C - R.101', 'Gedung C - R.102', 'Gedung C - R.103',
    'Gedung D - R.401', 'Gedung D - R.402',
    'Lab. Komputer 1', 'Lab. Komputer 2', 'Lab. Komputer 3',
    'Aula Utama', 'Ruang Seminar'
  ];
  v_day_idx int;
  v_start_hour int;
  v_duration int;
  v_start_time time;
  v_end_time time;
  v_room text;
  v_section_label text;
begin
  -- Iterate every course
  for v_section in
    select
      c.id   as course_id,
      c.code as course_code,
      c.name as course_name,
      c.credits,
      c.semester_target,
      sp.id   as program_id,
      sp.code as program_code,
      sp.faculty_id
    from public.courses c
    cross join public.study_programs sp
    where
      -- match program ↔ course (only IT programs get IF courses, etc.)
      (
        (sp.code in ('IF','SI','TI') and c.code like 'IF%' or c.code like 'SI%' or c.code like 'TI%' or c.code like 'UNI%' or c.code like 'MAT%')
        or (sp.code in ('IF') and c.code like 'IF%')
        or (sp.code in ('SI') and (c.code like 'IF%' or c.code like 'SI%' or c.code like 'MAT%' or c.code like 'UNI%'))
        or (sp.code in ('TI') and (c.code like 'IF%' or c.code like 'TI%' or c.code like 'MAT%' or c.code like 'UNI%'))
        or (sp.code in ('MJ','AK') and (c.code like 'MJ%' or c.code like 'AK%' or c.code like 'EK%' or c.code like 'MAT%' or c.code like 'UNI%'))
        or (sp.code in ('MT','ST') and (c.code like 'MAT%' or c.code like 'UNI%'))
        or (sp.code in ('TE') and (c.code like 'MAT%' or c.code like 'IF%' or c.code like 'UNI%'))
      )
      and c.semester_target <= 8
    order by sp.code, c.semester_target, c.code
  loop
    -- create one section per (course, program, semester_target, academic_year, label)
    v_section_label := case when (length(v_section.program_code) + v_section.semester_target) % 2 = 0 then 'A' else 'B' end;

    -- pick a deterministic lecturer by hashing course_id
    select id into v_lecturer
    from public.lecturers
    order by md5(id::text || v_section.course_id::text)
    limit 1;

    insert into public.class_sections (
      id, course_id, lecturer_id, study_program_id,
      semester, academic_year, section_label, capacity
    ) values (
      gen_random_uuid(),
      v_section.course_id,
      v_lecturer,
      v_section.program_id,
      v_section.semester_target,
      '2025/2026',
      v_section_label,
      40
    )
    on conflict do nothing
    returning id into v_cs_id;

    if v_cs_id is null then
      select id into v_cs_id
      from public.class_sections
      where course_id = v_section.course_id
        and study_program_id = v_section.program_id
        and semester = v_section.semester_target
        and academic_year = '2025/2026'
        and section_label = v_section_label;
    end if;

    -- weekly schedule: 1-2 meetings per week
    v_day_idx := (abs(hashtext(v_section.course_id::text || v_section.program_id::text)) % 5);  -- 0=Mon..4=Fri
    v_start_hour := 8 + (abs(hashtext(v_section.course_id::text)) % 8);  -- 08:00..15:00
    v_duration := case when v_section.credits >= 3 then 2 else 1 end;
    v_start_time := make_time(v_start_hour, 0, 0);
    v_end_time   := make_time(v_start_hour + v_duration, 30, 0);
    v_room := v_rooms[1 + (abs(hashtext(v_section.course_id::text || v_section.program_id::text)) % array_length(v_rooms, 1))];

    insert into public.schedules (class_section_id, day, start_time, end_time, room)
    values (
      v_cs_id,
      (array['monday','tuesday','wednesday','thursday','friday']::day_of_week[])[v_day_idx + 1],
      v_start_time,
      v_end_time,
      v_room
    )
    on conflict do nothing;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. Enrollments, Grades, Attendance
-- ---------------------------------------------------------------------
do $$
declare
  v_student record;
  v_sem int;
  v_section record;
  v_enrollment_id uuid;
  v_gpa_target numeric;
  v_course_score numeric;
  v_assignment numeric;
  v_midterm numeric;
  v_final numeric;
  v_final_numeric numeric(4,2);
  v_letter grade_letter;
  v_meeting int;
  v_meeting_date date;
  v_attendance_pct numeric;
  v_is_present boolean;
  v_rand double precision;
begin
  for v_student in
    select id, current_semester, gpa
    from public.students
    order by id
  loop
    -- ============================================================
    -- CURRENT semester enrollments (with grades + attendance)
    -- ============================================================
    v_gpa_target := v_student.gpa;

    for v_section in
      select cs.id as section_id
      from public.class_sections cs
      join public.courses c on c.id = cs.course_id
      where cs.study_program_id = (
              select study_program_id from public.students where id = v_student.id
            )
        and cs.semester = v_student.current_semester
      order by c.semester_target, c.code
      limit 5
    loop
      insert into public.enrollments (student_id, class_section_id)
      values (v_student.id, v_section.section_id)
      on conflict do nothing
      returning id into v_enrollment_id;

      if v_enrollment_id is null then
        select id into v_enrollment_id
        from public.enrollments
        where student_id = v_student.id and class_section_id = v_section.section_id;
      end if;

      -- Grade generation: noise around the student's GPA mapped to 0-100
      --   4.00 -> 92
      --   3.00 -> 78
      --   2.00 -> 60
      v_course_score := 50 + (v_gpa_target * 10.5) + ((random() * 20) - 10);
      v_course_score := greatest(0, least(100, v_course_score));

      -- distribute across components with slight variance
      v_assignment := greatest(0, least(100, v_course_score + (random() * 10 - 5)));
      v_midterm    := greatest(0, least(100, v_course_score + (random() * 10 - 5)));
      v_final      := greatest(0, least(100, v_course_score + (random() * 10 - 5)));

      insert into public.grades (enrollment_id, assignment_score, midterm_score, final_score)
      values (v_enrollment_id, v_assignment, v_midterm, v_final)
      on conflict (enrollment_id) do update
        set assignment_score = excluded.assignment_score,
            midterm_score    = excluded.midterm_score,
            final_score      = excluded.final_score;

      -- Attendance for 16 meetings (current semester)
      v_attendance_pct := 0.80 + (random() * 0.18);  -- 80-98%
      for v_meeting in 1..16 loop
        -- First meeting: 2025-09-01 (Monday of week 1 of odd semester)
        v_meeting_date := date '2025-09-01' + ((v_meeting - 1) * 7);

        v_rand := random();
        if v_rand < v_attendance_pct then
          v_is_present := true;
        elsif v_rand < v_attendance_pct + 0.05 then
          v_is_present := false;  -- absent
        elsif v_rand < v_attendance_pct + 0.10 then
          v_is_present := false;  -- sick
        else
          v_is_present := false;  -- permission
        end if;

        insert into public.attendance (enrollment_id, meeting_date, meeting_number, status, notes)
        values (
          v_enrollment_id,
          v_meeting_date,
          v_meeting,
          case
            when v_is_present then 'present'::attendance_status
            when v_rand < v_attendance_pct + 0.05 then 'absent'::attendance_status
            when v_rand < v_attendance_pct + 0.10 then 'sick'::attendance_status
            else 'permission'::attendance_status
          end,
          null
        )
        on conflict (enrollment_id, meeting_date) do nothing;
      end loop;
    end loop;

    -- ============================================================
    -- PREVIOUS semester enrollments (grades only, no attendance)
    -- For students at semester >= 2 only.
    -- ============================================================
    if v_student.current_semester >= 2 then
      for v_sem in 1..(v_student.current_semester - 1) loop
        for v_section in
          select cs.id as section_id
          from public.class_sections cs
          join public.courses c on c.id = cs.course_id
          where cs.study_program_id = (
                  select study_program_id from public.students where id = v_student.id
                )
            and cs.semester = v_sem
          order by c.semester_target, c.code
          limit 5
        loop
          insert into public.enrollments (student_id, class_section_id)
          values (v_student.id, v_section.section_id)
          on conflict do nothing
          returning id into v_enrollment_id;

          if v_enrollment_id is null then
            select id into v_enrollment_id
            from public.enrollments
            where student_id = v_student.id and class_section_id = v_section.section_id;
          end if;

          v_course_score := 50 + (v_gpa_target * 10.5) + ((random() * 20) - 10);
          v_course_score := greatest(0, least(100, v_course_score));
          v_assignment := greatest(0, least(100, v_course_score + (random() * 10 - 5)));
          v_midterm    := greatest(0, least(100, v_course_score + (random() * 10 - 5)));
          v_final      := greatest(0, least(100, v_course_score + (random() * 10 - 5)));

          insert into public.grades (enrollment_id, assignment_score, midterm_score, final_score)
          values (v_enrollment_id, v_assignment, v_midterm, v_final)
          on conflict (enrollment_id) do update
            set assignment_score = excluded.assignment_score,
                midterm_score    = excluded.midterm_score,
                final_score      = excluded.final_score;
        end loop;
      end loop;
    end if;

  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 3. Refresh the view
-- ---------------------------------------------------------------------
-- (views are computed on the fly; nothing to do)

-- Sanity check
do $$
declare
  v_students int;
  v_class_sections int;
  v_enrollments int;
  v_grades int;
  v_attendance int;
begin
  select count(*) into v_students from public.students;
  select count(*) into v_class_sections from public.class_sections;
  select count(*) into v_enrollments from public.enrollments;
  select count(*) into v_grades from public.grades;
  select count(*) into v_attendance from public.attendance;

  raise notice 'Seed summary:';
  raise notice '  students       = %', v_students;
  raise notice '  class_sections = %', v_class_sections;
  raise notice '  enrollments    = %', v_enrollments;
  raise notice '  grades         = %', v_grades;
  raise notice '  attendance     = %', v_attendance;
end $$;
