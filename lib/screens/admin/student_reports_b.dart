import '../../presentation/admin/student_reports/b_certificate_report_screen.dart';
import '../../presentation/admin/student_reports/b_daywise_screen.dart';
import '../../presentation/admin/student_reports/b_health_report_screen.dart';
import '../../presentation/admin/student_reports/b_monthwise_screen.dart';
import '../../presentation/admin/student_reports/b_request_report_screen.dart';
import '../../presentation/admin/student_reports/b_yearly_screen.dart';
import '../screen_registry.dart';

/// Student Report menus, group B: attendance (daywise / monthwise / yearly), requests, health and certificates.
/// Keyed by the normalized menu link (lowercase, slashes stripped) like `roleMenuScreens`.
final Map<String, ScreenBuilder> studentReportsB = {
  'student/daywise_student_attendance': (a) => BDaywiseAttendanceScreen(args: a),
  'student/monthwise_student_attendance': (a) => BMonthwiseAttendanceScreen(args: a),
  'student/yearly_student_attendance': (a) => BYearlyAttendanceScreen(args: a),
  'student/report/student_request_report': (a) => BRequestReportScreen(args: a),
  'student/report/student_health_report': (a) => BHealthReportScreen(args: a),
  'student/student_certificate_report': (a) => BCertificateReportScreen(args: a),
};
