/// Domain model for the `public.students` table + joined data from
/// `v_student_summary`.
class Student {
  final String id;
  final String? userId;
  final String nim;
  final String fullName;
  final String email;
  final String? gender;
  final DateTime? birthDate;
  final String? address;
  final String? phone;
  final String studyProgramId;
  final String studyProgramCode;
  final String studyProgramName;
  final String facultyId;
  final String facultyCode;
  final String facultyName;
  final int cohortYear;
  final int currentSemester;
  final double gpa;
  final int totalCredits;
  final String status;          // academic_status enum value
  final int totalCourses;
  final int coursesPassed;
  final int totalAttended;
  final int totalMeetings;

  const Student({
    required this.id,
    this.userId,
    required this.nim,
    required this.fullName,
    required this.email,
    this.gender,
    this.birthDate,
    this.address,
    this.phone,
    required this.studyProgramId,
    required this.studyProgramCode,
    required this.studyProgramName,
    required this.facultyId,
    required this.facultyCode,
    required this.facultyName,
    required this.cohortYear,
    required this.currentSemester,
    required this.gpa,
    required this.totalCredits,
    required this.status,
    this.totalCourses = 0,
    this.coursesPassed = 0,
    this.totalAttended = 0,
    this.totalMeetings = 0,
  });

  /// Human-readable attendance percentage.
  double get attendancePercent =>
      totalMeetings == 0 ? 0 : (totalAttended / totalMeetings) * 100;

  /// Pass rate across all enrolled courses.
  double get passRate =>
      totalCourses == 0 ? 0 : (coursesPassed / totalCourses) * 100;

  factory Student.fromViewJson(Map<String, dynamic> json) => Student(
        id: json['student_id'] as String,
        userId: null, // not joined in the view
        nim: json['nim'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        studyProgramId: json['program_id'] as String,
        studyProgramCode: json['program_code'] as String,
        studyProgramName: json['program_name'] as String,
        facultyId: json['faculty_id'] as String,
        facultyCode: json['faculty_code'] as String,
        facultyName: json['faculty_name'] as String,
        cohortYear: (json['cohort_year'] as num).toInt(),
        currentSemester: (json['current_semester'] as num).toInt(),
        gpa: (json['gpa'] as num).toDouble(),
        status: json['status'] as String,
        totalCourses: (json['total_courses'] as num?)?.toInt() ?? 0,
        coursesPassed: (json['courses_passed'] as num?)?.toInt() ?? 0,
        totalAttended: (json['total_attended'] as num?)?.toInt() ?? 0,
        totalMeetings: (json['total_meetings'] as num?)?.toInt() ?? 0,
      );
}

/// One row from `public.enrollments` joined with `public.courses`,
/// `public.class_sections`, `public.lecturers`, and `public.grades`.
class EnrolledCourse {
  final String enrollmentId;
  final String courseId;
  final String courseCode;
  final String courseName;
  final int credits;
  final int semester;
  final String sectionLabel;
  final String academicYear;
  final String lecturerName;
  final double? assignmentScore;
  final double? midtermScore;
  final double? finalScore;
  final double? finalNumeric;
  final String? letterGrade;

  const EnrolledCourse({
    required this.enrollmentId,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.credits,
    required this.semester,
    required this.sectionLabel,
    required this.academicYear,
    required this.lecturerName,
    this.assignmentScore,
    this.midtermScore,
    this.finalScore,
    this.finalNumeric,
    this.letterGrade,
  });

  /// Average score across the three components, or null if any missing.
  double? get averageScore {
    if (assignmentScore == null || midtermScore == null || finalScore == null) {
      return null;
    }
    return (assignmentScore! * 0.30) + (midtermScore! * 0.30) + (finalScore! * 0.40);
  }

  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    final course = json['courses'] as Map<String, dynamic>?;
    final cs = json['class_sections'] as Map<String, dynamic>?;
    final lecturer = cs?['lecturers'] as Map<String, dynamic>?;
    final grade = json['grades'] as Map<String, dynamic>?;
    return EnrolledCourse(
      enrollmentId: json['id'] as String,
      courseId: course?['id'] as String? ?? '',
      courseCode: course?['code'] as String? ?? '',
      courseName: course?['name'] as String? ?? '',
      credits: (course?['credits'] as num?)?.toInt() ?? 0,
      semester: (cs?['semester'] as num?)?.toInt() ?? 0,
      sectionLabel: cs?['section_label'] as String? ?? '',
      academicYear: cs?['academic_year'] as String? ?? '',
      lecturerName: lecturer?['full_name'] as String? ?? '-',
      assignmentScore: (grade?['assignment_score'] as num?)?.toDouble(),
      midtermScore: (grade?['midterm_score'] as num?)?.toDouble(),
      finalScore: (grade?['final_score'] as num?)?.toDouble(),
      finalNumeric: (grade?['final_numeric'] as num?)?.toDouble(),
      letterGrade: grade?['letter_grade'] as String?,
    );
  }
}

/// A weekly class meeting (from `public.schedules`).
class ClassSchedule {
  final String id;
  final String day;
  final String startTime;       // 'HH:mm'
  final String endTime;
  final String room;
  final String courseCode;
  final String courseName;
  final String lecturerName;

  const ClassSchedule({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.courseCode,
    required this.courseName,
    required this.lecturerName,
  });

  factory ClassSchedule.fromJson(Map<String, dynamic> json) {
    final cs = json['class_sections'] as Map<String, dynamic>?;
    final course = cs?['courses'] as Map<String, dynamic>?;
    final lecturer = cs?['lecturers'] as Map<String, dynamic>?;
    return ClassSchedule(
      id: json['id'] as String,
      day: json['day'] as String,
      startTime: (json['start_time'] as String).substring(0, 5),
      endTime: (json['end_time'] as String).substring(0, 5),
      room: json['room'] as String,
      courseCode: course?['code'] as String? ?? '',
      courseName: course?['name'] as String? ?? '',
      lecturerName: lecturer?['full_name'] as String? ?? '-',
    );
  }
}
