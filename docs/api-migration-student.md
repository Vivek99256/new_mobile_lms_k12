# Student screens: legacy -> `/api/*` migration status

Source analysis: backend routes/controllers read in `D:\next_lms_erp`. **Nothing here was verified against the live server**; only mocked-HTTP widget tests (`test/student_screens_test.dart`, group "api-migration") prove the client behaviour.

Rule for switched screens: call the new endpoint first; on any failure (HTTP 4xx/5xx, `success:false`, permission refusal, unparsable body, network) fall back ONCE to the legacy call and `debugPrint('api-migration: <screen> fell back to legacy: <reason>')` (helper `Sx.newThenLegacy`). Only reads are switched, so no write can be replayed.

## Switched (4)

| Screen | New endpoint | Request mapping | Response mapping | Fallback |
|---|---|---|---|---|
| result_pdf | `POST /api/result/cbse-1t5-result/pdf` (same controller method) | `term_id`, `student_id`, `syear`, `sub_institute_id` kept (identity auto-added) | `{success,data}` -> same `data` (object or list) -> `pdf_link` rows. HTTP 404 `success:false` "No Record" -> empty state, **no** fallback | `POST /studentResultPDFAPI` |
| leaderboard | `GET /api/lms/leaderboard` (bearer token identity, no body ids) | none | `data.learner.total_points` -> "My Points" tile; `rank` of `class_size` -> "My Leaderboard" (`#3 of 30`); `medal` -> "My Tier". `has_data:false` -> empty state. Modules/toppers/rankings (paginated) not shown | `POST /studentLeaderBoardAPI` (legacy tiles unchanged) |
| social_collabrative (student) | `GET /api/lms/social-collaborative?mine=1&per_page=50` (pages followed, max 10) and `GET /api/lms/social-collaborative/{id}` | none (token) | list row: `attachment_url` -> attachment, `comment_count` -> "View replies (n)"; thread loaded on tap from `data.comments[]` (`message`, `created_at`, `author.name`). A failed thread call shows "Could not load the replies." (no legacy re-call) | `POST /studentSocialCollabrativeAPI` (replies inline as before) |
| wrt_progress exam dropdown | `GET /api/result/exam-master/dropdown?standard_id=` | `standard_id` | `data[].id` / `data[].name` (fixes the previous empty labels) | `GET /result/exam_master`, now reading `Id`/`ExamTitle` (and the old keys) |

`user_profile_name='Student'`, `student_id`, `user_id` are sent by `LegacyApi.identity` on the POST (result PDF). The two token-scoped `GET`s (`/api/lms/*`, `exam-master/dropdown`) are sent without identity fields because the server derives them from the bearer token.

## Fallback paths corrected

| Was (does not exist) | Now |
|---|---|
| `/studentGalleryAPI` | `/studentPhotoVideoGalleryAPI` |
| `/virtualClassroomAPI` | `/studentVirtualClassroomAPI` |
| `/socialCollabrativeAPI` | `/studentSocialCollabrativeAPI` (legacy fallback of the switched screen) |
| `/leaderboardAPI` | `/studentLeaderBoardAPI` (legacy fallback of the switched screen) |

The other "guessed" fallbacks in the old porting notes (`/studentHomeworkAssignmentAPI`, `/studentExamScheduleAPI`, `/studentAttendanceAPI`, `/studentTimetableAPI`, `/studentPortfolioAPI`, `/studentHealthAPI`, `/studentCertificateAPI`, `/notificationHubAPI`) were checked in the analysis and do exist, so they are unchanged. No fallback had to be removed for lack of a real path.

## Still legacy (not approved for switching or no equivalent)

| Legacy endpoint | Screen | Why it stays |
|---|---|---|
| `studentSubjectAPI`, `studentContentAPI`, `studentQuestionPaperListAPI` | lms | New `/api/lms-courses`, `/lms-chapter-content`, `/question-paper` exist but body-supplied identity, shared-library and topic-wise gaps; not approved |
| `studentQuestionPaperAPI`, `...SaveAPI`, `studentAssessmentAPI`, `studentAssessmentDetailAPI` | quiz, reports | Replacements are root-level `/lms/online_exam*`, not `/api`; writes; not approved |
| `studentHomeworkAssignmentAPI` | home_work, assignment | `/api/lms-homework/list` needs client rebuilds and trusts a body profile name; not approved |
| `studentPhotoVideoGalleryAPI` | galleries | `/api/front-desk/photo-video-gallery` has no student scoping; not approved |
| `studentTimetableAPI`, `studentCalenderAPI` | time_table, holiday_list, academic_calendar | Replacements are root-level and need more ids / return school-wide data; not approved |
| attendance, fees, receipt, leave, circulars, notifications, parent communication, capture photos, health, infirmary, vaccination, height/weight, transport, hostel, consent, documents, certificates, discipline, exam schedule, teachers, school info, portfolio, virtual classroom, classwork, `get_wrtreportAPI` | various | No student-safe `/api` equivalent exists (class C in the analysis) |

## Residual risks

- Unverified against a live server: field names (`learner.rank`, `author.name`, `meta.last_page`, `comments[]`) come from reading the controllers, not from real responses.
- `api.session` endpoints return 422 "Academic Term Date Expired" when no academic_year row covers today, and 401 for old-app tokens; the legacy fallback hides that (check logs for `api-migration:` lines).
- "No Record" detection is by message text (the HTTP status is not exposed by `LegacyApi`); a differently worded 404 triggers one legacy call, which is harmless.
- Leaderboard ranks are now real and will differ from the old (top-5-only) ranks. The tier is the server's constant `Bronze`.
- Social thread replies need one extra call per opened doubt; the list is capped at 10 pages of 50.
- `student_id` for the result PDF is still taken from the request body server-side (same IDOR weakness as legacy).
- Exam dropdown: `/api/result/*` is reachable by any authenticated user on the server (backend hardening point, not a client issue).
