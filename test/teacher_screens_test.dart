import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:new_mobile_lms_k12/core/feed.dart';
import 'package:new_mobile_lms_k12/core/legacy_api.dart';
import 'package:new_mobile_lms_k12/core/session.dart';
import 'package:new_mobile_lms_k12/screens/screen_registry.dart';
import 'package:new_mobile_lms_k12/screens/teacher/comm_screens.dart';
import 'package:new_mobile_lms_k12/screens/teacher/hrms_screens.dart';
import 'package:new_mobile_lms_k12/screens/teacher/marks_screens.dart';
import 'package:new_mobile_lms_k12/screens/teacher/simple_lists.dart';
import 'package:new_mobile_lms_k12/screens/teacher/teacher_screens.dart';

class Recorded {
  Recorded(this.path, this.method, this.fields);
  final String path, method;
  final Map<String, String> fields;
}

/// Answers each path with canned JSON and remembers what was sent.
class FakeClient extends http.BaseClient {
  FakeClient(this.routes);
  final Map<String, Object> routes;
  final List<Recorded> calls = [];

  List<Recorded> to(String path) => calls.where((c) => c.path == path).toList();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final fields = request is http.MultipartRequest ? Map<String, String>.from(request.fields) : <String, String>{...request.url.queryParameters};
    final path = request.url.path;
    calls.add(Recorded(path, request.method, fields));
    final body = routes[path];
    if (body == null) {
      return http.StreamedResponse(Stream.value(utf8.encode('{"status":"0","message":"Nothing here"}')), 200);
    }
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200, headers: {'content-type': 'application/json'});
  }
}

Session session(String profile) => Session(
      token: 'tok',
      userId: 7,
      subInstituteId: 1,
      clientId: 1,
      userProfileId: 3,
      userProfileName: profile,
      name: 'Asha Rao',
      email: 'asha@example.com',
      schoolName: 'School',
      mobileSyear: '2026',
    );

ScreenArgs argsFor(FakeClient c, String screen, {String profile = 'Teacher', String label = 'Screen'}) {
  final s = session(profile);
  final item = FeedItem(label: label, iconUrl: '', api: '', apiParam: '', screenName: screen, renderType: 'native', webUrl: '');
  return ScreenArgs(item, s, LegacyApi(s, client: c));
}

Future<void> show(WidgetTester t, FakeClient c, String screen, {String profile = 'Teacher', String label = 'Screen'}) async {
  t.view.physicalSize = const Size(900, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final builder = lookupScreen(profile, screen)!;
  await t.pumpWidget(MaterialApp(home: builder(argsFor(c, screen, profile: profile, label: label))));
  await t.pumpAndSettle();
}

Future<void> pick(WidgetTester t, String field, String option) async {
  await t.tap(find.text(field).first);
  await t.pumpAndSettle();
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}

/// Like [FakeClient] but every route answers `(httpStatus, body)`; a String body is sent raw.
/// Unknown paths answer 404 with Laravel's JSON "route could not be found" message.
class StatusClient extends http.BaseClient {
  StatusClient(this.routes);
  final Map<String, (int, Object)> routes;
  final List<Recorded> calls = [];

  List<Recorded> to(String path) => calls.where((c) => c.path == path).toList();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final fields = request is http.MultipartRequest ? Map<String, String>.from(request.fields) : <String, String>{...request.url.queryParameters};
    calls.add(Recorded(request.url.path, request.method, fields));
    final r = routes[request.url.path] ?? (404, {'message': 'The route ${request.url.path} could not be found.'});
    final body = r.$2 is String ? r.$2 as String : jsonEncode(r.$2);
    return http.StreamedResponse(Stream.value(utf8.encode(body)), r.$1, headers: {'content-type': 'application/json'});
  }
}

ScreenArgs argsWith(http.Client c, String screen, {String profile = 'Teacher'}) {
  final s = session(profile);
  final item = FeedItem(label: 'Screen', iconUrl: '', api: '', apiParam: '', screenName: screen, renderType: 'native', webUrl: '');
  return ScreenArgs(item, s, LegacyApi(s, client: c));
}

