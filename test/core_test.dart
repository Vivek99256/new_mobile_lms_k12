import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:new_mobile_lms_k12/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_mobile_lms_k12/core/feed.dart';
import 'package:new_mobile_lms_k12/core/native_target.dart';
import 'package:new_mobile_lms_k12/core/page_service.dart';
import 'package:new_mobile_lms_k12/core/session.dart';
import 'package:new_mobile_lms_k12/ui/native_screens.dart';

void main() {
  final feed = [
    {
      'main_title': 'Student',
      'menu_type': 'Menu',
      'main_itle_color': '#09518c',
      'main_title_background_image': 'https://x/bg.png',
      'contents': [
        {'sub_title': 'Homework', 'sub_title_icon': 'https://x/i.png', 'sub_title_api': 'https://erp/hw', 'sub_title_api_param': '', 'screen_name': 'home_work', 'render_type': 'native', 'web_url': ''},
        {'sub_title': 'Add House', 'screen_name': 'add_house', 'render_type': 'webview', 'web_url': 'https://k12.example.com/mobile/custom/add-house'},
      ],
    },
    {'main_title': 'Empty', 'contents': []},
    {'main_title': 'Banner', 'menu_type': 'Banner', 'api': 'x', 'screen_name': 'promo'},
  ];

  group('FeedRepository.parse', () {
    test('keeps the old app\'s sections, colours and tiles', () {
      final s = FeedRepository.parse(feed);
      expect(s.map((e) => e.title), ['Student', 'Banner']); // empty sections dropped
      expect(s.first.colorHex, '#09518c');
      expect(s.first.backgroundImage, 'https://x/bg.png');
      final hw = s.first.items.first;
      expect(hw.label, 'Homework');
      expect(hw.screenName, 'home_work');
      expect(hw.api, 'https://erp/hw');
      expect(hw.iconUrl, 'https://x/i.png');
      expect(s.last.isBanner, isTrue);
      expect(s.last.items.single.screenName, 'promo');
    });

    test('empty or malformed feed means no sections', () {
      expect(FeedRepository.parse(null), isEmpty);
      expect(FeedRepository.parse(const []), isEmpty);
    });

    test('search index carries the section', () {
      final idx = buildFeedIndex(FeedRepository.parse(feed));
      expect(idx.first.section.title, 'Student');
      expect(idx.map((e) => e.item.label), contains('Add House'));
    });

    test('students use the student feed', () {
      expect(FeedRepository.isStudentProfile('Student'), isTrue);
      expect(FeedRepository.isStudentProfile('Teacher'), isFalse);
    });
  });

  group('FeedRepository.load (mobile/bootstrap)', () {
    final session = Session(
      token: 'jwt', userId: 9, subInstituteId: 1, clientId: 1, userProfileId: 3,
      userProfileName: 'Teacher', name: 'T', email: 't@x', schoolName: 'S',
    );
    // The home menu now comes only from the menus ticked Mobile in Roles & Access (`role_menu`).
    final bootstrap = {
      'success': true,
      'data': {
        'user': {'id': 9},
        'menu': [], // the old mobile_homescreen menu is no longer shown
        'role_menu': {
          'menus': [],
          'tree': [
            {
              'id': 1, 'title': 'Institute ERP', 'level': 1, 'mobile_enabled': false, 'link': 'javascript:void(0);', 'path': null,
              'children': [
                {
                  'id': 173, 'title': 'Admission', 'level': 2, 'mobile_enabled': false, 'link': 'javascript:void(0);', 'path': null,
                  'children': [
                    {'id': 174, 'title': 'Admission Inquiry', 'level': 3, 'mobile_enabled': true, 'link': '/admissions/admission_enquiry/', 'path': '/admissions/admission_enquiry/', 'icon': null, 'children': []},
                    {'id': 999, 'title': 'No Screen Yet', 'level': 3, 'mobile_enabled': true, 'link': 'javascript:void(0);', 'path': null, 'children': []},
                  ],
                },
              ],
            },
          ],
        },
      },
    };

    test('builds the home menu from role_menu of GET /api/mobile/bootstrap with the bearer token', () async {
      late http.Request seen;
      final api = ApiClient(client: MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode(bootstrap), 200);
      }));
      final sections = await FeedRepository(api).load(session);
      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/mobile/bootstrap');
      expect(seen.headers['Authorization'], 'Bearer jwt');
      expect(sections.single.title, 'Admission'); // the level-2 module names the section
      final it = sections.single.items.single; // a menu with no native screen and no path is skipped
      expect(it.label, 'Admission Inquiry');
      expect(it.screenName, '/admissions/admission_enquiry/');
    });

    test('an old server without the route falls back to the legacy menu call', () async {
      final paths = <String>[];
      final api = ApiClient(client: MockClient((req) async {
        paths.add(req.url.path);
        if (req.url.path == '/api/mobile/bootstrap') return http.Response(jsonEncode({'message': 'not found'}), 404);
        return http.Response(jsonEncode({'status': '1', 'data': feed}), 200);
      }));
      final sections = await FeedRepository(api).load(session);
      expect(paths, ['/api/mobile/bootstrap', '/teacher_homescreen']);
      expect(sections.first.title, 'Student');
    });

    test('an auth failure is surfaced, not retried on the legacy endpoint', () async {
      final paths = <String>[];
      final api = ApiClient(client: MockClient((req) async {
        paths.add(req.url.path);
        return http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401);
      }));
      await expectLater(FeedRepository(api).load(session), throwsA(isA<ApiException>()));
      expect(paths, ['/api/mobile/bootstrap']);
    });
  });

  group('NativeTarget.fromWebUrl', () {
    test('maps /mobile/custom/<slug>', () {
      expect(NativeTarget.fromWebUrl('https://k12.example.com/mobile/custom/mark-attendance'),
          const NativeTarget.page('mark-attendance'));
      expect(NativeTarget.fromWebUrl('https://x.com/user/page'), isNull);
    });
  });

  test('Session.fromLogin reads the login payload', () {
    final s = Session.fromLogin({
      'status': 1,
      'data': {
        'id': 5, 'sub_institute_id': 47, 'client_id': 2, 'user_profile_id': 3,
        'user_profile': 'Teacher', 'first_name': 'Asha', 'last_name': 'Rao',
        'email': 'a@x.in', 'user_token': 'jwt', 'school_name': 'S', 'logo': 'l.png',
      },
    }, 'fallback@x.in', 'https://h');
    expect(s.token, 'jwt');
    expect(s.name, 'Asha Rao');
    expect(s.initials, 'AR');
    expect(Session.fromJson(s.toJson()).userId, 5);
  });

  test('formatIndian groups like Indian currency', () {
    expect(formatIndian(1234567), '12,34,567');
    expect(formatIndian(999), '999');
    expect(formatIndian(1234.5, decimals: 2), '1,234.50');
  });

  test('resolveTemplate and resolveField', () {
    expect(resolveTemplate('get/{{id}}/x', {'id': '7'}), 'get/7/x');
    expect(resolveField({'a': {'b': 3}}, 'a.b'), 3);
    expect(resolveField({'a': 1}, 'a.b'), isNull);
  });
}
