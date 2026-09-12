-- =====================================================================
-- Seed: 02_lecturers.sql
-- Purpose: 30 realistic Indonesian lecturers with NIDN and credentials.
-- =====================================================================

insert into public.lecturers (id, nidn, full_name, email, expertise) values
  -- Fakultas Ilmu Komputer
  ('33333333-3333-3333-3333-333333333301', '0001017501', 'Dr. Budi Santoso, S.Kom., M.Kom.',          'budi.santoso@uir.ac.id',  'Kecerdasan Buatan'),
  ('33333333-3333-3333-3333-333333333302', '0002027802', 'Siti Aminah, S.Kom., M.Cs.',                 'siti.aminah@uir.ac.id',   'Sistem Informasi'),
  ('33333333-3333-3333-3333-333333333303', '0003038103', 'Andi Wijaya, S.T., M.T.',                   'andi.wijaya@uir.ac.id',  'Jaringan Komputer'),
  ('33333333-3333-3333-3333-333333333304', '0004048204', 'Dewi Lestari, S.Kom., M.Kom.',              'dewi.lestari@uir.ac.id', 'Rekayasa Perangkat Lunak'),
  ('33333333-3333-3333-3333-333333333305', '0005058005', 'Rudi Hermawan, S.Kom., M.Sc.',              'rudi.hermawan@uir.ac.id','Basis Data'),
  ('33333333-3333-3333-3333-333333333306', '0006068306', 'Indah Permata, S.Kom., M.Kom.',             'indah.permata@uir.ac.id','Machine Learning'),
  ('33333333-3333-3333-3333-333333333307', '0007078407', 'Fajar Nugraha, S.T., M.Eng.',               'fajar.nugraha@uir.ac.id','Sistem Operasi'),
  ('33333333-3333-3333-3333-333333333308', '0008088508', 'Maya Sari, S.Kom., M.T.I.',                 'maya.sari@uir.ac.id',    'Pemrograman Web'),
  ('33333333-3333-3333-3333-333333333309', '0009098609', 'Hendra Gunawan, S.Kom., M.Kom.',            'hendra.gunawan@uir.ac.id','Data Mining'),
  ('33333333-3333-3333-3333-333333333310', '0010108710', 'Prof. Dr. Eko Prabowo, M.Cs.',              'eko.prabowo@uir.ac.id',  'Algoritma dan Pemrograman'),

  -- Fakultas Ekonomi dan Bisnis
  ('33333333-3333-3333-3333-333333333311', '0011117511', 'Dr. Hj. Sumarni, S.E., M.M.',                'sumarni@uir.ac.id',      'Manajemen Keuangan'),
  ('33333333-3333-3333-3333-333333333312', '0012127812', 'Wahyu Pratama, S.E., M.M.',                 'wahyu.pratama@uir.ac.id','Manajemen Pemasaran'),
  ('33333333-3333-3333-3333-333333333313', '0013138113', 'Sri Mulyani, S.E., M.Ak.',                  'sri.mulyani@uir.ac.id',  'Akuntansi Keuangan'),
  ('33333333-3333-3333-3333-333333333314', '0014148214', 'Ahmad Fauzi, S.E., M.M.',                   'ahmad.fauzi@uir.ac.id',  'Manajemen SDM'),
  ('33333333-3333-3333-3333-333333333315', '0015158315', 'Lina Marlina, S.E., M.Si.',                 'lina.marlina@uir.ac.id', 'Ekonomi Mikro'),
  ('33333333-3333-3333-3333-333333333316', '0016168416', 'Bambang Suryadi, S.E., M.M.',               'bambang.suryadi@uir.ac.id','Pajak'),

  -- Fakultas Teknik
  ('33333333-3333-3333-3333-333333333317', '0017178517', 'Dr. Ir. Joko Widodo, M.T.',                 'joko.widodo@uir.ac.id',  'Teknik Elektro'),
  ('33333333-3333-3333-3333-333333333318', '0018188618', 'Rina Astuti, S.T., M.T.',                   'rina.astuti@uir.ac.id',  'Sistem Tenaga'),
  ('33333333-3333-3333-3333-333333333319', '0019198719', 'Ir. Hartono, M.T.',                         'hartono@uir.ac.id',      'Teknik Mesin'),
  ('33333333-3333-3333-3333-333333333320', '0020208820', 'Yusuf Kurniawan, S.T., M.Eng.',             'yusuf.kurniawan@uir.ac.id','Manufaktur'),

  -- Fakultas MIPA
  ('33333333-3333-3333-3333-333333333321', '0021218921', 'Dr. Rina Susanti, M.Si.',                   'rina.susanti@uir.ac.id', 'Matematika'),
  ('33333333-3333-3333-3333-333333333322', '0022229022', 'Hadi Sutopo, S.Si., M.Si.',                 'hadi.sutopo@uir.ac.id',  'Statistika'),
  ('33333333-3333-3333-3333-333333333323', '0023239123', 'Nurul Hidayah, S.Si., M.Pd.',               'nurul.hidayah@uir.ac.id','Fisika'),
  ('33333333-3333-3333-3333-333333333324', '0024249224', 'Dr. Tono Sukarto, M.Si.',                   'tono.sukarto@uir.ac.id', 'Kimia'),

  -- Tambahan (pengampu mata kuliah dasar & umum)
  ('33333333-3333-3333-3333-333333333325', '0025259325', 'Dr. Endang Sulistyowati, M.Pd.',             'endang.sulistyowati@uir.ac.id','Bahasa Indonesia'),
  ('33333333-3333-3333-3333-333333333326', '0026269426', 'Agus Salim, S.Pd., M.Pd.',                  'agus.salim@uir.ac.id',   'Bahasa Inggris'),
  ('33333333-3333-3333-3333-333333333327', '0027279527', 'Dr. M. Yusuf, M.Ag.',                       'm.yusuf@uir.ac.id',      'Pendidikan Pancasila'),
  ('33333333-3333-3333-3333-333333333328', '0028289628', 'Dra. Hj. Khadijah, M.Pd.',                  'khadijah@uir.ac.id',     'Pendidikan Kewarganegaraan'),
  ('33333333-3333-3333-3333-333333333329', '0029299729', 'Drs. Suparman, M.M.',                       'suparman@uir.ac.id',     'Kewirausahaan'),
  ('33333333-3333-3333-3333-333333333330', '0030309830', 'Ir. Nurcholis, M.M.',                       'nurcholis@uir.ac.id',    'Etika Profesi')
on conflict (id) do nothing;