Future<void> showWidget(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(900, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: w));
  await t.pumpAndSettle();
}

Future<void> findStudents(WidgetTester t) async {
  await pick(t, 'Standard', '5th');
  await pick(t, 'Division', 'A');
  await t.tap(find.text('Find students'));
  await t.pumpAndSettle();
}

Map<String, (int, Object)> staffClassRoutes() => {
      for (final e in classRoutes.entries) e.key: (200, e.value),
    };

const classRoutes = <String, Object>{
  '/get_teacher_timetablewiseStandard': {
    'status': '1',
    'data': [
      {'std_id': 5, 'std_name': '5th', 'grade_id': 2}
    ]
  },
  '/get_teacher_timetablewiseDivision': {
    'status': '1',
    'data': [
      {'div_id': 9, 'div_name': 'A'}
    ]
  },
  '/allStudentListAPI': {
    'status': '1',
    'data': [
      {'id': 101, 'student_name': 'Ravi Kumar', 'roll_no': 1, 'enrollment_no': 'G1', 'mobile': '9999999999', 'standard_name': '5th', 'division_name': 'A'},
      {'id': 102, 'student_name': 'Sana Khan', 'roll_no': 2, 'enrollment_no': 'G2', 'mobile': '8888888888', 'standard_name': '5th', 'division_name': 'A'},
    ]
  },
};

