# Teacher screens: porting notes

Source: d:/scholarclone (read-only). Nothing here was verified against the live server; every request field name and endpoint is copied from the old code or the catalogue.

## Registered screen_names -> file (all under lib/screens/teacher/)

| screen_name | screen | file |
|---|---|---|
| t_own_profile | OwnProfileScreen (from login data, no API) | profile_screens.dart |
| t_student_profile | StudentProfileListScreen + detail | profile_screens.dart |
| t_message | TMessageScreen (calls teacherAnnoucementAPI, renders `data` if any) | simple_lists.dart |
| t_proxy | ProxyScreen (shared with admin) | simple_lists.dart |
| t_virtual_classroom | VirtualClassroomScreen | simple_lists.dart |
| t_teacher_resource | TeacherResourceScreen | simple_lists.dart |
| t_social_collobrative | SocialCollaborativeScreen | simple_lists.dart |
| t_notification_report | NotificationReportScreen | simple_lists.dart |
| t_calander | CalendarScreen | simple_lists.dart |
| t_timetable, time_table | TimetableScreen | simple_lists.dart |
| t_teach | TeachScreen -> ChapterListScreen -> ChapterDetailScreen -> VideoScreen | teach_screens.dart |
| t_teacher_dairy | LessonPlanningScreen | attendance_screens.dart |
| t_take_attendance, take_attendance | TakeAttendanceScreen | attendance_screens.dart |
| t_homework | HomeworkListScreen + AssignHomeworkScreen | homework_screens.dart |
| t_circular | CircularListScreen + AddCircularScreen | homework_screens.dart |
| t_exam_schedule | ExamScheduleScreen + AddExamScreen | homework_screens.dart |
| t_parent_comm, reply_parent_communication | ParentCommScreen (shared) | comm_screens.dart |
| t_approve_leave | ApproveLeaveScreen | comm_screens.dart |
| t_disclipline | DisciplineScreen | comm_screens.dart |
| t_sms_parent, t_notification_parent, t_email_parent | ParentMessageScreen(kind) | comm_screens.dart |
| t_marks | MarksSelectorScreen + MarksEntryScreen | marks_screens.dart |
| t_photo_gallary, t_video_gallary, gallary | GalleryScreen, PhotosScreen, ZoomPhotoScreen, AddPhotoVideoScreen | gallery_screens.dart |
| t_wrt_progress | WrtProgressScreen (shared) | wrt_progress.dart |
| t_requisition | RequisitionScreen + AddRequisitionScreen (shared) | office_screens.dart |
| t_task, task | TaskScreen + AddAllocationScreen (shared) | office_screens.dart |
| t_complain | ComplainScreen + AddAllocationScreen (shared) | office_screens.dart |
| t_visitor | VisitorScreen + AddVisitorScreen (shared) | office_screens.dart |
| t_punch_inout, punch_in_out | PunchScreen | hrms_screens.dart |
| t_my_attendance, my_attendance | MyAttendanceScreen | hrms_screens.dart |
| t_my_leave, my_leave | MyLeaveScreen + ApplyLeaveScreen + LeaveHistoryScreen | hrms_screens.dart |
| t_capture_photos | CapturePhotosScreen(args) from lib/screens/admin | teacher_screens.dart |
| t_capture_attendance | CaptureAttendanceScreen(args, isAdmin: false) from lib/screens/admin | teacher_screens.dart |

Shared helpers: tk.dart (ClassPicker, loadStudents, StudentTile, StudentChecklist, BusyMixin, ListPage, RangeListPage, date helpers). The registry is teacher_screens.dart.

## Role branching

`isAdmin(args)` in tk.dart is true for every profile that is not `teacher` (Admin, Principal, Trustee...), because those use the admin endpoints in the old app. The catalogue says `== 'admin'`; this is a deliberate widening.

Branches: proxy, WRT student list, requisition list, task list/add, complaint list/add, visitor list, parent communication list/save, gallery list (and no standard_id), discipline/other forms via ClassPicker (admin uses Section > Standard > Division with the admin endpoints, teacher uses the timetable-based endpoints). Every request also carries `teacher_id = user_id` and `admin_id = user_id` from `LegacyApi.identity`.

## Intentional changes from the old behaviour

