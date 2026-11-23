import '../../presentation/admin/student_reports/age_wise_report.dart';
import '../../presentation/admin/student_reports/missing_documents_report.dart';
import '../../presentation/admin/student_reports/strength_report.dart';
import '../../presentation/admin/student_reports/student_dynamic_report.dart';
import '../screen_registry.dart';

/// Native screens for the Student ▸ Reports menus (group A). Keyed by the normalised menu link
/// (lower case, slashes stripped), the way `roleMenuScreens` is.
final Map<String, ScreenBuilder> studentReportsA = {
  'student/report/student_report': (a) => StudentDynamicReportScreen(args: a, inactive: false),
  'student/report/inactive_student_report': (a) => StudentDynamicReportScreen(args: a, inactive: true),
  'student/report/agewise_report': (a) => AgeWiseReportScreen(args: a),
  'student_strength_report.index': (a) => StrengthReportScreen(args: a),
  'student/report/missing_document_report': (a) => MissingDocumentsReportScreen(args: a),
};
