# Student screens: porting notes

Source: `d:/scholarclone` (GetX). Target: `lib/screens/student/`. 45 `screen_name` keys are registered in `student_screens.dart`. Nothing here has been run against the live server; only mocked-HTTP widget tests (`test/student_screens_test.dart`).

## screen_name -> file

| screen_name | file |
|---|---|
| lms_subject, lms_pal | lms.dart (subject grid, chapter list, Learn/Test/Report tabs, chapter detail) |
| (tests opened from lms_subject) | quiz.dart, quiz_reports.dart |
| virtual_classroom, social_collabrative, leaderboard, child_remark, exam_schedule, holiday_list, subjects, assignment, home_work, notification_hub | lists_a.dart |
| health_details, height_weight, student_infirmary, student_vaccination, student_transport, student_hostel, student_consent, achievement_certificate | records.dart |
| student_attendance, academic_calendar | calendars.dart |
| circular_events, portfolio, result_pdf, time_table | tabbed.dart |
| about_us, principal_desk, school_information, achievement, school_timing, rules, facility, acadamic_activity (+ alias academic_activity), reach_us, student_certificate, classwork_gallery, wrt_progress | info.dart |
| leave_application | leave.dart |
| parent_communication, capture_photos | communication.dart |
| fees | fees.dart (pending/paid, receipt) |
| photos_gallery, video_gallery | gallery.dart |
| (shared) image pager, video player | media.dart |
| (shared) helpers and widgets | student_common.dart |

## Intentional changes from the old app

- All calls go through `LegacyApi` (multipart form-data). The old LMS endpoints (`studentSubjectAPI`, `studentContentAPI`, quiz APIs) were raw JSON; they now send form fields. Laravel normally reads both the same way, but verify.
- Endpoints taken from the feed's `sub_title_api` when present, with the catalogue URL as a relative fallback. Hard-coded old URLs are kept as relative paths so they follow the configured host.
- Quiz: scoring compares answer ids instead of answer text. When the time runs out the quiz now auto-submits what has been answered (old app just closed). Timer only runs when `time_allowed` is greater than 0. Answers can be reviewed on the result screen.
- Leave: reason is required (old app crashed without it); the status list refreshes and the Status tab opens after a successful send. No image cropper (package not available): the picker resizes to 500x500 at quality 50.
- Parent communication: stays on the screen after sending and refreshes the list (old app closed the screen). The literal text "null" is not shown for missing replies.
- Face attendance photos: uses `image_picker` camera; the first new photo replaces the saved set, as before.
- Timetable shows start and end time (old app left them blank). Classwork, discipline, etc. show friendly empty states instead of a blank screen.
- Status codes: `LegacyApi.ok` accepts `status` or `status_code`.
- Leaderboard: tile order is kept (points, rank, tier) but labelled.
- Achievement certificate (old screen was unfinished): implemented as a list of `document_title` with an attachment link.
- Hostel also shows warden details if returned.

## Not ported (and why)

- No WebView package is available, so: `/webView` links (content type `link`) open in the external browser; certificate and receipt HTML render with `flutter_widget_from_html_core` (basic tags, tables and some inline CSS may render differently from a real browser).
- SVG subject icons (`.svg`) show a generic icon (no SVG renderer package).
- Downloads: files open in the external app or browser instead of being saved by the app; gallery "Download" opens each link externally, "Share" shares the links (not the downloaded files).
- Home screen, drawer, bottom navigation, child picker, student profile, login/OTP, FCM registration: not part of this task (the new shell handles them).
- Notification bell badge counter: not ported.
- `youtube_video_player` (empty stub in the old app): skipped.

## Assumptions to verify against the real API

- Fallback endpoints used only when the tile has no `sub_title_api`: `/studentHomeworkAssignmentAPI`, `/studentExamScheduleAPI`, `/studentAttendanceAPI`, `/studentTimetableAPI`, `/studentPortfolioAPI`, `/studentHealthAPI`, `/studentCertificateAPI`, `/notificationHubAPI` (all verified to exist server-side), plus `/studentPhotoVideoGalleryAPI`, `/studentVirtualClassroomAPI`, `/studentSocialCollabrativeAPI`, `/studentLeaderBoardAPI` (corrected from the guessed `/studentGalleryAPI`, `/virtualClassroomAPI`, `/socialCollabrativeAPI`, `/leaderboardAPI`, which do not exist). See `docs/api-migration-student.md` for the four screens that now call `/api/*` first.
- Identity: `session.userId` as `student_id`, `session.mobileSyear` as `syear`. If `mobileSyear` is null no `syear` is sent.
- Values the old app read from the child record (`std_name`, `mobile`, `standard_id`, `term_data`, `division`) are read from `session.raw`; if the new login response does not include them, notification `mobile_no`, attendance `mobile_no`, the WRT exam dropdown (`standard_id`), the result term tabs and the quiz title suffix will be empty. Result PDFs falls back to one "Results" tab with an empty `term_id`.
- Receipt download: `GET /ajax_PDF_FeesReceipt` answers a bare PDF URL (not JSON), so it is fetched directly with `package:http` using the bearer token and `AppConfig.apiBase`.
- Question-paper responses are parsed defensively (`data` map whose first value is a map of questions, or a list).
- `LegacyApi.get` is used for `/front_desk/send_attachment/create`, `/result/exam_master` and `/document_details`; identity fields (including `token`) go in the query string, as the old app did.
- Status `0` from the notification hub and homework lists is treated as "empty", others show the server `message` with a retry.