void main() {
  test('registry has the teacher feed names and the capture screens', () {
    for (final k in ['t_homework', 't_take_attendance', 't_timetable', 't_punch_inout', 't_my_leave', 't_wrt_progress', 't_capture_photos', 't_capture_attendance']) {
      expect(teacherScreens.containsKey(k), isTrue, reason: k);
    }
  });

  testWidgets('proxy list shows rows and the teacher uses get_proxy_master', (t) async {
    final c = FakeClient({
      '/get_proxy_master': {
        'data': [
          {'proxy_date': '2026-10-06', 'teacher_name': 'A Rao', 'proxy_teacher_name': 'B Shah', 'period_name': 'P3', 'sub_name': 'Maths', 'standard_name': '5th', 'division_name': 'A'}
        ]
      }
    });
    await show(t, c, 't_proxy', label: 'Proxy');
    expect(find.text('Maths'), findsOneWidget);
    expect(find.text('B Shah'), findsOneWidget);
    expect(c.to('/get_proxy_master').single.fields['from_date'], isNotEmpty);
  });

  testWidgets('proxy branches to the admin endpoint for Admin', (t) async {
    final c = FakeClient({
      '/get_adminTodaysProxyListAPI': {'data': []}
    });
    await show(t, c, 't_proxy', profile: 'Admin');
    expect(c.to('/get_adminTodaysProxyListAPI'), hasLength(1));
    expect(c.to('/get_proxy_master'), isEmpty);
    expect(find.text('No proxy lectures in this date range.'), findsOneWidget);
  });

  testWidgets('list shows an error with retry when the server fails', (t) async {
    final c = FakeClient({
      '/get_teacherVirtualClassroomAPI': {'status': '0', 'message': 'Not allowed today'}
    });
    await show(t, c, 't_virtual_classroom');
    expect(find.text('Not allowed today'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(c.to('/get_teacherVirtualClassroomAPI'), hasLength(2));
  });

  testWidgets('add task form submits and reports success', (t) async {
    final c = FakeClient({
      '/get_teachertaskAPI': {'status': '1', 'data': []},
      '/get_visitorTypeAPI': {
        'status': '1',
        'to_meet_array': [
          {'id': 4, 'staff_name': 'Principal'}
        ]
      },
      '/add_teachertaskAPI': {'status': '1', 'message': 'Task added'},
    });
    await show(t, c, 't_task');
    expect(find.text('No tasks yet.'), findsOneWidget);
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Print papers');
    await pick(t, 'Allocated to', 'Principal');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final sent = c.to('/add_teachertaskAPI').single.fields;
    expect(sent['title'], 'Print papers');
    expect(sent['allocated_to'], '4');
    expect(sent['teacher_id'], '7');
  });

  testWidgets('add task validates the title before calling the server', (t) async {
    final c = FakeClient({
      '/get_teachertaskAPI': {'status': '1', 'data': []},
      '/get_visitorTypeAPI': {'status': '1', 'to_meet_array': []}
    });
    await show(t, c, 't_task');
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Please enter a title.'), findsOneWidget);
    expect(c.to('/add_teachertaskAPI'), isEmpty);
  });

  testWidgets('attendance: pick class, mark everyone present, submit', (t) async {
    final c = FakeClient({
      ...classRoutes,
      '/student/save_student_attendance': {'status': '1', 'message': 'Attendance saved'},
    });
    await show(t, c, 't_take_attendance');
    await pick(t, 'Standard', '5th');
    await pick(t, 'Division', 'A');
    await t.tap(find.text('Search'));
    await t.pumpAndSettle();
    expect(find.text('Ravi Kumar'), findsOneWidget);
    await t.tap(find.text('Mark all present'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Save attendance'));
    await t.pumpAndSettle();
    final sent = c.to('/student/save_student_attendance').single.fields;
    expect(sent['student[101]'], 'P');
    expect(sent['student[102]'], 'P');
    expect(sent['standard_division'], '5||9');
  });

  testWidgets('attendance: revisiting a saved class shows the saved P/A and saves them unchanged', (t) async {
    final c = FakeClient({
      ...classRoutes,
      '/student/show_student_attendance': {
        'status': '1',
        'attendance_data': {'101': 'A', '102': 'P'},
      },
      '/student/save_student_attendance': {'status': '1', 'message': 'ok'},
    });
    await show(t, c, 't_take_attendance');
    await pick(t, 'Standard', '5th');
    await pick(t, 'Division', 'A');
    await t.tap(find.text('Search'));
    await t.pumpAndSettle();
    final q = c.to('/student/show_student_attendance').single.fields;
    expect(q['standard_division'], '5||9');
    expect(q['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$'))); // no time part
    expect(find.text('Saved earlier · change and save to update'), findsOneWidget);
    expect(find.text('Present 1'), findsOneWidget);
    expect(find.text('Absent 1'), findsOneWidget);
    await t.tap(find.textContaining('Save attendance'));
    await t.pumpAndSettle();
    final sent = c.to('/student/save_student_attendance').single.fields;
    expect(sent['student[101]'], 'A');
    expect(sent['student[102]'], 'P');
  });

  testWidgets('attendance: marking one student absent sends A and leaves the rest empty', (t) async {
    final c = FakeClient({
      ...classRoutes,
      '/student/save_student_attendance': {'status': '1', 'message': 'ok'}
    });
    await show(t, c, 't_take_attendance');
    await pick(t, 'Standard', '5th');
    await pick(t, 'Division', 'A');
    await t.tap(find.text('Search'));
    await t.pumpAndSettle();
    await t.tap(find.text('A').at(1));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Save attendance'));
    await t.pumpAndSettle();
    final sent = c.to('/student/save_student_attendance').single.fields;
    expect(sent['student[101]'], 'A');
    expect(sent['student[102]'], '');
  });

  testWidgets('student leave approval posts the decision', (t) async {
    final c = FakeClient({
      '/teacherLeaveApplicationListAPI': {
        'status': '1',
        'data': [
          {'leave_app_id': 12, 'student_name': 'Ravi Kumar', 'std_name': '5', 'title': 'Fever', 'message': 'Unwell', 'file_name': '', 'apply_date': '2026-10-05', 'reply': ''}
        ]
      },
      '/teacherLeaveApplicationSaveAPI': {'status': '1', 'message': 'ok'},
    });
    await show(t, c, 't_approve_leave');
    expect(find.text('Ravi Kumar'), findsOneWidget);
    await t.tap(find.text('Approve'));
    await t.pumpAndSettle();
    final sent = c.to('/teacherLeaveApplicationSaveAPI').single.fields;
    expect(sent['leave_app_id'], '12');
    expect(sent['status'], 'Approved');
  });

  testWidgets('timetable filters by weekday letter (Thursday is H)', (t) async {
    final c = FakeClient({
      '/teacherTimetableAPI': {
        'status_code': '1',
        'data': [
          {'week_day': 'H', 'periodname': 'P1', 'lectures': '5-A Science'},
          {'week_day': 'M', 'periodname': 'P2', 'lectures': '6-B Maths'},
        ]
      }
    });
    await show(t, c, 't_timetable');
    await t.tap(find.text('Thu'));
    await t.pumpAndSettle();
    expect(find.text('5-A Science'), findsOneWidget);
    expect(find.text('6-B Maths'), findsNothing);
    await t.tap(find.text('Mon'));
    await t.pumpAndSettle();
    expect(find.text('6-B Maths'), findsOneWidget);
  });

  testWidgets('my attendance reads the hrms_attendances table for the teacher', (t) async {
    final c = FakeClient({
      '/lms_data': {
        'data': [
          {'day': '2026-10-05', 'punchin_time': '2026-10-05 09:05:00', 'punchout_time': '2026-10-05 17:00:00'}
        ]
      }
    });
    await show(t, c, 't_my_attendance');
    expect(find.text('05 Oct 2026'), findsOneWidget);
    final q = c.to('/lms_data').single.fields;
    expect(q['table'], 'hrms_attendances');
    expect(q['filters[user_id]'], '7');
  });

  group('api migration (teacher)', () {
    Future<void> sendFlow(WidgetTester t, StatusClient c, String screen, ParentMessageKind kind, String text, {String? subject}) async {
      await showWidget(t, ParentMessageScreen(args: argsWith(c, screen), kind: kind));
      await findStudents(t);
      await t.tap(find.textContaining('Select all'));
      await t.pumpAndSettle();
      if (subject != null) await t.enterText(find.widgetWithText(TextField, 'Subject'), subject);
      await t.enterText(find.byType(TextField).last, text);
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Send to'));
      await t.pumpAndSettle();
    }

    testWidgets('SMS to parents goes to api/easy_com/send-sms-parents with grade, class and mobile keys', (t) async {
      final c = StatusClient({
        ...staffClassRoutes(),
        '/api/easy_com/send-sms-parents': (200, {'success': true, 'message': '2 SMS sent.', 'data': {'sent': 2}, 'errors': null}),
      });
      await sendFlow(t, c, 't_sms_parent', ParentMessageKind.sms, 'School closed');
      final sent = c.to('/api/easy_com/send-sms-parents').single.fields;
      expect(sent['grade'], '2');
      expect(sent['standard'], '5');
      expect(sent['division'], '9');
      expect(sent['smsText'], 'School closed');
      expect(sent['sendsms[9999999999]'], 'on');
      expect(sent['sendsms[8888888888]'], 'on');
      expect(c.to('/teacherSendSmsParentsAPI'), isEmpty);
    });

    testWidgets('a 403 refusal on SMS falls back to the legacy endpoint exactly once', (t) async {
      final c = StatusClient({
        ...staffClassRoutes(),
        '/api/easy_com/send-sms-parents': (403, {'message': 'This action is unauthorized.'}),
        '/teacherSendSmsParentsAPI': (200, {'status': '1', 'message': 'Legacy sent'}),
      });
      await sendFlow(t, c, 't_sms_parent', ParentMessageKind.sms, 'Hello');
      expect(c.to('/api/easy_com/send-sms-parents'), hasLength(1));
      expect(c.to('/teacherSendSmsParentsAPI'), hasLength(1));
      expect(c.to('/teacherSendSmsParentsAPI').single.fields['mobile_number[101]'], '9999999999');
    });

    testWidgets('a 422 on SMS shows the server message and is NOT retried on legacy', (t) async {
      final c = StatusClient({
        ...staffClassRoutes(),
        '/api/easy_com/send-sms-parents': (422, {
          'success': false,
          'message': 'Validation failed.',
          'data': null,
          'errors': {
            'smsText': ['The SMS text is too long.']
          }
        }),
        '/teacherSendSmsParentsAPI': (200, {'status': '1', 'message': 'Legacy sent'}),
      });
      await sendFlow(t, c, 't_sms_parent', ParentMessageKind.sms, 'Hello');
      expect(find.text('The SMS text is too long.'), findsOneWidget);
      expect(c.to('/teacherSendSmsParentsAPI'), isEmpty);
    });

    testWidgets('a 500 on SMS is not replayed on legacy', (t) async {
      final c = StatusClient({
        ...staffClassRoutes(),
        '/api/easy_com/send-sms-parents': (500, {'success': false, 'message': 'Something went wrong.'}),
        '/teacherSendSmsParentsAPI': (200, {'status': '1', 'message': 'Legacy sent'}),
      });
      await sendFlow(t, c, 't_sms_parent', ParentMessageKind.sms, 'Hello');
      expect(c.to('/teacherSendSmsParentsAPI'), isEmpty);
    });

    testWidgets('notification to parents keys recipients by mobile on the new endpoint', (t) async {
      final c = StatusClient({
        ...staffClassRoutes(),
        '/api/easy_com/send-notification-parents': (200, {'success': true, 'message': '2 notification(s) sent.', 'data': {}, 'errors': null}),
      });
      await sendFlow(t, c, 't_notification_parent', ParentMessageKind.notification, 'PTM tomorrow');
      final sent = c.to('/api/easy_com/send-notification-parents').single.fields;
      expect(sent['notificationText'], 'PTM tomorrow');
      expect(sent['sendNotification[9999999999]'], 'on');
      expect(sent['grade'], '2');
      expect(c.to('/add_SendNotificationAPI'), isEmpty);
    });

    testWidgets('email to parents sends subject/content/all_email to the new endpoint', (t) async {
      final routes = staffClassRoutes();
      routes['/allStudentListAPI'] = (200, {
        'status': '1',
        'data': [
          {'id': 101, 'student_name': 'Ravi Kumar', 'mobile': '9999999999', 'email': 'r@x.test', 'standard_name': '5th', 'division_name': 'A'}
        ]
      });
      routes['/api/easy_com/send-email-parents'] = (200, {'success': true, 'message': '1 email(s) sent.', 'data': {}, 'errors': null});
      final c = StatusClient(routes);
      await sendFlow(t, c, 't_email_parent', ParentMessageKind.email, 'Pack lunch', subject: 'Trip');
      final sent = c.to('/api/easy_com/send-email-parents').single.fields;
      expect(sent['subject'], 'Trip');
      expect(sent['content'], 'Pack lunch');
      expect(sent['all_email'], 'r@x.test');
      expect(c.to('/teacherSendEmailParentsAPI'), isEmpty);
    });

    Future<void> fillDiscipline(WidgetTester t, StatusClient c) async {
      await showWidget(t, DisciplineScreen(args: argsWith(c, 't_disclipline')));
      await pick(t, 'Standard', '5th');
      await pick(t, 'Division', 'A');
      await pick(t, 'Student', 'Ravi Kumar');
      await pick(t, 'Student performance', 'Good');
      await t.enterText(find.widgetWithText(TextField, 'Message'), 'Helped a friend');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
    }

    testWidgets('discipline posts to student-care/discipline with date_ and user_id; a 422 is not retried on legacy', (t) async {
      final c = StatusClient({
        ...staffClassRoutes(),
        '/student-care/discipline': (422, {
          'status': 0,
          'message': 'Invalid record details.',
          'errors': {
            'message': ['The message field is required.']
          },
          'data': []
        }),
        '/add_teacherStudentDisciplineAPI': (200, {'status': '1', 'message': 'Record Added'}),
      });
      await fillDiscipline(t, c);
      final sent = c.to('/student-care/discipline').single.fields;
      expect(sent['student_id'], '101');
      expect(sent['dicipline'], 'Good');
      expect(sent['message'], 'Helped a friend');
      expect(sent['user_id'], '7');
      expect(sent['sub_institute_id'], '1');
      expect(sent['syear'], '2026');
      expect(sent['date_'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(find.text('The message field is required.'), findsOneWidget);
      expect(c.to('/add_teacherStudentDisciplineAPI'), isEmpty);
    });

    testWidgets('discipline falls back to legacy when the new route is missing (404)', (t) async {
      final c = StatusClient({
        ...staffClassRoutes(),
        '/add_teacherStudentDisciplineAPI': (200, {'status': '1', 'message': 'Record Added'}),
      });
      await fillDiscipline(t, c);
      expect(c.to('/student-care/discipline'), hasLength(1));
      expect(c.to('/add_teacherStudentDisciplineAPI'), hasLength(1));
    });

    testWidgets('notification report reads api/easy_com/reports/notification and maps its keys', (t) async {
      final c = StatusClient({
        '/api/easy_com/reports/notification': (200, {
          'success': true,
          'data': [
            {'student_name': 'Ravi Kumar', 'standard_name': '5th', 'division_name': 'A', 'notification_type': 'Notification', 'notification_text': 'PTM at 10', 'notification_date': '05-10-2026'}
          ]
        }),
      });
      await showWidget(t, NotificationReportScreen(args: argsWith(c, 't_notification_report')));
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('PTM at 10'), findsOneWidget);
      expect(c.to('/api/easy_com/reports/notification').single.fields['from_date'], isNotEmpty);
      expect(c.to('/easy_com/notification_report/create'), isEmpty);
    });

    testWidgets('notification report falls back to the legacy report when the new one fails', (t) async {
      final c = StatusClient({
        '/api/easy_com/reports/notification': (500, '<html>boom</html>'),
        '/easy_com/notification_report/create': (200, {
          'status': '1',
          'data': [
            {'stu_name': 'Sana Khan', 'std_name': '5th', 'div_name': 'A', 'NOTIFICATION_DESCRIPTION': 'Old text', 'NOTOFICATION_DATE': '2026-10-05'}
          ]
        }),
      });
      await showWidget(t, NotificationReportScreen(args: argsWith(c, 't_notification_report')));
      expect(find.text('Sana Khan'), findsOneWidget);
      expect(c.to('/api/easy_com/reports/notification'), hasLength(1));
      expect(c.to('/easy_com/notification_report/create'), hasLength(1));
    });

    testWidgets('marks terms come from api/academic-terms', (t) async {
      final c = StatusClient({
        '/api/academic-terms': (200, {
          'success': true,
          'data': [
            {'term_id': 11, 'title': 'Term 1'}
          ]
        }),
      });
      await showWidget(t, MarksSelectorScreen(args: argsWith(c, 't_marks')));
      final q = c.to('/api/academic-terms').single.fields;
      expect(q['sub_institute_id'], '1');
      expect(q['syear'], '2026');
      expect(c.to('/lms_data'), isEmpty);
    });

    testWidgets('marks terms fall back to lms_data academic_year when api/academic-terms is refused', (t) async {
      final c = StatusClient({
        '/api/academic-terms': (403, {'message': 'Forbidden'}),
        '/lms_data': (200, {
          'data': [
            {'term_id': 12, 'title': 'Term 2'}
          ]
        }),
      });
      await showWidget(t, MarksSelectorScreen(args: argsWith(c, 't_marks')));
      expect(c.to('/api/academic-terms'), hasLength(1));
      expect(c.to('/lms_data').single.fields['table'], 'academic_year');
    });

    testWidgets('my leave reads api/hrms/leaves and maps summary/leave_types', (t) async {
      final c = StatusClient({
        '/api/hrms/leaves': (200, {
          'success': true,
          'data': {
            'summary': {'total': 12, 'used': 3, 'remaining': 9},
            'leave_types': [
              {'leave_type': 'Casual', 'total': 12, 'used': 3}
            ]
          }
        }),
      });
      await showWidget(t, MyLeaveScreen(args: argsWith(c, 't_my_leave')));
      expect(find.text('9'), findsOneWidget);
      expect(find.text('3 used'), findsOneWidget);
      expect(find.text('Casual'), findsOneWidget);
      expect(c.to('/hrms/myleave/7'), isEmpty);
    });

    testWidgets('my leave falls back to /hrms/myleave when api/hrms/leaves is refused', (t) async {
      final c = StatusClient({
        '/api/hrms/leaves': (404, {'success': false, 'message': 'HRMS is available to staff users only.'}),
        '/hrms/myleave/7': (200, {
          'status': '1',
          'data': {
            'leave_summary': {'total_leaves': 20, 'used_leaves': 5, 'remaining_leaves': 15},
            'leave_types': []
          }
        }),
      });
      await showWidget(t, MyLeaveScreen(args: argsWith(c, 't_my_leave')));
      expect(find.text('15'), findsOneWidget);
      expect(c.to('/hrms/myleave/7'), hasLength(1));
    });

    const leaveTypes = (200, {
      'data': [
        {'id': 3, 'leave_type': 'Casual'}
      ]
    });

    Future<void> fillLeave(WidgetTester t, StatusClient c) async {
      await showWidget(t, ApplyLeaveScreen(args: argsWith(c, 't_apply_leave')));
      await pick(t, 'Leave type', 'Casual');
      await pick(t, 'Day type', 'Full');
      await t.enterText(find.widgetWithText(TextField, 'Comment'), 'Family function');
      await t.tap(find.widgetWithText(FilledButton, 'Apply leave'));
      await t.pumpAndSettle();
    }

    testWidgets('apply leave posts api/leave/requests with token and user_id', (t) async {
      final c = StatusClient({
        '/lms_data': leaveTypes,
        '/api/leave/requests': (201, {'status': 1, 'message': 'Leave applied successfully', 'data': {'id': 9}}),
      });
      await fillLeave(t, c);
      final sent = c.to('/api/leave/requests').single.fields;
      expect(sent['leave_type_id'], '3');
      expect(sent['day_type'], 'full');
      expect(sent['comment'], 'Family function');
      expect(sent['token'], 'tok');
      expect(sent['user_id'], '7');
      expect(sent['to_date'], isNotEmpty);
      expect(c.to('/leave-apply'), isEmpty);
    });

    testWidgets('apply leave: a 422 shows the message and does not retry on /leave-apply', (t) async {
      final c = StatusClient({
        '/lms_data': leaveTypes,
        '/api/leave/requests': (422, {
          'status': 0,
          'message': 'A reason is required.',
          'errors': {
            'comment': ['A reason is required.']
          }
        }),
        '/leave-apply': (200, {'status': '1', 'message': 'legacy'}),
      });
      await fillLeave(t, c);
      expect(find.text('A reason is required.'), findsOneWidget);
      expect(c.to('/leave-apply'), isEmpty);
    });

    testWidgets('apply leave falls back to /leave-apply on a 419 refusal', (t) async {
      final c = StatusClient({
        '/lms_data': leaveTypes,
        '/api/leave/requests': (419, '<html>Page Expired</html>'),
        '/leave-apply': (200, {'status': '1', 'message': 'legacy ok'}),
      });
      await fillLeave(t, c);
      expect(c.to('/leave-apply'), hasLength(1));
      expect(c.to('/leave-apply').single.fields['leave_type'], '3');
    });

    testWidgets('leave history lists api/leave/requests rows for the teacher (reason shown as comment)', (t) async {
      final c = StatusClient({
        '/lms_data': leaveTypes,
        '/api/leave/requests': (200, {
          'status': 1,
          'data': [
            {'id': 5, 'employee_id': 7, 'leave_type_id': 3, 'leave_type': 'Casual', 'day_type': '1', 'from_date': '2026-10-02', 'to_date': '2026-10-03', 'status': 'approved', 'reason': 'Wedding'}
          ],
          'pagination': {'page': 1, 'per_page': 200, 'total': 1, 'last_page': 1}
        }),
      });
      await showWidget(t, LeaveHistoryScreen(args: argsWith(c, 't_leave_history')));
      expect(find.text('Wedding'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      final q = c.to('/api/leave/requests').single.fields;
      expect(q['employee_id'], '7');
      expect(q['token'], 'tok');
      expect(c.to('/lms_data').where((x) => x.fields['table'] == 'hrms_emp_leaves'), isEmpty);
    });
  });
}
