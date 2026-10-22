import '../screen_registry.dart';
import 'calendars.dart';
import 'communication.dart';
import 'fees.dart';
import 'gallery.dart';
import 'info.dart';
import 'leave.dart';
import 'lists_a.dart';
import 'lms.dart';
import 'records.dart';
import 'tabbed.dart';

/// Student `screen_name` -> screen. Ported from the old app (see docs/porting-notes-student.md).
final Map<String, ScreenBuilder> studentScreens = {
  // Learning
  'lms_subject': learnScreen,
  'lms_pal': palScreen,
  'virtual_classroom': virtualClassroomScreen,
  'social_collabrative': socialCollaborativeScreen,
  'leaderboard': leaderboardScreen,
  'portfolio': (a) => PortfolioScreen(args: a),
  // Academics
  'assignment': homeworkScreen,
  'home_work': homeworkScreen,
  'time_table': (a) => TimetableScreen(args: a),
  'exam_schedule': examScheduleScreen,
  'result_pdf': (a) => ResultPdfScreen(args: a),
  'wrt_progress': (a) => WrtProgressScreen(args: a),
  'classwork_gallery': (a) => ClassworkScreen(args: a),
  'subjects': teacherListScreen,
  // Attendance and calendar
  'student_attendance': (a) => AttendanceScreen(args: a),
  'academic_calendar': (a) => AcademicCalendarScreen(args: a),
  'holiday_list': holidayListScreen,
  'leave_application': (a) => LeaveScreen(args: a),
  'capture_photos': (a) => FaceAttendanceScreen(args: a),
  // Communication
  'notification_hub': notificationHubScreen,
  'circular_events': circularEventsScreen,
  'parent_communication': (a) => ParentCommunicationScreen(args: a),
  'child_remark': disciplineScreen,
  // Fees, certificates and records
  'fees': (a) => FeesScreen(args: a),
  'student_certificate': certificateListScreen,
  'achievement_certificate': achievementCertificateScreen,
  'health_details': healthDetailsScreen,
  'height_weight': heightWeightScreen,
  'student_infirmary': infirmaryScreen,
  'student_vaccination': vaccinationScreen,
  'student_transport': transportScreen,
  'student_hostel': hostelScreen,
  'student_consent': consentScreen,
  // Galleries
  'photos_gallery': (a) => AlbumsScreen(args: a, video: false),
  'video_gallery': (a) => AlbumsScreen(args: a, video: true),
  // School information
  'about_us': (a) => schoolInfoScreen(a, action: 'About Us', fixedTitle: 'About us', fixedUrl: true),
  'principal_desk': (a) => schoolInfoScreen(a, action: 'Principal Desk', principal: true),
  'school_information': (a) => schoolInfoScreen(a, action: 'School Information', fixedTitle: 'School information'),
  'achievement': (a) => schoolInfoScreen(a, action: 'Achievement'),
  'school_timing': (a) => schoolInfoScreen(a, action: 'School Timing'),
  'rules': (a) => schoolInfoScreen(a, action: 'Rules'),
  'facility': (a) => schoolInfoScreen(a, action: 'Facility'),
  'acadamic_activity': (a) => schoolInfoScreen(a, action: 'Academic Activity'),
  'academic_activity': (a) => schoolInfoScreen(a, action: 'Academic Activity'),
  'reach_us': (a) => schoolInfoScreen(a, action: 'Reach Us'),
};
