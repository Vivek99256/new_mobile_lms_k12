import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:new_mobile_lms_k12/core/api_client.dart';
import 'package:new_mobile_lms_k12/core/auth_controller.dart';
import 'package:new_mobile_lms_k12/core/session.dart';
import 'package:new_mobile_lms_k12/ui/dashboard/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session session(String profile) => Session(
      token: 't', userId: 9, subInstituteId: 1, clientId: 1, userProfileId: 1,
      userProfileName: profile, name: 'A', email: 'a@x', schoolName: 'S',
    );

void main() {
  test('roleOf maps profiles to dashboards', () {
    expect(roleOf('Student'), DashboardRole.student);
    expect(roleOf('Teacher'), DashboardRole.teacher);
    expect(roleOf('Admin'), DashboardRole.admin);
    expect(roleOf('Principal'), DashboardRole.admin);
  });

  testWidgets('admin dashboard renders KPIs and charts from the summary payload', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final client = MockClient((req) async {
      expect(req.url.path, '/api/admin-dashboard/summary');
      return http.Response(
        jsonEncode({
          'status': '1',
          'summary': {'total_students': 1240, 'total_staff': 80, 'fees_collected_today': 125000.5},
          'fee_collection_trend': [
            {'label': 'Mon', 'amount': 1000}, {'label': 'Tue', 'amount': 0},
          ],
          'students_by_class': [{'standard_name': 'Class 1', 'students': 40}],
          'recent_fee_receipts': [{'student_name': 'Asha Rao', 'receipt_no': '12', 'receiptdate': '2026-10-05', 'amount': 500}],
          'upcoming_birthdays': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final auth = AuthController(ApiClient(client: client))..session = session('Admin');
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('School overview'), findsOneWidget);
    expect(find.text('1,240'), findsOneWidget);
    expect(find.text('₹1,25,000.50'), findsOneWidget);
    expect(find.text('Class 1'), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('No birthdays in the next 7 days.'), findsOneWidget);
  });

  testWidgets('shows last saved data when the refresh fails', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dashboard_9_admin': jsonEncode({
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': {'summary': {'total_students': 7}},
      }),
    });
    final client = MockClient((_) async => http.Response('boom', 500));
    final auth = AuthController(ApiClient(client: client))..session = session('Admin');
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    expect(find.textContaining('last saved data'), findsOneWidget);
  });
}
