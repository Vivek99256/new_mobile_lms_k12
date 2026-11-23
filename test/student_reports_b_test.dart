import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:new_mobile_lms_k12/core/feed.dart';
import 'package:new_mobile_lms_k12/core/legacy_api.dart';
import 'package:new_mobile_lms_k12/core/session.dart';
import 'package:new_mobile_lms_k12/presentation/admin/student_reports/b_daywise_screen.dart';
import 'package:new_mobile_lms_k12/presentation/admin/student_reports/b_health_report_screen.dart';
import 'package:new_mobile_lms_k12/presentation/admin/student_reports/b_request_report_screen.dart';
import 'package:new_mobile_lms_k12/screens/admin/student_reports_b.dart';
import 'package:new_mobile_lms_k12/screens/screen_registry.dart';

class _Fake extends http.BaseClient {
  _Fake(this.routes);
  final Map<String, Object?> routes;
  final log = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    log.add(request);
    final body = routes[request.url.path] ?? {'status': '0', 'message': 'no route ${request.url.path}', 'data': []};
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200, headers: {'content-type': 'application/json'});
  }
}

ScreenArgs _args(_Fake c) {
  final session = Session(
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
    raw: const {},
  );
  return ScreenArgs(
    const FeedItem(label: 'Report', iconUrl: '', api: '', apiParam: '', screenName: 't_x', renderType: 'native', webUrl: ''),
    session,
    LegacyApi(session, client: c),
  );
}

Future<void> _show(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  test('registry covers the six menus', () {
    expect(studentReportsB.keys, containsAll([
      'student/daywise_student_attendance',
      'student/monthwise_student_attendance',
      'student/yearly_student_attendance',
      'student/report/student_request_report',
      'student/report/student_health_report',
      'student/student_certificate_report',
    ]));
  });

  testWidgets('daywise attendance shows class cards and totals', (tester) async {
    final c = _Fake({
      '/student/show_daywise_student_attendance': {
        'status': '1',
        'attendance_data': [
          {'standard_name': 'Std 5/A', 'BOY': '10', 'GIRL': '12', 'TBP': '9', 'TGP': '11', 'TBA': '1', 'TGA': '1'},
          {'standard_name': 'Std 6/B', 'BOY': '8', 'GIRL': '7', 'TBP': '0', 'TGP': '0', 'TBA': '0', 'TGA': '0'},
        ],
      },
    });
    await _show(tester, BDaywiseAttendanceScreen(args: _args(c)));
    expect(find.text('Std 5/A'), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('Not taken'), findsOneWidget);
    final req = c.log.first as http.MultipartRequest;
    expect(req.fields['taken'], '');
    expect(req.fields['date'], isNotEmpty);
  });

  testWidgets('request report lists requests with status', (tester) async {
    final c = _Fake({
      '/student/student_request_report/create': {
        'status': '1',
        'result_report': [
          {'student_name': 'Riya Shah', 'enrollment_no': '1020', 'standard': '6', 'division': 'C', 'REQUEST': 'Name change', 'REASON': 'Spelling', 'STATUS': 'Approved'},
        ],
      },
    });
    await _show(tester, BRequestReportScreen(args: _args(c)));
    expect(find.text('Riya Shah'), findsOneWidget);
    expect(find.text('Name change'), findsOneWidget);
    expect(find.text('Approved'), findsWidgets);
  });

  testWidgets('health report uses the server headers for the card lines', (tester) async {
    final c = _Fake({
      '/student/show_student_health_report': {
        'status': '1',
        'headers': {'student_name': 'Student Name', 'doctor_name': 'Doctor Name', 'date': 'Date'},
        'health_data': [
          {'student_id': 4, 'student_name': 'Riya Shah', 'doctor_name': 'Dr. Mehta', 'date': '2026-11-17'},
        ],
      },
    });
    await _show(tester, BHealthReportScreen(args: _args(c)));
    expect(find.text('Riya Shah'), findsOneWidget);
    expect(find.text('Dr. Mehta'), findsOneWidget);
    expect(find.text('17 Nov 2026'), findsOneWidget);
  });
}
