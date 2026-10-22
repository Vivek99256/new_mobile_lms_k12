import '../admin/capture_attendance.dart';
import '../admin/capture_photos.dart';
import '../screen_registry.dart';
import 'attendance_screens.dart';
import 'comm_screens.dart';
import 'gallery_screens.dart';
import 'hrms_screens.dart';
import 'homework_screens.dart';
import 'marks_screens.dart';
import 'office_screens.dart';
import 'profile_screens.dart';
import 'simple_lists.dart';
import 'teach_screens.dart';
import 'wrt_progress.dart';

/// Teacher `screen_name` -> screen. Admins fall back to these for the screens the two roles
/// share (those branch on the user's profile themselves).
final Map<String, ScreenBuilder> teacherScreens = {
  't_own_profile': (a) => OwnProfileScreen(args: a),
  't_message': (a) => TMessageScreen(args: a),
  't_proxy': (a) => ProxyScreen(args: a),
  't_teach': (a) => TeachScreen(args: a),
  't_virtual_classroom': (a) => VirtualClassroomScreen(args: a),
  't_teacher_resource': (a) => TeacherResourceScreen(args: a),
  't_teacher_dairy': (a) => LessonPlanningScreen(args: a),
  't_social_collobrative': (a) => SocialCollaborativeScreen(args: a),
  't_student_profile': (a) => StudentProfileListScreen(args: a),
  't_take_attendance': (a) => TakeAttendanceScreen(args: a),
  't_homework': (a) => HomeworkListScreen(args: a),
  't_circular': (a) => CircularListScreen(args: a),
  't_parent_comm': (a) => ParentCommScreen(args: a),
  't_approve_leave': (a) => ApproveLeaveScreen(args: a),
  't_disclipline': (a) => DisciplineScreen(args: a),
  't_marks': (a) => MarksSelectorScreen(args: a),
  't_sms_parent': (a) => ParentMessageScreen(args: a, kind: ParentMessageKind.sms),
  't_notification_parent': (a) => ParentMessageScreen(args: a, kind: ParentMessageKind.notification),
  't_email_parent': (a) => ParentMessageScreen(args: a, kind: ParentMessageKind.email),
  't_calander': (a) => CalendarScreen(args: a),
  't_timetable': (a) => TimetableScreen(args: a),
  't_photo_gallary': (a) => GalleryScreen(args: a),
  't_video_gallary': (a) => GalleryScreen(args: a, video: true),
  't_wrt_progress': (a) => WrtProgressScreen(args: a),
  't_notification_report': (a) => NotificationReportScreen(args: a),
  't_exam_schedule': (a) => ExamScheduleScreen(args: a),
  't_requisition': (a) => RequisitionScreen(args: a),
  't_task': (a) => TaskScreen(args: a),
  't_complain': (a) => ComplainScreen(args: a),
  't_visitor': (a) => VisitorScreen(args: a),
  't_punch_inout': (a) => PunchScreen(args: a),
  't_my_attendance': (a) => MyAttendanceScreen(args: a),
  't_my_leave': (a) => MyLeaveScreen(args: a),
  // Aliases: the old app's route-style names, in case a feed uses them.
  'time_table': (a) => TimetableScreen(args: a),
  'take_attendance': (a) => TakeAttendanceScreen(args: a),
  'punch_in_out': (a) => PunchScreen(args: a),
  'my_leave': (a) => MyLeaveScreen(args: a),
  'my_attendance': (a) => MyAttendanceScreen(args: a),
  'reply_parent_communication': (a) => ParentCommScreen(args: a),
  'task': (a) => TaskScreen(args: a),
  'gallary': (a) => GalleryScreen(args: a),
  // Teachers reuse the admin capture screens (registered last, they live in lib/screens/admin).
  't_capture_photos': (a) => CapturePhotosScreen(args: a),
  't_capture_attendance': (a) => CaptureAttendanceScreen(args: a, isAdmin: false),
};
