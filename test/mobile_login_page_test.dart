import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:new_mobile_lms_k12/core/api_client.dart';
import 'package:new_mobile_lms_k12/core/mobile_auth.dart';
import 'package:new_mobile_lms_k12/ui/mobile_login_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'a cooldown response still lets the user enter the existing OTP',
    (tester) async {
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        storageChannel,
        (_) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          storageChannel,
          null,
        );
      });

      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/mobile-auth/status') {
            return http.Response(
              jsonEncode({
                'status': 1,
                'data': {'state': 'activate'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'status': 0,
              'message':
                  'Please wait a few seconds before asking for another code.',
            }),
            429,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await tester.pumpWidget(
        Provider<MobileAuthService>.value(
          value: MobileAuthService(api),
          child: const MaterialApp(home: MobileLoginPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verify your number'), findsOneWidget);
      expect(find.text('6 digit code'), findsOneWidget);
      expect(
        find.text('Please wait a few seconds before asking for another code.'),
        findsOneWidget,
      );
    },
  );
}
