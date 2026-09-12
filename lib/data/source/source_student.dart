import 'package:cause_money_record/config/supabase_config.dart';
import 'package:cause_money_record/data/model/student.dart';

/// Repository for student academic data.
///
/// All methods return empty / null on failure so the UI can render
/// empty/error states without try/catch noise in every screen.
class SourceStudent {
  static get _client => SupabaseConfig.client;

  /// Fetch the student record linked to the currently signed-in user.
  static Future<Student?> getCurrentStudent() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return null;
    try {
      final resp = await _client
          .from('v_student_summary')
          .select()
          .eq('email', SupabaseConfig.currentUserEmail ?? '')
          .maybeSingle();
      if (resp == null) return null;
      return Student.fromViewJson(resp);
    } catch (_) {
      return null;
    }
  }

  /// List all enrollments for a student (with course + grade + lecturer).
  static Future<List<EnrolledCourse>> getEnrollments(String studentId) async {
    try {
      final resp = await _client
          .from('enrollments')
          .select('''
            id,
            class_sections (
              id, semester, section_label, academic_year,
              courses ( id, code, name, credits ),
              lecturers ( id, full_name )
            ),
            grades ( assignment_score, midterm_score, final_score, final_numeric, letter_grade )
          ''')
          .eq('student_id', studentId);
      return (resp as List)
          .map((e) => EnrolledCourse.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// List enrollments for a specific semester.
  static Future<List<EnrolledCourse>> getEnrollmentsBySemester(
    String studentId,
    int semester,
  ) async {
    final all = await getEnrollments(studentId);
    return all.where((e) => e.semester == semester).toList();
  }

  /// Weekly schedules for a student (joins through enrollments).
  static Future<List<ClassSchedule>> getSchedules(String studentId) async {
    try {
      // First get the class section ids the student is enrolled in
      final enrollments = await _client
          .from('enrollments')
          .select('class_section_id')
          .eq('student_id', studentId);

      final sectionIds = (enrollments as List)
          .map((e) => (e as Map)['class_section_id'] as String)
          .toList();

      if (sectionIds.isEmpty) return [];

      final resp = await _client
          .from('schedules')
          .select('''
            id, day, start_time, end_time, room,
            class_sections (
              id,
              courses ( id, code, name ),
              lecturers ( id, full_name )
            )
          ''')
          .inFilter('class_section_id', sectionIds);

      return (resp as List)
          .map((e) => ClassSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
