import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/data/model/student.dart';
import 'package:cause_money_record/presentation/controller/c_student.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

/// Student academic dashboard — shows profile, IPK, current semester
/// courses with grades, and weekly class schedule.
class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  final c = Get.put(CStudent());

  @override
  void initState() {
    super.initState();
    c.loadAll();
  }

  Future<void> _refresh() => c.loadAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: AppColor.card,
        foregroundColor: AppColor.textPrimary,
        elevation: 0,
        title: const Text('Akademik', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh, color: AppColor.accent,
        child: Obx(() {
          if (c.loading && c.student == null) {
            return const StateView(
              loading: true, error: null, empty: false, child: SizedBox.shrink(),
            );
          }
          if (c.error != null && c.student == null) {
            return StateView(
              loading: false, error: c.error, empty: false, onRetry: _refresh, child: const SizedBox.shrink(),
              emptyTitle: 'Tidak ada data',
            );
          }
          if (c.student == null) {
            return StateView(
              loading: false, error: null, empty: true, onRetry: _refresh, child: const SizedBox.shrink(),
              emptyTitle: 'Akun belum terhubung',
              emptyMessage: 'Akun ini belum terhubung ke data mahasiswa. Hubungi admin untuk menghubungkan akun Anda.',
              emptyIcon: Icons.school_outlined,
            );
          }
          return _body(c.student!);
        }),
      ),
    );
  }

  Widget _body(Student s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _profileCard(s),
        const SizedBox(height: 20),
        _statsRow(s),
        const SizedBox(height: 24),
        _sectionTitle('Mata Kuliah Semester ${s.currentSemester}'),
        const SizedBox(height: 8),
        _coursesSection(),
        const SizedBox(height: 24),
        _sectionTitle('Jadwal Kelas'),
        const SizedBox(height: 8),
        _scheduleSection(),
      ],
    );
  }

  Widget _profileCard(Student s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColor.primary, Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColor.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _initials(s.fullName),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.fullName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${s.nim} • ${s.facultyCode} - ${s.studyProgramCode}',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
          ])),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _chip('${s.studyProgramName}', Icons.school_outlined),
          const SizedBox(width: 8),
          _chip('Angkatan ${s.cohortYear}', Icons.calendar_today_outlined),
        ]),
      ]),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _statsRow(Student s) {
    return Row(children: [
      _statTile('IPK', s.gpa.toStringAsFixed(2), Icons.school, AppColor.accent,
          accentBg: AppColor.accent),
      const SizedBox(width: 12),
      _statTile('Semester', '${s.currentSemester}', Icons.layers_outlined, AppColor.primary,
          accentBg: AppColor.primary),
      const SizedBox(width: 12),
      _statTile('Status', _statusLabel(s.status), Icons.verified_outlined, _statusColor(s.status),
          accentBg: _statusColor(s.status)),
    ]);
  }

  Widget _statTile(String label, String value, IconData icon, Color color, {required Color accentBg}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColor.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColor.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: accentBg.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColor.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColor.textSecondary, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColor.textPrimary));
  }

  Widget _coursesSection() {
    return Obx(() {
      if (c.currentEnrollments.isEmpty) {
        return const StateView(
          loading: false, error: null, empty: true, child: SizedBox.shrink(),
          emptyTitle: 'Belum ada KRS',
          emptyMessage: 'Anda belum mengambil mata kuliah semester ini',
          emptyIcon: Icons.book_outlined,
        );
      }
      return Column(
        children: c.currentEnrollments.map((e) => _courseCard(e)).toList(),
      );
    });
  }

  Widget _courseCard(EnrolledCourse e) {
    final letterColor = _letterColor(e.letterGrade);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColor.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.courseName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColor.textPrimary)),
            const SizedBox(height: 2),
            Text('${e.courseCode} • ${e.credits} SKS • Kelas ${e.sectionLabel}',
              style: const TextStyle(fontSize: 11, color: AppColor.textSecondary)),
          ])),
          if (e.letterGrade != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: letterColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: letterColor.withOpacity(0.3)),
              ),
              child: Text(e.letterGrade!,
                style: TextStyle(color: letterColor, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.person_outline, size: 12, color: AppColor.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              e.lecturerName,
              style: const TextStyle(fontSize: 11, color: AppColor.textSecondary, fontStyle: FontStyle.italic),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _gradeBlock('Tugas', e.assignmentScore),
          const SizedBox(width: 8),
          _gradeBlock('UTS', e.midtermScore),
          const SizedBox(width: 8),
          _gradeBlock('UAS', e.finalScore),
        ]),
        if (e.averageScore != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColor.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Text('Nilai Akhir', style: TextStyle(fontSize: 11, color: AppColor.textSecondary)),
              const Spacer(),
              Text(
                '${e.averageScore!.toStringAsFixed(2)}  •  ${e.finalNumeric?.toStringAsFixed(2) ?? '-'} / 4.00',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: letterColor,
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _gradeBlock(String label, double? value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColor.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColor.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value == null ? '-' : value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColor.textPrimary),
          ),
        ]),
      ),
    );
  }

  Widget _scheduleSection() {
    return Obx(() {
      if (c.schedules.isEmpty) {
        return const StateView(
          loading: false, error: null, empty: true, child: SizedBox.shrink(),
          emptyTitle: 'Tidak ada jadwal',
          emptyMessage: 'Jadwal kelas belum tersedia untuk minggu ini',
          emptyIcon: Icons.calendar_today_outlined,
        );
      }
      // Group by day
      final byDay = <String, List<ClassSchedule>>{};
      for (final s in c.schedules) {
        byDay.putIfAbsent(s.day, () => []).add(s);
      }
      // Sort by start time within each day
      for (final list in byDay.values) {
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
      // Order days Monday -> Sunday
      const dayOrder = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
      final dayLabels = {
        'monday': 'Senin', 'tuesday': 'Selasa', 'wednesday': 'Rabu',
        'thursday': 'Kamis', 'friday': 'Jumat', 'saturday': 'Sabtu', 'sunday': 'Minggu',
      };

      return Column(
        children: dayOrder
            .where((d) => byDay.containsKey(d))
            .map((d) => _dayBlock(dayLabels[d]!, byDay[d]!))
            .toList(),
      );
    });
  }

  Widget _dayBlock(String dayLabel, List<ClassSchedule> schedules) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColor.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dayLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColor.textPrimary)),
        const SizedBox(height: 10),
        ...schedules.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 70,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColor.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(children: [
                    Text(s.startTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColor.accent)),
                    Text(s.endTime, style: const TextStyle(fontSize: 10, color: AppColor.textSecondary)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.courseName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColor.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${s.courseCode} • ${s.lecturerName}',
                    style: const TextStyle(fontSize: 11, color: AppColor.textSecondary)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 11, color: AppColor.textSecondary),
                    const SizedBox(width: 3),
                    Text(s.room, style: const TextStyle(fontSize: 11, color: AppColor.textSecondary)),
                  ]),
                ])),
              ]),
            )),
      ]),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active': return 'Aktif';
      case 'on_leave': return 'Cuti';
      case 'probation': return 'Peringatan';
      case 'graduated': return 'Lulus';
      case 'dropped_out': return 'DO';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return AppColor.income;
      case 'on_leave': return Colors.orange;
      case 'probation': return AppColor.danger;
      case 'graduated': return AppColor.accent;
      case 'dropped_out': return Colors.grey;
      default: return AppColor.textSecondary;
    }
  }

  Color _letterColor(String? letter) {
    switch (letter) {
      case 'A': return AppColor.income;
      case 'B': return AppColor.accent;
      case 'C': return Colors.orange;
      case 'D': return Colors.deepOrange;
      case 'E': return AppColor.danger;
      default: return AppColor.textSecondary;
    }
  }
}
