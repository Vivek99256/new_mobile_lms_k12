import '../screen_registry.dart';
import 'admission_list.dart';
import 'approve_leave.dart';
import 'capture_attendance.dart';
import 'capture_photos.dart';
import 'circular.dart';
import 'discipline.dart';
import 'fees_collect.dart';
import 'homework.dart';
import 'inward_outward.dart';
import 'leave_requests.dart';
import 'profiles.dart';
import 'send_message.dart';

/// Admin-only `screen_name` -> screen. Looked up before [teacherScreens] for admin users.
/// (The photo/video add form, `AdminAddPhotoVideoScreen`, is opened from the shared gallery.)
final Map<String, ScreenBuilder> adminScreens = {
  't_teacher_profile': (a) => TeacherProfileListScreen(args: a),
  't_student_profile': (a) => StudentProfileListScreen(args: a),
  't_own_profile': (a) => OwnProfileScreen(args: a),
  't_homework': (a) => AdminHomeworkScreen(args: a),
  't_circular': (a) => AdminCircularScreen(args: a),
  't_approve_leave': (a) => ApproveLeaveScreen(args: a),
  't_disclipline': (a) => DisciplineScreen(args: a),
  't_sms_parent': (a) => SendMessageScreen(args: a, kind: MessageKind.sms),
  't_notification_parent': (a) => SendMessageScreen(args: a, kind: MessageKind.notification),
  't_email_parent': (a) => SendMessageScreen(args: a, kind: MessageKind.email),
  't_enquiry': (a) => AdmissionListScreen(args: a, stage: AdmissionStage.enquiry),
  't_registration': (a) => AdmissionListScreen(args: a, stage: AdmissionStage.registration),
  't_confirmation': (a) => AdmissionListScreen(args: a, stage: AdmissionStage.confirmation),
  't_feescollect': (a) => FeesCollectScreen(args: a),
  't_leave_authorisation': (a) => LeaveRequestsScreen(args: a),
  't_inward': (a) => RegisterListScreen(args: a, kind: RegisterKind.inward),
  't_outward': (a) => RegisterListScreen(args: a, kind: RegisterKind.outward),
  't_capture_photos': (a) => CapturePhotosScreen(args: a),
  't_capture_attendance': (a) => CaptureAttendanceScreen(args: a, isAdmin: true),
};