- **Class selection**: the old `standard_division` / `standard_division_title` / `term_data` login fields do not exist in the new login. Screens that used STD_DIV_TOKENS or `standard_division.split("||")` now use `ClassPicker`: Standard (get_teacher_timetablewiseStandard) > Division (get_teacher_timetablewiseDivision) [> Subject]. A teacher with no timetable entries sees "No classes are linked to your timetable yet." Multi-class teachers work for every screen.
- Take attendance posts `standard_division` = `"<std>||<div>"` of the chosen class (old code posted the teacher's whole raw string). Unmarked students are sent as an empty string, as before.
- Lesson planning posts the standard **id** (old code posted the standard name).
- Marks: terms come from `session.raw['term_data']` if present, otherwise `GET /lms_data?table=academic_year` filtered by institute and year. `subject_id` is the selected subject (old: hard-coded 3975). `grade_id` comes from the timetable standard row. Percentage uses the exam's max `points` (old: /20). Only students with an entered value are sent (old: everyone, unentered as 0.0, which would overwrite existing marks); `AB`/`EX`/`N.A.` are accepted. The exam id sent is the exam row `id`.
- Discipline `data` is built with `jsonEncode` instead of string concatenation.
- t_teach: standard picker + subject cards; `get_teacherContentAPI` is sent as multipart form fields like every other call (old: a JSON string body). In-app WebView is not used: links/PDF/images open externally; video content plays in an in-app `video_player` screen.
- Teacher timetable: Thursday maps to `H` correctly; Sunday shows no lectures.
- Gallery: Photos/Videos toggle added (old: video tab unreachable, YouTube thumbnail from `?v=`). Select-and-share downloads each image to the temp folder and uses the share sheet; "download" opens the URL externally (no path_provider/storage permission needed).
- Add photos: uses `image_picker` multi-select (jpg/png from the gallery); videos are still only a YouTube link. Both roles use this form (the admin agent's own add form is separate).
- Punch in/out: GPS coordinates string as address (no reverse geocoding), front camera selfie, permission checks with messages. Debug hard-coded user id removed.
- Requisition add: item list is requested from the configured host (`/get_adminItemListAPI`), not `http://dev.triz.co.in`. `created_ip_address` IS sent: the server validator requires it (teacherapiController `add_teacherRequisitionAPI`), so the app sends the device's local IPv4 address (no third-party lookup; `0.0.0.0` when none is found).
- Leave apply: validates leave type, day type, slot and dates, and only closes on success (old: always closed).
- Leave gauge uses used/total (old: fixed 25%).
- Statuses are read with `LegacyApi.ok` (status or status_code). Dates are posted as `yyyy-MM-dd 00:00:00.000` (what the old Dart `DateTime.toString()` produced for picked dates).
- Add forms and lists reload after returning (old: only the gallery did).
- Student SMS recipients are keyed by student id: `mobile_number[<student id>]` (old docs keyed by enrollment number in the UI only; the posted key was the student id).

## Not ported / partly ported

- In-app WebView page for non-YouTube `link` content (no webview package): opens externally.
- Moodle-style file-type icons from `202.47.117.131` replaced by Material icons.
- Home/drawer/login/share/logout: owned by the app shell, not this package.
- `t_marks` Term shows the title; "Term : id" header shows the name instead.
- `t_message` has no known response shape; it renders `title`/`message`/`description`/`created_at` if the endpoint returns rows.
- Capture photos/attendance live in lib/screens/admin (other agent); teacher just routes to them. Their step-2 contract (`get_attendanceDataAPI` sample JSON) is unresolved in the source and is not handled here.

## Assumptions to verify against the real API

1. `get_teacher_timetablewiseStandard/Division/Subject` accept the identity fields the shell adds (token, teacher_id = user_id, syear, sub_institute_id) and return `std_id/std_name/grade_id`, `div_id/div_name`, `sub_id/sub_name`.
2. The server accepts `get_teacherContentAPI` as multipart form-data (old app sent JSON).
3. `/student/save_student_attendance` accepts `standard_division` = the single chosen `std||div` token.
4. Term list: now `GET /api/academic-terms` first (see docs/api-migration-staff.md); `/lms_data?table=academic_year` (unauthenticated, returns `data[]`) is only the fallback.
5. `/hrms-inout-time` returns the status at top level (no `status` key); we read `hrms_attendance`, `button`, `button_disable`.
6. `exam_id` sent to `/result/marks_entry` should be the `result_create_exam.id` returned by `get_teacherResultExamList`.
7. (Corrected) `/add_teacherRequisitionAPI` REQUIRES `created_ip_address`; the code sends it. Omitting it makes the validator fail and the response has no `status`.
8. For non-teacher staff (Principal/Trustee) the admin endpoints listed above accept the shell identity; screens that have no admin variant (calendar, timetable, take attendance, punch, leave, exam schedule, message) were only ever guaranteed to work for admins if `teacher_id = user_id` is accepted server-side (the shell already sends it).
9. Gallery `data` may be a map `album -> items` or a flat list; both are handled.

## Tests

`test/teacher_screens_test.dart`: 11 tests (registry, proxy teacher vs admin endpoint, error + retry, add-task submit and validation, attendance mark-all and single-absent submit, leave approval, timetable weekday mapping, HRMS attendance query). Run with `flutter test test/teacher_screens_test.dart`.

## API migration (staff)

Parent SMS/notification/email, notification report, term list, leave balance, leave apply/history, and discipline now call the newer endpoints first. See `docs/api-migration-staff.md` for the table, mappings and fallback rules. Tests for these are in the `api migration (teacher)` group of `test/teacher_screens_test.dart`.
