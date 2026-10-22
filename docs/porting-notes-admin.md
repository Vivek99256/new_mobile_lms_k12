# Admin screens port notes

Source: old Flutter/GetX app (`d:/scholarclone`, admin folder). Nothing here was verified against the live server; all behaviour comes from the catalogue and the old source.

## Registered screen_names (19) -> file

All in `lib/screens/admin/admin_screens.dart` (`adminScreens`).

| screen_name | file / class |
|---|---|
| t_teacher_profile | profiles.dart `TeacherProfileListScreen` (+ `TeacherProfileDetailScreen`) |
| t_student_profile | profiles.dart `StudentProfileListScreen` (+ `StudentProfileDetailScreen`, written new) |
| t_own_profile | profiles.dart `OwnProfileScreen` (session data only, no API) |
| t_homework | homework.dart |
| t_circular | circular.dart |
| t_approve_leave | approve_leave.dart |
| t_disclipline | discipline.dart |
| t_sms_parent, t_notification_parent, t_email_parent | send_message.dart `SendMessageScreen(kind)` |
| t_enquiry, t_registration, t_confirmation | admission_list.dart `AdmissionListScreen(stage)`; form in admission_form.dart |
| t_feescollect | fees_collect.dart (+ fee_details.dart: details, payment history, `ReceiptScreen`) |
| t_leave_authorisation | leave_requests.dart (list + detail) |
| t_inward, t_outward | inward_outward.dart (+ inward_outward_form.dart) |
| t_capture_photos | capture_photos.dart `CapturePhotosScreen` (+ student_attendance_photos.dart) |
| t_capture_attendance | capture_attendance.dart `CaptureAttendanceScreen(isAdmin: true)` |

Not registered, but exposed: `AdminAddPhotoVideoScreen(args:)` in `admin_add_photo_video.dart` (opened by the shared gallery; pops `true` after a save; the Photos/Videos tab follows the tile name, optional `video:` override). The teacher agent registers teacher `t_capture_attendance` / `t_capture_photos` against `CaptureAttendanceScreen(args, isAdmin)` and `CapturePhotosScreen(args)`.

Helpers: `admin_common.dart` (`AdminHttp` PUT/DELETE, `statusOf`/`submitOk`, `SubmitGuard`, `StudentPicker`, `StudentTile`), `camera_helper.dart`.

## Intentional changes vs the old app

- Success is read from `status` OR `status_code` everywhere writes happen. Server `message` is toasted on failure and success.
- Every cascade (Section > Standard > Division > Subject) resets child levels on change (kit `CascadeFilter`). Student results are cleared when the filter changes and replaced (not appended) on each Search.
- Discipline: `data` is `jsonEncode`d. The "Mobile No." field (required but never sent) was dropped.
- Admission enquiry: create toasts, goes back and reloads the list; `email` is sent as `email`; Follow-up on the card uses `followup_date`. Registration edit sends `middle_name` and the edited `previous_standard`. The hard-coded enquiry number `20210024` is not sent on create (see assumptions).
- Admission confirmation: list only (read-only). The old create/edit controller was a copy of the Outward form and could not work. No edit endpoint was guessed.
- Fees: pending installments with checkboxes, total, bank name + transaction id, Pay now, receipt HTML view, and the PAID history (new; tap a row to see its `fees_html`).
- Inward/outward: delete asks for confirmation and only removes the row after a non-"0" response (the old code removed it unconditionally). Edit does not allow replacing the attachment (see below).
- Leave authorisation: the list refetches when either date changes; picking a From date later than To moves To. After Apply the screen stays open on failure (the old app always went back).
- Photo/video: validation messages are no longer swapped. Photo upload uses `image_picker` multi-select. Videos remain link-only (as in the old app).
- Capture attendance step 3 keys `student[<student id>]`. Both roles use the cascade filter (no `standard_division` in the new login).
- Homework `students[]` is still a single comma-joined field. Selection is by student `id` (SMS/email previously tracked by `enrollment_no`).
- Dates are sent as `yyyy-MM-dd` (old app sent raw `DateTime.toString()` in several places; the server was reported to accept both).
- Teacher list has a local name/mobile search (new). Student/teacher "detail" screens are read-only.

