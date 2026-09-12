-- =====================================================================
-- Seed: 01_faculties_programs.sql
-- Purpose: Idempotent reference data for faculties and study programs.
-- =====================================================================

insert into public.faculties (id, code, name, description) values
  ('11111111-1111-1111-1111-111111111101', 'FKOM', 'Fakultas Ilmu Komputer', 'Fakultas yang menyelenggarakan program studi di bidang komputer, sistem informasi, dan teknologi informasi.'),
  ('11111111-1111-1111-1111-111111111102', 'FEKON', 'Fakultas Ekonomi dan Bisnis', 'Fakultas yang menyelenggarakan program studi di bidang ekonomi, manajemen, akuntansi, dan kewirausahaan.'),
  ('11111111-1111-1111-1111-111111111103', 'FT',   'Fakultas Teknik', 'Fakultas yang menyelenggarakan program studi di bidang teknik elektro, mesin, sipil, dan industri.'),
  ('11111111-1111-1111-1111-111111111104', 'FMIPA','Fakultas Matematika dan Ilmu Pengetahuan Alam', 'Fakultas yang menyelenggarakan program studi di bidang matematika, fisika, kimia, dan statistika.')
on conflict (id) do nothing;

insert into public.study_programs (id, faculty_id, code, name, degree, accreditation) values
  -- Fakultas Ilmu Komputer
  ('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111101', 'IF',  'Teknik Informatika',          'S1', 'Unggul'),
  ('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111101', 'SI',  'Sistem Informasi',            'S1', 'Unggul'),
  ('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111101', 'TI',  'Teknologi Informasi',         'S1', 'Baik Sekali'),

  -- Fakultas Ekonomi dan Bisnis
  ('22222222-2222-2222-2222-222222222204', '11111111-1111-1111-1111-111111111102', 'MJ',  'Manajemen',                   'S1', 'Unggul'),
  ('22222222-2222-2222-2222-222222222205', '11111111-1111-1111-1111-111111111102', 'AK',  'Akuntansi',                   'S1', 'Unggul'),
  ('22222222-2222-2222-2222-222222222206', '11111111-1111-1111-1111-111111111102', 'EK',  'Ilmu Ekonomi',                'S1', 'Baik Sekali'),

  -- Fakultas Teknik
  ('22222222-2222-2222-2222-222222222207', '11111111-1111-1111-1111-111111111103', 'TE',  'Teknik Elektro',              'S1', 'Unggul'),
  ('22222222-2222-2222-2222-222222222208', '11111111-1111-1111-1111-111111111103', 'TM',  'Teknik Mesin',                'S1', 'Baik Sekali'),

  -- Fakultas MIPA
  ('22222222-2222-2222-2222-222222222209', '11111111-1111-1111-1111-111111111104', 'MT',  'Matematika',                  'S1', 'Unggul'),
  ('22222222-2222-2222-2222-222222222210', '11111111-1111-1111-1111-111111111104', 'ST',  'Statistika',                  'S1', 'Baik Sekali')
on conflict (id) do nothing;
