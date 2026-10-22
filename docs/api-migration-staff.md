# Staff (teacher + admin) API migration

Scope: a small, product-owner-approved set of teacher/admin screens moved from legacy mobile endpoints to the newer `/api/*` (or web-proven) endpoints. Everything else stays on its legacy endpoint on purpose.

**Not verified against a live server.** All mappings come from reading the Laravel routes/controllers (`D:\next_lms_erp`) and the Next.js client; the behaviour is covered by mocked-HTTP widget tests only (`test/teacher_screens_test.dart`, `test/admin_screens_test.dart`). Smoke-test every row below against a real staging account before release.

Shared code: `lib/screens/teacher/api_migration.dart` (fallback helpers and response adapters). Used by both teacher and admin screens.

## Fallback policy

| Call type | Rule |
|---|---|
| READ | Try the new endpoint; on ANY failure (HTTP 4xx/5xx, permission refusal, unparsable body, empty term list) call the legacy endpoint once and `debugPrint('api-migration: <screen> fell back to legacy: <reason>')`. |
| WRITE | Fall back to legacy only for a definite pre-processing refusal: HTTP 401/403/404/405/419 (non-JSON bodies carry the status in `ApiException.statusCode`), or a JSON body with NO `errors` payload whose message names an auth / permission / route / CSRF problem. A 422 (validation, always carries `errors`) or 500 shows the server message (first validation message when the body is generic) and is NOT retried. Network errors and timeouts are not replayed either, because the request may have been accepted. |

Why body-sniffing: `LegacyApi` (lib/core, not editable here) returns decoded JSON for 4xx without exposing the HTTP status, so a "refusal" is inferred from the body shape. A new-endpoint failure that does not look like a refusal is never replayed on a legacy write.

## Switched endpoints

| Screen / action | Legacy (fallback) | New path | Mapping | Fallback |
|---|---|---|---|---|
| Teacher + admin SMS to parents | `/teacherSendSmsParentsAPI`, `/add_adminSendSmsAPI` | `POST /api/easy_com/send-sms-parents` | `smsText`, `grade` (section id from the class picker), `standard`, `division`, `sendsms[<mobile>]=on` (students without a mobile are skipped; legacy keyed by student id). Response normalised to `status 1/0` + `message` ("N SMS sent."). | write rule. Legacy used directly when section/standard/division id is missing. |
| Teacher + admin push notification | `/add_SendNotificationAPI` | `POST /api/easy_com/send-notification-parents` | `notificationText`, class ids as above, `sendNotification[<mobile>]=on`. | write rule. Legacy used directly when a chosen student has no mobile (new endpoint addresses parents by mobile) or class ids are missing. |
| Teacher + admin email to parents | `/teacherSendEmailParentsAPI`, `/add_adminSendEmailAPI` | `POST /api/easy_com/send-email-parents` | `subject` (was `example-subject`), `content`, `all_email` (csv, unchanged), plus class ids. No attachment is sent (the app never sent one). | write rule |
| Notification report (`t_notification_report`) | `GET /easy_com/notification_report/create` | `GET /api/easy_com/reports/notification` | `from_date`, `to_date`. Rows mapped back: `student_name`->`stu_name`, `standard_name`->`std_name`, `division_name`->`div_name`, `notification_type`, `notification_text`->`NOTIFICATION_DESCRIPTION`, `notification_date`->`NOTOFICATION_DATE`. Server caps at 5,000 rows. | read rule |
| Term list for marks (`t_marks`) | `GET /lms_data?table=academic_year` (unauthenticated) | `GET /api/academic-terms` | `sub_institute_id` + `syear` from identity; rows already carry `term_id`, `title`. Empty list also triggers the fallback. | read rule |
| My leave balance (`t_my_leave`) | `GET /hrms/myleave/{id}` (returns hard-coded sample numbers) | `GET /api/hrms/leaves` | `data.summary.{total,used,remaining}` -> `leave_summary.{total_leaves,used_leaves,remaining_leaves}`; `leave_types[{leave_type,total,used}]` unchanged. | read rule. NOTE: the fallback shows the server's sample numbers again, so a 404 ("staff users only") means the user sees fake data. |
| Teacher apply leave | `POST /leave-apply` | `POST /api/leave/requests` | `leave_type`->`leave_type_id`, `day_type` full/half, `from_date`, `to_date` (full) or `slot` (half), `comment` (server requires it, max 255; legacy did not). `type_leave` dropped. Body `token` + `user_id` come from `LegacyApi.identity`. | write rule |
| Teacher leave history | `GET /lms_data?table=hrms_emp_leaves` | `GET /api/leave/requests?employee_id=<me>[&leave_type_id]` | Pages of 200 (max 10 pages). `reason`->`comment`, `employee_id`->`user_id`. Limited to the leave year of `syear`. | read rule |
| Admin leave-authorisation LIST | `POST /show-leave-authorisation` | `GET /api/leave/requests?status=pending&from_date&to_date` | Same adapter. Date semantics change from containment to overlap. Row `id` is the same `hrms_emp_leaves.id` the (unchanged) decision call needs. | read rule |
| Admission enquiry / registration / confirmation lists | `GET /admission/admission_enquiry|registration|confirmation` | `GET /api/admission_enquiry`, `GET /api/admission_registration` (used for both registration and confirmation: identical query) | Enquiry list is raw table rows: `std_name` is filled from the hard-coded standard list. | read rule |
| Admission enquiry create | `POST /admission/admission_enquiry` | `POST /api/admission_enquiry` | The new store does not number enquiries: `enquiry_no` = max numeric existing + 1 (or `<syear>001`), computed from the list (same as the web app). `Gender`->`gender`, adds `created_by`, `created_on`. Falls back to legacy BEFORE sending if the list cannot be read or numbers are non-numeric (e.g. `M2025001`). | write rule |
| Admission enquiry / registration edit | `PUT /admission/admission_*/{enquiry_no}` | `PUT /api/admission_enquiry/{id}`, `PUT /api/admission_registration/{id}` | Path uses the numeric row `id` (not the enquiry number); same query fields. | write rule |
| Discipline (teacher + admin) | `POST /add_teacherStudentDisciplineAPI` | `POST /student-care/discipline` | `student_id`, `dicipline`, `message` (required by the screen), `date_` = today, `user_id`/`sub_institute_id`/`syear` from identity. JSON `data` blob dropped. | write rule |