## Not ported / limitations

- Admission confirmation create/edit (broken in source).
- Shared teacher screens, the gallery list, the home screen and the drawer (other agents / app shell). "My Profile" has no API.
- Inward/outward edit cannot change the attachment: the edit call is a PUT with query-string parameters only and the old app did not re-send the file.
- Video file upload (never uploaded by the old app).
- Receipt print/share.

## Assumptions to verify against the real API

1. Capture attendance step 2: the old code sent a hard-coded sample as `json_data`. Assumption: `add_studentCaptureAttendanceAPI` returns the recognised students in `data` (same shape as the sample: student_id, student_name, enrollment_no, roll_no, attendance_code, standard_id, division_id, attendance_date) and that array is what `get_attendanceDataAPI` wants as `json_data`. If the upload returns no list, the app sends `[{standard_id, division_id, attendance_date}]`. If step 2 yields no students, the app falls back to the class roster from `get_adminStudentList`, all marked Absent, for manual marking. Step 3 posts `standard_division="<std>||<div>"` and `student[<id>]=P|A`.
2. Session `syear` is `session.mobileSyear`; when null the app omits `syear` instead of defaulting to "2021" (it is sent as empty on the PUT/receipt query strings).
3. Admission enquiry create: `enquiry_id` is omitted (server presumed to generate it). Gender key is `Gender`, `send_sms` ids are inverted (No=1, Yes=0) as in the old app.
4. Admission enquiry/registration/confirmation lists use `GET /admission/admission_*` with `type, token, sub_institute_id, syear` from the standard identity block. PUT edit URLs are `/admission/admission_enquiry/<enquiry_no>` and `/admission/admission_registration/<enquiry_no>` with all fields in the query string.
5. Registration edit sends `status` and `admission_standard` as NAMES (OPEN/CLOSE, standard label), as the old app did; enquiry edit sends ids.
6. Inward/outward create for inward also sends `inward_number`/`inward_date` next to the `outward_*` keys the old inward form used; unknown extras are assumed ignored. Edit prefill matches dropdowns by label (then id).
7. Fees: `studentFeesDetailAPI` and `fees/get_online_receipt` are called with params in the URL and no identity body; the pay call uses `STU_DATA.token` (falls back to the admin token). Host is the configured API base, not `dev.triz.co.in` explicitly. `receipt_html` is read from the top level or `data`.
8. Leave authorisation reads `get_employee_leave_lists`; action values are lowercased (`approved_lwp`).
9. Leave approve uses `status` strings "Approved" / "Reject". "Replied" detection: reply, reply_on and reply_by all non-empty.
10. Homework attachment is still required (old behaviour) and sent as `image`.
11. Student detail data comes from the list row (no extra call). `allStudentListAPI` is used for student profile and discipline, `get_adminStudentList` elsewhere, as in the old app.

## TODO: hard-coded admission lists

`admissionStandards` and `admissionCategories` in `admission_form.dart` are copied from the old app's `core/utils/standard.dart` and are specific to one school. Replace them with server-sourced lists when an endpoint exists; they are only a fallback.

## Tests

`test/admin_screens_test.dart` (11 widget/unit tests): registry keys, list + search, list error/retry, cascade filter + student search, circular validation + submit toast, leave approve (status string, reload), fee installments total + pay + receipt + history, inward delete confirmation, enquiry create (email field), leave authorisation apply, own profile + capture-attendance initial state. HTTP is mocked with a `BaseClient` subclass.

## API migration (staff)

Parent SMS/notification/email, discipline, the leave-authorisation LIST (not the decision) and the admission enquiry/registration/confirmation lists and edit/create forms now call the newer endpoints first, with the fallback rules in `docs/api-migration-staff.md`. Admission edits use the numeric row `id` (not the enquiry number) on the new routes. Tests: the `api migration (admin)` group of `test/admin_screens_test.dart`.
