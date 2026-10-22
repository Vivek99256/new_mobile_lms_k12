# Mobile page audit — duplicates and dropdown fields

Audited 2026-10-06, read-only, against the live database (`mobile_pages`, `mobile_page_versions`,
`teacher_mobile_homescreen`, `mobile_homescreen`). Only school (sub_institute) **1** has Page Builder pages.
Nothing was changed — everything below is flagged for correction.

Page IDs are `mobile_pages.id` (Mobile Page Builder → Pages).

## 1. Duplicate pages

### 1a. Same page built more than once (Page Builder)

| Flag | Pages | What is duplicated | Suggested fix |
| --- | --- | --- | --- |
| **DUP-1** | **#50** Mark Attendance (published, `mark-attendance`) and **#67** Mark Attendance (draft, `mark-attendance-2`) | Identical layout: same title, same list, same search fields (standard, division, date). | Delete **#67**. Keep #50 (it is the one the menu uses). |
| **DUP-2** | **#16** Add Student (published, `untitled-page-4`), **#27** Add Student (draft, `add-student`) and **#82** Add Student Registration (published, `add-student-registration`) | Three pages for one task; all post to `student-registration`. #27 is the most complete (18 fields, real dropdowns); #82 is live but only has plain-text fields; #16 is effectively empty (see 1c). | Keep one. Recommended: finish **#27** (fix the dropdowns in section 2), publish it, then delete #16 and #82. The app currently runs #82 under the slug `add-student-registration`, so repoint anything that uses that slug. |
| **DUP-3** | **#13**, **#14**, **#15** "Untitled Page" (inactive) | Three empty placeholder pages, no content. | Delete all three. |

### 1b. Same menu entry listed twice (mobile menu rows)

| Flag | Rows | Detail | Suggested fix |
| --- | --- | --- | --- |
| **DUP-4** | `teacher_mobile_homescreen` school 1, **Admin** profile: "My Attendance" (row `t_my_attendance`, native) and "My Attendance" (row `my_attendance`, id 2500, webview → page #50 *Mark Attendance*) | Same label, two different things: one is staff punch/attendance, the other is the *class* attendance page #50 mislabelled "My Attendance". Admin sees two identical-looking "My Attendance" entries. | Rename row 2500 to "Mark Attendance" (it opens #50), or remove it if `t_my_attendance` is the intended one. |

No other duplicates found: no repeated entries in the student menu (`mobile_homescreen`, 862 active rows) or among
the other 1,100+ staff/admin rows, and no label from the mobile menu appears twice in the web menu (so the app's
level-wise tree does not create duplicates itself).

### 1c. Not duplicates, but broken or empty (found while checking)

| Flag | Page | Problem |
| --- | --- | --- |
| **EMPTY-1** | **#16** Add Student (published) | Its only input has **no field key** and the label "Add Student", and the button has **no action** ("Button" → none). It cannot save anything. |
| **EMPTY-2** | **#52** Admission Inquiry (published, menu row 2501 "Admission Enquiry") | The layout is a single image — **no form fields and no button**. Users opening "Admission Enquiry" see nothing to fill in. |
| **EMPTY-3** | **#51** Admission Confirmation (draft) | Empty layout, 0 components. |

## 2. Dropdown fields shown as plain inputs

A field is flagged when it can only take a fixed or looked-up value but is built as free text, or when the label
itself tells the user what to type.

| Flag | Page | Field (key) | Currently | Should be |
| --- | --- | --- | --- | --- |
| **DD-1** | **#82** Add Student Registration (**published**) | Gender (`gender`) | text — label says "(Male/Female/Other)" | dropdown: Male / Female / Other (as #27 already does) |
| **DD-2** | #82 | Blood Group (`bloodgroup`) | text | dropdown with the 8 groups (as #27) |
| **DD-3** | #82 | Date of Birth (`dob`) | text — label says "(YYYY-MM-DD)" | **date picker** (`inputType: date`) |
| **DD-4** | #82 | Standard / Division | **missing entirely** — the page cannot place a student in a class | add Standard and Division dropdowns, plus Section, Student Quota and House as #27 has |
| **DD-5** | **#27** Add Student (draft) | Standard (`standard`) | text | dropdown (class list). It is cascading with Division, which is why it was imported as text; needs a real cascading select |
| **DD-6** | #27 | Division (`division`) | text | dropdown, filtered by the chosen Standard |
| **DD-7** | **#50** Mark Attendance (**published**) and **#67** (draft) | Search field Standard (`standard`) | text | dropdown (classes) |
| **DD-8** | #50 / #67 | Search field Division (`division`) | text | dropdown (divisions of the chosen class) |
| **DD-9** | **#95** Student Vaccination (published) | Vaccination Type (`vaccination_type`) | text | dropdown of vaccine types (or text + suggestions if the list is open-ended) |
| **DD-10** | **#92** Student Discipline, **#93** Height & Weight, **#94** Health, **#95** Vaccination, **#96** Infirmary | Student ID (`student_id`) | free text / number | **student lookup** (search by name or GR no. and pick) — users should not type a database id. Lower priority |
| **DD-11** | **#96** Student Infirmary | Health Center (`health_center`) | text | dropdown if the school has a fixed list of centers (confirm) |

Already correct (real dropdowns): #27 Section, Blood Group, Gender, Student Quota, House; #92 Discipline Type and Flag.

**Priority:** DD-1…DD-4 and DD-7/DD-8 are on **published** pages that are live in the menu today; DD-5/DD-6 are on a draft.

## 3. How the app shows these

The Flutter app renders whatever the page says: `inputType: select` becomes a dropdown (options from the page or
from its `optionsSource` endpoint), anything else becomes a text field. So these are **page configuration fixes**
(Mobile Page Builder) and need no app update — change the field type to *select* and set its options/source, then
republish.
