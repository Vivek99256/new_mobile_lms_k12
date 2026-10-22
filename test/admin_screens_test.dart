import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:new_mobile_lms_k12/core/feed.dart';
import 'package:new_mobile_lms_k12/core/legacy_api.dart';
import 'package:new_mobile_lms_k12/core/session.dart';
import 'package:new_mobile_lms_k12/screens/admin/admin_common.dart';
import 'package:new_mobile_lms_k12/screens/admin/admin_screens.dart';
import 'package:new_mobile_lms_k12/screens/admin/admission_form.dart';
import 'package:new_mobile_lms_k12/screens/admin/admission_list.dart';
import 'package:new_mobile_lms_k12/screens/admin/approve_leave.dart';
import 'package:new_mobile_lms_k12/screens/admin/capture_attendance.dart';
import 'package:new_mobile_lms_k12/screens/admin/circular.dart';
import 'package:new_mobile_lms_k12/screens/admin/discipline.dart';
import 'package:new_mobile_lms_k12/screens/admin/fee_details.dart';
import 'package:new_mobile_lms_k12/screens/admin/inward_outward.dart';
import 'package:new_mobile_lms_k12/screens/admin/leave_requests.dart';
import 'package:new_mobile_lms_k12/screens/admin/profiles.dart';
import 'package:new_mobile_lms_k12/screens/admin/send_message.dart';
import 'package:new_mobile_lms_k12/screens/screen_registry.dart';

/// Records every request and answers from a path -> JSON table.
class FakeClient extends http.BaseClient {
  FakeClient(this.routes);
  final Map<String, Object? Function(http.BaseRequest)> routes;
  final log = <http.BaseRequest>[];

  Map<String, String> fieldsOf(http.BaseRequest r) => r is http.MultipartRequest ? r.fields : r.url.queryParameters;

  Iterable<http.BaseRequest> calls(String path) => log.where((r) => r.url.path == path);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    log.add(request);
    final h = routes[request.url.path];
    final body = h == null ? {'status': '0', 'message': 'no route ${request.url.path}'} : h(request);
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200, headers: {'content-type': 'application/json'});
  }
}

Session _session() => Session(
      token: 't0k',
      userId: 7,
      subInstituteId: 3,
      clientId: 1,
      userProfileId: 1,
      userProfileName: 'Admin',
      name: 'Asha Admin',
      email: 'asha@school.test',
      schoolName: 'Test School',
      mobileSyear: '2025',
      raw: const {'mobile': '9999999999', 'address': '12 Park Road'},
    );

ScreenArgs _args(FakeClient c, {String screen = 't_x', String label = 'Tile'}) {
  final session = _session();
  AdminHttp.client = c;
  return ScreenArgs(
    FeedItem(label: label, iconUrl: '', api: '', apiParam: '', screenName: screen, renderType: 'native', webUrl: ''),
    session,
    LegacyApi(session, client: c),
  );
}

Map<String, Object?> ok([Object? data, String message = 'Done']) => {'status': '1', 'message': message, 'data': data};

Future<void> _show(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => screen)), child: const Text('open')))),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String field, String option) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

final _cascade = <String, Object? Function(http.BaseRequest)>{
  '/get_adminAcademicSection': (_) => ok([{'id': 1, 'short_name': 'Primary'}]),
  '/get_adminStandard': (_) => ok([{'id': 10, 'name': 'Std 5'}]),
  '/get_adminDivision': (_) => ok([{'id': 20, 'name': 'A'}]),
};

/// Answers each path with `(httpStatus, body)` from a handler, so tests can assert on 4xx/5xx
/// handling. Unknown paths answer 404 with Laravel's JSON "route could not be found" message.
class StatusClient extends http.BaseClient {
  StatusClient(this.routes);
  final Map<String, (int, Object) Function(http.BaseRequest)> routes;
  final log = <http.BaseRequest>[];

  Map<String, String> fieldsOf(http.BaseRequest r) => r is http.MultipartRequest ? r.fields : r.url.queryParameters;

  List<http.BaseRequest> calls(String path) => log.where((r) => r.url.path == path).toList();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    log.add(request);
    final h = routes[request.url.path];
    final (int, Object) r = h == null ? (404, <String, Object>{'message': 'The route ${request.url.path} could not be found.'}) : h(request);
    final body = r.$2 is String ? r.$2 as String : jsonEncode(r.$2);
    return http.StreamedResponse(Stream.value(utf8.encode(body)), r.$1, headers: {'content-type': 'application/json'});
  }
}