## Still on the legacy endpoint (unchanged)

| Area | Endpoint(s) | Why it stays |
|---|---|---|
| Leave DECISION (admin) | `POST /leave-authorisation-store` | `api/leave/requests/{id}/decision` has no role or rights check. |
| Homework, tasks, complaints, galleries, requisitions | `/teacherHomeworkAssignmentAPI`, `/student/student_homework`, `/get_*taskAPI`, `/add_*taskAPI`, `/get_*complaintAPI`, `/add_*complaintAPI`, gallery and requisition endpoints | Not in the approved set (the new equivalents lose attachments, notifications or creator scoping). |
| Marks entry / exam list | `/get_teacherResultExamList`, `/result/marks_entry` | Not approved (new exam list drops max marks). |
| Take attendance, capture attendance/photos | `/student/save_student_attendance`, capture endpoints | No `/api` equivalent. |
| Parent communication, circulars, exam schedule, leave application (students) | `/teacherParentcommunication*`, `/add_adminParentCommunication*`, circular, exam schedule, student leave endpoints | Not approved. |
| Lesson planning, proxy, visitors, inward/outward, fees, messages, virtual classroom, resources, WRT progress | various | Not approved or no equivalent. |
| Punch in/out, my attendance, leave types for the apply form | `/hrms-*`, `/lms_data` (`hrms_attendances`, `hrms_leave_types`) | Not approved. |
| Class/student pickers | `/get_teacher_timetablewise*`, `/get_admin*`, `/allStudentListAPI`, `/get_adminStudentList` | Not approved. |

## Residual risks

1. **Rights are not enforced the same way.** The legacy T2 routes (`leave-apply`, `show-leave-authorisation`, `admission/*`, `easy_com/notification_report/create`) sit behind `check_permissions` (menu rights). The new `/api/*` routes do not check menu rights. Staff who lacked the menu right can now reach these functions through the app. Conversely, a new endpoint that refuses (403) falls back to the legacy route, which still applies the old rights.
2. **Missing role checks on the new endpoints.** `api/easy_com/send-*` and `api/leave/requests` (list/apply) only require a valid JWT (`api.session` / body `token`); `api/leave/requests` accepts `user_id`/`employee_id` from the request, so a caller can apply or list on behalf of another user. `student-care/discipline` trusts `user_id` and `sub_institute_id` from the body. Admission `store`/`update` mass-assign request fields. Add `staff.only` plus rights checks server-side.
3. **CSRF 419.** `api/*` is CSRF-exempt, but the legacy web-group fallbacks (`/leave-apply`, `/admission/*`, `/show-leave-authorisation`) return 419 on hosts not listed in `VerifyCsrfToken::$except` (staging, a new prod domain, an emulator host). On those hosts only the new path works; a 419 on a NEW endpoint is treated as a refusal and retried on legacy (which will also 419 and show that error).
4. **Notification/SMS semantics change.** The new senders address parents by MOBILE number, are class-scoped (numbers outside the picked class are skipped, siblings sharing a number collapse to one) and report per-recipient results; legacy keyed by student id and always answered "sent".
5. **Enquiry numbering race.** Two staff creating enquiries at the same moment can compute the same `enquiry_no` (the web app has the same behaviour). The legacy numbering formula (`<syear>00<n>`) and the client one diverge once there are 10+ enquiries (`...0010` vs `...010`).
6. **List-shape differences.** Registration/confirmation lists are the same server query (inner join to `admission_form`, grouped by name), so enquiries without a form do not appear in confirmation/registration; the enquiry list has no standard join (name taken from a hard-coded, school-specific map).
7. **Leave-year scoping.** `api/leave/requests` limits rows to the leave year of `syear`; history from earlier years is no longer listed on the teacher history screen.
8. **Fake data on fallback.** `hrms/myleave` still returns sample numbers; falling back to it (e.g. a 404 for a user without a `tbluser` row) shows them.
9. **Refusal detection is heuristic.** Because `LegacyApi` hides HTTP status for JSON bodies, a write is only replayed on legacy when the body looks like a refusal (no `errors`, message mentions unauthorized/forbidden/permission/not found/CSRF/token/not allowed). An unusual refusal message is shown to the user instead of falling back.
