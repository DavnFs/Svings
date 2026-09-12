import 'package:get/get.dart';
import 'package:cause_money_record/data/model/student.dart';
import 'package:cause_money_record/data/source/source_student.dart';

/// Controller for the student academic dashboard.
class CStudent extends GetxController {
  final _loading = false.obs;
  bool get loading => _loading.value;

  final _error = RxnString();
  String? get error => _error.value;

  final _student = Rxn<Student>();
  Student? get student => _student.value;

  final _currentEnrollments = <EnrolledCourse>[].obs;
  List<EnrolledCourse> get currentEnrollments => _currentEnrollments;

  final _schedules = <ClassSchedule>[].obs;
  List<ClassSchedule> get schedules => _schedules;

  /// Pull everything for the signed-in student in parallel.
  Future<void> loadAll() async {
    _loading.value = true;
    _error.value = null;
    try {
      final s = await SourceStudent.getCurrentStudent();
      if (s == null) {
        _error.value = 'Akun ini belum terhubung ke data mahasiswa';
        _student.value = null;
        return;
      }
      _student.value = s;

      // Run two follow-ups in parallel
      final results = await Future.wait([
        SourceStudent.getEnrollmentsBySemester(s.id, s.currentSemester),
        SourceStudent.getSchedules(s.id),
      ]);
      _currentEnrollments.assignAll(results[0] as List<EnrolledCourse>);
      _schedules.assignAll(results[1] as List<ClassSchedule>);
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _loading.value = false;
    }
  }
}