ScreenArgs _argsFor(http.Client c, {String screen = 't_x'}) {
  final session = _session();
  AdminHttp.client = c;
  return ScreenArgs(
    FeedItem(label: 'Tile', iconUrl: '', api: '', apiParam: '', screenName: screen, renderType: 'native', webUrl: ''),
    session,
    LegacyApi(session, client: c),
  );
}

(int, Object) Function(http.BaseRequest) _r(int status, Object body) => (_) => (status, body);

final _statusCascade = <String, (int, Object) Function(http.BaseRequest)>{
  for (final e in _cascade.entries) e.key: (r) => (200, e.value(r) as Object),
};

final _studentsWithContacts = _r(200, {
  'status': '1',
  'data': [
    {'id': 5, 'student_name': 'Kiran Patel', 'mobile': '9811111111', 'email': 'k@x.test', 'standard_name': 'Std 5', 'division_name': 'A'},
  ],
});

void main() {
  test('registry holds every admin screen_name', () {
    for (final k in [
      't_teacher_profile', 't_student_profile', 't_homework', 't_circular', 't_approve_leave', 't_disclipline',
      't_sms_parent', 't_notification_parent', 't_email_parent', 't_enquiry', 't_registration', 't_confirmation',
      't_feescollect', 't_leave_authorisation', 't_inward', 't_outward', 't_capture_photos', 't_capture_attendance', 't_own_profile',
    ]) {
      expect(adminScreens.containsKey(k), isTrue, reason: k);
    }
  });

  testWidgets('teacher list shows rows and searches', (tester) async {
    final c = FakeClient({
      '/get_adminTeacherList': (_) => ok([
            {'id': 1, 'user_full_name': 'Ravi Shah', 'mobile': '9811111111', 'user_profile_name': 'Teacher', 'birthdate': '1990-01-05'},
            {'id': 2, 'user_full_name': 'Meena Joshi', 'mobile': '9822222222', 'user_profile_name': 'Teacher'},
          ]),
    });
    await _show(tester, TeacherProfileListScreen(args: _args(c)));
    expect(find.text('Ravi Shah'), findsOneWidget);
    expect(find.text('Meena Joshi'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'meena');
    await tester.pumpAndSettle();
    expect(find.text('Ravi Shah'), findsNothing);
    expect(find.text('Meena Joshi'), findsOneWidget);
  });

  testWidgets('list shows the server error with a retry', (tester) async {
    final c = FakeClient({'/get_adminTeacherList': (_) => {'status': '0', 'message': 'No access'}});
    await _show(tester, TeacherProfileListScreen(args: _args(c)));
    expect(find.text('No access'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('student profile: cascade filter then search lists students', (tester) async {
    final c = FakeClient({
      ..._cascade,
      '/allStudentListAPI': (_) => ok([
            {'id': 5, 'student_name': 'Kiran Patel', 'roll_no': 4, 'enrollment_no': 'GR9', 'standard_name': 'Std 5', 'division_name': 'A'},
          ]),
    });
    await _show(tester, StudentProfileListScreen(args: _args(c)));
    // Search stays disabled until a standard is chosen.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Search students')).onPressed, isNull);
    await _pick(tester, 'Section', 'Primary');
    await _pick(tester, 'Standard', 'Std 5');
    await _pick(tester, 'Division', 'A');
    await tester.tap(find.text('Search students'));
    await tester.pumpAndSettle();
    expect(find.text('Kiran Patel'), findsOneWidget);
    final sent = c.fieldsOf(c.calls('/allStudentListAPI').single);
    expect(sent['standard_id'], '10');
    expect(sent['division_id'], '20');
    expect(sent['grade_id'], '1');
  });

  testWidgets('circular: validation toast, then a successful submit toasts the server message', (tester) async {
    final c = FakeClient({..._cascade, '/add_adminCircularAPI': (_) => ok(null, 'Circular added')});
    await _show(tester, AdminCircularScreen(args: _args(c)));
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.text('Please select a standard.'), findsOneWidget);

    await _pick(tester, 'Section', 'Primary');
    await _pick(tester, 'Standard', 'Std 5');
    await _pick(tester, 'Division', 'A');
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Sports day');
    await tester.enterText(find.widgetWithText(TextField, 'Message'), 'Bring kits');
    await _pick(tester, 'Type', 'Event');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    final sent = c.fieldsOf(c.calls('/add_adminCircularAPI').single);
    expect(sent['type'], '2');
    expect(sent['standard_id'], '10');
    expect(sent['title'], 'Sports day');
    expect(find.text('Circular added'), findsOneWidget);
    expect(find.text('open'), findsOneWidget); // popped back
  });

  testWidgets('approve leave sends the exact status string and reloads', (tester) async {
    var state = 'pending';
    final c = FakeClient({
      '/get_adminLeaveApplicationListAPI': (_) => ok([
            state == 'pending'
                ? {'leave_app_id': 9, 'student_name': 'Isha Rao', 'std_name': '5', 'title': 'Fever', 'message': 'Unwell', 'apply_date': '2025-07-01', 'reply': '', 'reply_on': '', 'reply_by': ''}
                : {'leave_app_id': 9, 'student_name': 'Isha Rao', 'std_name': '5', 'title': 'Fever', 'apply_date': '2025-07-01', 'reply': 'ok', 'reply_on': '2025-07-02 10:00:00', 'reply_by': 'Asha', 'status': 'Approved'},
          ]),
      '/add_adminLeaveApplicationSaveAPI': (_) {
        state = 'done';
        return {'status_code': '1', 'message': 'Leave saved'};
      },
    });
    await _show(tester, ApproveLeaveScreen(args: _args(c)));
    await tester.enterText(find.widgetWithText(TextField, 'Reply (optional)'), 'ok');
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    final sent = c.fieldsOf(c.calls('/add_adminLeaveApplicationSaveAPI').single);
    expect(sent['status'], 'Approved');
    expect(sent['leave_app_id'], '9');
    expect(sent['reply'], 'ok');
    expect(c.calls('/get_adminLeaveApplicationListAPI').length, 2);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Approved'), findsWidgets);
  });

  testWidgets('fee details: ticking installments sums the total and pay sends it', (tester) async {
    final c = FakeClient({
      '/studentFeesDetailAPI': (_) => ok({
            'STU_DATA': {'token': 'stu-tok'},
            'PENDING': [
              {'month': 'April', 'remain': 100},
              {'month': 'May', 'remain': '200'},
              {'month': 'June', 'remain': 400},
            ],
            'PAID': [
              {'receipt_no': 'R-11', 'receiptdate': '2025-03-01', 'payment_mode': 'Cash', 'paid_amount': 500},
            ],
          }),
      '/fees/get_online_receipt': (_) => {'status': '1', 'message': 'Paid', 'receipt_html': '<p>Receipt body</p>'},
    });
    await _show(tester, FeeDetailsScreen(args: _args(c), student: const {'id': 5, 'student_name': 'Kiran'}));
    expect(find.text('Receipt #R-11'), findsOneWidget); // paid history is shown
    expect(find.byKey(const Key('fee-total')).evaluate().isNotEmpty, isTrue);
    expect(find.text('Rs 0'), findsOneWidget);
    await tester.tap(find.text('April'));
    await tester.tap(find.text('May'));
    await tester.pump();
    expect(find.text('Rs 300'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextField, 'Bank name'), 'SBI');
    await tester.enterText(find.widgetWithText(TextField, 'Transaction ID'), 'TX1');
    await tester.tap(find.textContaining('Pay now'));
    await tester.pumpAndSettle();
    final q = c.calls('/fees/get_online_receipt').single.url.queryParameters;
    expect(q['amount'], '300');
    expect(q['token'], 'stu-tok');
    expect(q['transactionid'], 'TX1');
    expect(find.text('Fees receipt'), findsOneWidget);
  });

  testWidgets('inward delete asks first; cancel keeps the row, confirm deletes it', (tester) async {
    var rowsLeft = 1;
    final c = FakeClient({
      '/inward_outward/add_inward': (r) =>
          ok(rowsLeft == 0 ? [] : [{'id': 4, 'place_id': 'Head office', 'inward_number': 'IN-1', 'title': 'Letter', 'inward_date': '2025-06-01'}]),
      '/inward_outward/add_inward/4': (r) {
        rowsLeft = 0;
        return {'status': '1', 'message': 'Deleted'};
      },
    });
    await _show(tester, RegisterListScreen(args: _args(c), kind: RegisterKind.inward));
    expect(find.text('1. Head office'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete inward entry?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.log.where((r) => r.method == 'DELETE'), isEmpty);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(c.log.where((r) => r.method == 'DELETE').length, 1);
    expect(find.text('No inward entries yet.'), findsOneWidget);
  });

  testWidgets('enquiry create sends email as email, toasts and returns true', (tester) async {
    final c = FakeClient({'/admission/admission_enquiry': (_) => ok(null, 'Enquiry saved')});
    final args = _args(c);
    await _show(tester, AdmissionFormScreen(args: args, stage: AdmissionStage.enquiry));
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Neel');
    await tester.enterText(find.widgetWithText(TextField, 'Mobile'), '9000000001');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'neel@x.test');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final sent = c.fieldsOf(c.calls('/admission/admission_enquiry').single);
    expect(sent['email'], 'neel@x.test');
    expect(sent['mobile'], '9000000001');
    expect(find.text('Enquiry saved'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('leave request detail: Apply needs an action and sends it lowercased', (tester) async {
    final c = FakeClient({'/leave-authorisation-store': (_) => ok(null, 'Updated')});
    await _show(tester, LeaveRequestDetailScreen(args: _args(c), row: const {'id': 12, 'employee_name': 'T. Mehta', 'day_type': '0.5', 'slot': 'first_half'}));
    expect(find.text('Half day'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply')).onPressed, isNull);
    await _pick(tester, 'Take action', 'Approved lwp');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    final sent = c.fieldsOf(c.calls('/leave-authorisation-store').single);
    expect(sent['single_leave_status'], 'approved_lwp');
    expect(sent['id'], '12');
  });

  testWidgets('own profile reads the session, capture attendance starts disabled', (tester) async {
    final c = FakeClient(_cascade);
    await _show(tester, OwnProfileScreen(args: _args(c)));
    expect(find.text('Asha Admin'), findsOneWidget);
    expect(find.text('9999999999'), findsOneWidget);
    expect(c.log, isEmpty);
    Navigator.of(tester.element(find.text('Asha Admin'))).pop();
    await tester.pumpAndSettle();
    await _show(tester, CaptureAttendanceScreen(args: _args(c), isAdmin: true));
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Upload photos')).onPressed, isNull);
  });
  group('api migration (admin)', () {
    Future<void> sendFlow(WidgetTester tester, StatusClient c, MessageKind kind, String text, {String? subject}) async {
      await _show(tester, SendMessageScreen(args: _argsFor(c), kind: kind));
      await _pick(tester, 'Section', 'Primary');
      await _pick(tester, 'Standard', 'Std 5');
      await _pick(tester, 'Division', 'A');
      await tester.tap(find.text('Search students'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Select all'));
      await tester.pumpAndSettle();
      if (subject != null) await tester.enterText(find.widgetWithText(TextField, 'Subject'), subject);
      await tester.enterText(find.widgetWithText(TextField, kind == MessageKind.notification ? 'Notification text' : 'Message'), text);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Send to 1'));
      await tester.pumpAndSettle();
    }

    testWidgets('admin SMS goes to api/easy_com/send-sms-parents with the section id as grade', (tester) async {
      final c = StatusClient({
        ..._statusCascade,
        '/get_adminStudentList': _studentsWithContacts,
        '/api/easy_com/send-sms-parents': _r(200, {'success': true, 'message': '1 SMS sent.', 'data': {}, 'errors': null}),
      });
      await sendFlow(tester, c, MessageKind.sms, 'Holiday tomorrow');
      final sent = c.fieldsOf(c.calls('/api/easy_com/send-sms-parents').single);
      expect(sent['grade'], '1');
      expect(sent['standard'], '10');
      expect(sent['division'], '20');
      expect(sent['smsText'], 'Holiday tomorrow');
      expect(sent['sendsms[9811111111]'], 'on');
      expect(c.calls('/add_adminSendSmsAPI'), isEmpty);
    });

    testWidgets('admin SMS: 403 falls back to /add_adminSendSmsAPI once', (tester) async {
      final c = StatusClient({
        ..._statusCascade,
        '/get_adminStudentList': _studentsWithContacts,
        '/api/easy_com/send-sms-parents': _r(403, {'message': 'This action is unauthorized.'}),
        '/add_adminSendSmsAPI': _r(200, {'status': '1', 'message': 'Legacy sent'}),
      });
      await sendFlow(tester, c, MessageKind.sms, 'Hello');
      expect(c.calls('/api/easy_com/send-sms-parents'), hasLength(1));
      expect(c.calls('/add_adminSendSmsAPI'), hasLength(1));
      expect(c.fieldsOf(c.calls('/add_adminSendSmsAPI').single)['mobile_number[5]'], '9811111111');
    });

    testWidgets('admin SMS: a 422 shows the server message and is not retried on legacy', (tester) async {
      final c = StatusClient({
        ..._statusCascade,
        '/get_adminStudentList': _studentsWithContacts,
        '/api/easy_com/send-sms-parents': _r(422, {
          'success': false,
          'message': 'Number does not belong to the selected class.',
          'data': null,
          'errors': {'requested': 1, 'sent': 0, 'failed': [], 'skipped': []}
        }),
        '/add_adminSendSmsAPI': _r(200, {'status': '1', 'message': 'Legacy sent'}),
      });
      await sendFlow(tester, c, MessageKind.sms, 'Hello');
      expect(find.text('Number does not belong to the selected class.'), findsOneWidget);
      expect(c.calls('/add_adminSendSmsAPI'), isEmpty);
    });

    testWidgets('admin notification uses the new endpoint', (tester) async {
      final c = StatusClient({
        ..._statusCascade,
        '/get_adminStudentList': _studentsWithContacts,
        '/api/easy_com/send-notification-parents': _r(200, {'success': true, 'message': '1 notification(s) sent.', 'data': {}, 'errors': null}),
      });
      await sendFlow(tester, c, MessageKind.notification, 'PTM');
      final n = c.fieldsOf(c.calls('/api/easy_com/send-notification-parents').single);
      expect(n['notificationText'], 'PTM');
      expect(n['sendNotification[9811111111]'], 'on');
      expect(n['grade'], '1');
      expect(c.calls('/add_SendNotificationAPI'), isEmpty);
    });

    testWidgets('admin email uses the new endpoint', (tester) async {
      final c = StatusClient({
        ..._statusCascade,
        '/get_adminStudentList': _studentsWithContacts,
        '/api/easy_com/send-email-parents': _r(200, {'success': true, 'message': '1 email(s) sent.', 'data': {}, 'errors': null}),
      });
      await sendFlow(tester, c, MessageKind.email, 'Body text', subject: 'Subj');
      final e = c.fieldsOf(c.calls('/api/easy_com/send-email-parents').single);
      expect(e['subject'], 'Subj');
      expect(e['content'], 'Body text');
      expect(e['all_email'], 'k@x.test');
      expect(e['grade'], '1');
      expect(c.calls('/add_adminSendEmailAPI'), isEmpty);
    });

    Future<StatusClient> runDiscipline(WidgetTester tester, Map<String, (int, Object) Function(http.BaseRequest)> extra) async {
      final c = StatusClient({
        ..._statusCascade,
        '/allStudentListAPI': _r(200, {
          'status': '1',
          'data': [
            {'id': 5, 'student_name': 'Kiran Patel'}
          ]
        }),
        ...extra,
      });
      await _show(tester, DisciplineScreen(args: _argsFor(c)));
      await _pick(tester, 'Section', 'Primary');
      await _pick(tester, 'Standard', 'Std 5');
      await _pick(tester, 'Division', 'A');
      await _pick(tester, 'Student', 'Kiran Patel');
      await _pick(tester, 'Student performance', 'Good');
      await tester.enterText(find.widgetWithText(TextField, 'Message'), 'Polite');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('admin discipline posts to student-care/discipline with date_ and user_id', (tester) async {
      final c = await runDiscipline(tester, {
        '/student-care/discipline': _r(201, {'status': 1, 'message': 'Record created successfully.', 'data': {'id': 1}})
      });
      final sent = c.fieldsOf(c.calls('/student-care/discipline').single);
      expect(sent['student_id'], '5');
      expect(sent['dicipline'], 'Good');
      expect(sent['message'], 'Polite');
      expect(sent['user_id'], '7');
      expect(sent['sub_institute_id'], '3');
      expect(sent['syear'], '2025');
      expect(sent['date_'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(c.calls('/add_teacherStudentDisciplineAPI'), isEmpty);
    });

    testWidgets('admin discipline falls back to legacy when the new route is missing', (tester) async {
      final c = await runDiscipline(tester, {'/add_teacherStudentDisciplineAPI': _r(200, {'status': '1', 'message': 'Record Added'})});
      expect(c.calls('/student-care/discipline'), hasLength(1));
      expect(c.calls('/add_teacherStudentDisciplineAPI'), hasLength(1));
    });

    testWidgets('admin discipline: a 422 shows the first validation message, no legacy retry', (tester) async {
      final c = await runDiscipline(tester, {
        '/student-care/discipline': _r(422, {
          'status': 0,
          'message': 'Invalid record details.',
          'errors': {
            'date_': ['The date_ is not a valid date.']
          },
          'data': []
        }),
        '/add_teacherStudentDisciplineAPI': _r(200, {'status': '1', 'message': 'Record Added'}),
      });
      expect(find.text('The date_ is not a valid date.'), findsOneWidget);
      expect(c.calls('/add_teacherStudentDisciplineAPI'), isEmpty);
    });

    testWidgets('leave authorisation list reads api/leave/requests (status=pending) and shows the reason', (tester) async {
      final c = StatusClient({
        '/api/leave/requests': _r(200, {
          'status': 1,
          'data': [
            {'id': 12, 'employee_name': 'T. Mehta', 'leave_type': 'Casual', 'reason': 'Wedding', 'from_date': '2026-10-06', 'to_date': '2026-10-07', 'day_type': '1', 'status': 'pending'}
          ],
          'pagination': {'page': 1, 'per_page': 200, 'total': 1, 'last_page': 1}
        }),
      });
      await _show(tester, LeaveRequestsScreen(args: _argsFor(c)));
      expect(find.text('T. Mehta'), findsOneWidget);
      expect(find.text('Wedding'), findsOneWidget);
      final q = c.fieldsOf(c.calls('/api/leave/requests').single);
      expect(q['status'], 'pending');
      expect(q['token'], 't0k');
      expect(q['user_id'], '7');
      expect(c.calls('/show-leave-authorisation'), isEmpty);
    });

    testWidgets('leave authorisation list falls back to /show-leave-authorisation on failure', (tester) async {
      final c = StatusClient({
        '/api/leave/requests': _r(401, {'status': 0, 'message': 'Token not provided'}),
        '/show-leave-authorisation': _r(200, {
          'status': '1',
          'get_employee_leave_lists': [
            {'id': 3, 'employee_name': 'R. Shah', 'leave_type': 'Sick', 'comment': 'Fever', 'from_date': '2026-10-06', 'to_date': '2026-10-06'}
          ]
        }),
      });
      await _show(tester, LeaveRequestsScreen(args: _argsFor(c)));
      expect(find.text('R. Shah'), findsOneWidget);
      expect(c.calls('/show-leave-authorisation'), hasLength(1));
    });

    testWidgets('enquiry list uses api/admission_enquiry (no legacy call)', (tester) async {
      final c = StatusClient({
        '/api/admission_enquiry': _r(200, {
          'status_code': 1,
          'data': [
            {'id': 41, 'enquiry_no': '2025001', 'first_name': 'Neel', 'last_name': 'Shah', 'admission_standard': '34'}
          ]
        }),
      });
      await _show(tester, AdmissionListScreen(args: _argsFor(c), stage: AdmissionStage.enquiry));
      expect(find.text('1. Neel Shah'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(c.calls('/admission/admission_enquiry'), isEmpty);
    });

    testWidgets('confirmation list uses api/admission_registration', (tester) async {
      final c = StatusClient({
        '/api/admission_registration': _r(200, {
          'status': 1,
          'data': [
            {'id': 8, 'enquiry_no': '2025002', 'first_name': 'Riya', 'last_name': 'Jain', 'std_name': '3'}
          ]
        }),
      });
      await _show(tester, AdmissionListScreen(args: _argsFor(c), stage: AdmissionStage.confirmation));
      expect(find.text('1. Riya Jain'), findsOneWidget);
      expect(c.calls('/admission/admission_confirmation'), isEmpty);
    });

    testWidgets('registration list falls back to the legacy list when the new one is refused', (tester) async {
      final c = StatusClient({
        '/api/admission_registration': _r(403, {'message': 'Forbidden'}),
        '/admission/admission_registration': _r(200, {
          'status_code': 1,
          'data': [
            {'enquiry_no': '9', 'first_name': 'Old', 'last_name': 'Row'}
          ]
        }),
      });
      await _show(tester, AdmissionListScreen(args: _argsFor(c), stage: AdmissionStage.registration));
      expect(find.text('1. Old Row'), findsOneWidget);
      expect(c.calls('/admission/admission_registration'), hasLength(1));
    });

    testWidgets('enquiry create posts api/admission_enquiry with the next enquiry_no; a 422 is shown, not retried', (tester) async {
      final c = StatusClient({
        '/api/admission_enquiry': (r) => r.method == 'GET'
            ? (200, {
                'status_code': 1,
                'data': [
                  {'id': 1, 'enquiry_no': '2025003'},
                  {'id': 2, 'enquiry_no': '2025007'},
                ]
              })
            : (422, {
                'status_code': 0,
                'message': 'sub_institute_id is required',
                'data': [],
                'errors': {
                  'sub_institute_id': ['sub_institute_id is required']
                }
              }),
        '/admission/admission_enquiry': _r(200, {'status': '1', 'message': 'legacy'}),
      });
      await _show(tester, AdmissionFormScreen(args: _argsFor(c), stage: AdmissionStage.enquiry));
      await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Neel');
      await tester.enterText(find.widgetWithText(TextField, 'Mobile'), '9000000001');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final post = c.calls('/api/admission_enquiry').firstWhere((r) => r.method == 'POST');
      final sent = c.fieldsOf(post);
      expect(sent['enquiry_no'], '2025008');
      expect(sent['first_name'], 'Neel');
      expect(sent['mobile'], '9000000001');
      expect(sent['created_by'], '7');
      expect(sent['sub_institute_id'], '3');
      expect(sent['syear'], '2025');
      expect(find.text('sub_institute_id is required'), findsOneWidget);
      expect(c.calls('/admission/admission_enquiry'), isEmpty);
    });

    testWidgets('enquiry edit PUTs the numeric id to api/admission_enquiry/{id}', (tester) async {
      final c = StatusClient({
        '/api/admission_enquiry/41': _r(200, {'status_code': 1, 'message': 'Updated successfully', 'data': {}}),
      });
      await _show(tester, AdmissionFormScreen(args: _argsFor(c), stage: AdmissionStage.enquiry, row: const {'id': 41, 'enquiry_no': '2025001', 'first_name': 'Neel', 'mobile': '9000000001'}));
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      final put = c.calls('/api/admission_enquiry/41').single;
      expect(put.method, 'PUT');
      expect(c.fieldsOf(put)['first_name'], 'Neel');
      expect(c.fieldsOf(put)['user_id'], '7');
      expect(c.log.where((r) => r.url.path.startsWith('/admission/')), isEmpty);
    });

    testWidgets('registration edit PUTs api/admission_registration/{id}', (tester) async {
      final c = StatusClient({
        '/api/admission_registration/8': _r(200, {'status_code': '1', 'message': 'Added successfully'}),
      });
      await _show(tester, AdmissionFormScreen(args: _argsFor(c), stage: AdmissionStage.registration, row: const {'id': 8, 'enquiry_no': '2025002', 'first_name': 'Riya', 'mobile': '9000000002'}));
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(c.calls('/api/admission_registration/8').single.method, 'PUT');
      expect(c.log.where((r) => r.url.path.startsWith('/admission/')), isEmpty);
    });

    testWidgets('enquiry edit falls back to the legacy PUT (enquiry number) when the new route refuses', (tester) async {
      final c = StatusClient({
        '/api/admission_enquiry/41': _r(404, {'status_code': 0, 'message': 'Record not found', 'data': []}),
        '/admission/admission_enquiry/2025001': _r(200, {'status': '1', 'message': 'legacy updated'}),
      });
      await _show(tester, AdmissionFormScreen(args: _argsFor(c), stage: AdmissionStage.enquiry, row: const {'id': 41, 'enquiry_no': '2025001', 'first_name': 'Neel', 'mobile': '9000000001'}));
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(c.calls('/admission/admission_enquiry/2025001'), hasLength(1));
    });
  });
}
