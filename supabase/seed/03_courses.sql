-- =====================================================================
-- Seed: 03_courses.sql
-- Purpose: 30 realistic Indonesian university courses.
-- =====================================================================

insert into public.courses (id, code, name, credits, semester_target, description) values
  -- Semester 1-2 (dasar)
  ('44444444-4444-4444-4444-444444444401', 'UNI101', 'Bahasa Indonesia',                   2,  1,  'Bahasa Indonesia untuk perguruan tinggi.'),
  ('44444444-4444-4444-4444-444444444402', 'UNI102', 'Bahasa Inggris',                     2,  1,  'English for academic purposes.'),
  ('44444444-4444-4444-4444-444444444403', 'UNI103', 'Pendidikan Pancasila',               2,  1,  'Pancasila dan kewarganegaraan.'),
  ('44444444-4444-4444-4444-444444444404', 'UNI104', 'Pendidikan Kewarganegaraan',         2,  2,  'Kewarganegaraan dan bela negara.'),
  ('44444444-4444-4444-4444-444444444405', 'MAT101', 'Kalkulus I',                         3,  1,  'Diferensial, integral, dan aplikasi.'),
  ('44444444-4444-4444-4444-444444444406', 'MAT102', 'Kalkulus II',                        3,  2,  'Multivariat, deret, dan vektor.'),
  ('44444444-4444-4444-4444-444444444407', 'MAT201', 'Matematika Diskrit',                 3,  3,  'Logika, himpunan, graf, kombinatorika.'),
  ('44444444-4444-4444-4444-444444444408', 'MAT202', 'Aljabar Linear',                     3,  2,  'Vektor, matriks, transformasi linear.'),
  ('44444444-4444-4444-4444-444444444409', 'MAT301', 'Statistika dan Probabilitas',        3,  4,  'Distribusi, uji hipotesis, regresi.'),

  -- Semester 1-4 (ilmu komputer)
  ('44444444-4444-4444-4444-444444444410', 'IF101',  'Algoritma dan Pemrograman',           4,  1,  'Konsep algoritma dan pemrograman dasar (Pascal/Python).'),
  ('44444444-4444-4444-4444-444444444411', 'IF102',  'Struktur Data',                       4,  2,  'List, stack, queue, tree, graph.'),
  ('44444444-4444-4444-4444-444444444412', 'IF201',  'Pemrograman Berorientasi Objek',      4,  3,  'Konsep OOP dengan Java/Python.'),
  ('44444444-4444-4444-4444-444444444413', 'IF202',  'Basis Data',                          4,  3,  'Relational DB, SQL, normalisasi.'),
  ('44444444-4444-4444-4444-444444444414', 'IF203',  'Sistem Operasi',                      3,  4,  'Proses, thread, memory, file system.'),
  ('44444444-4444-4444-4444-444444444415', 'IF204',  'Jaringan Komputer',                   3,  4,  'OSI/TCP-IP, routing, switching.'),
  ('44444444-4444-4444-4444-444444444416', 'IF301',  'Pemrograman Web',                     4,  4,  'HTML, CSS, JavaScript, framework.'),
  ('44444444-4444-4444-4444-444444444417', 'IF302',  'Rekayasa Perangkat Lunak',            3,  5,  'SDLC, requirement, design pattern.'),
  ('44444444-4444-4444-4444-444444444418', 'IF303',  'Kecerdasan Buatan',                   3,  5,  'Search, knowledge, expert system.'),
  ('44444444-4444-4444-4444-444444444419', 'IF304',  'Machine Learning',                    3,  6,  'Supervised, unsupervised, deep learning.'),
  ('44444444-4444-4444-4444-444444444420', 'IF305',  'Keamanan Informasi',                  3,  6,  'Kriptografi, security policy, OWASP.'),
  ('44444444-4444-4444-4444-444444444421', 'IF306',  'Data Mining',                         3,  6,  'Preprocessing, clustering, klasifikasi.'),
  ('44444444-4444-4444-4444-444444444422', 'IF401',  'Skripsi',                             6,  8,  'Tugas akhir penelitian terapan.'),

  -- Sistem Informasi
  ('44444444-4444-4444-4444-444444444423', 'SI201',  'Analisis dan Perancangan Sistem',     3,  4,  'Analisis kebutuhan, DFD, ERD.'),
  ('44444444-4444-4444-4444-444444444424', 'SI301',  'Manajemen Proyek TI',                 3,  5,  'PMBOK, scrum, agile estimation.'),

  -- Ekonomi & Manajemen
  ('44444444-4444-4444-4444-444444444425', 'EK101',  'Pengantar Ekonomi Mikro',             3,  1,  'Teori konsumen, produsen, pasar.'),
  ('44444444-4444-4444-4444-444444444426', 'MJ201',  'Manajemen Keuangan',                  3,  3,  'CAPM, capital budgeting, dividend.'),
  ('44444444-4444-4444-4444-444444444427', 'MJ202',  'Manajemen Pemasaran',                 3,  4,  'Bauran pemasaran, STP, perilaku konsumen.'),
  ('44444444-4444-4444-4444-444444444428', 'AK201',  'Akuntansi Keuangan Dasar',            3,  2,  'Persamaan dasar akuntansi, jurnal, laporan.'),

  -- Kewirausahaan / Etika (umum)
  ('44444444-4444-4444-4444-444444444429', 'UNI201', 'Kewirausahaan',                       2,  5,  'Mindset, business model, lean startup.'),
  ('44444444-4444-4444-4444-444444444430', 'UNI202', 'Etika Profesi',                       2,  6,  'Etika IT, kode etik, tanggung jawab profesional.')
on conflict (id) do nothing;
