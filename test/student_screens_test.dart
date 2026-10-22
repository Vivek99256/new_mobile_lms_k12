import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:new_mobile_lms_k12/core/feed.dart';
import 'package:new_mobile_lms_k12/core/legacy_api.dart';
import 'package:new_mobile_lms_k12/core/session.dart';
import 'package:new_mobile_lms_k12/screens/screen_registry.dart';
import 'package:new_mobile_lms_k12/screens/student/quiz.dart';
import 'package:new_mobile_lms_k12/screens/student/student_common.dart';
import 'package:new_mobile_lms_k12/screens/student/student_screens.dart';
import 'package:new_mobile_lms_k12/ui/theme.dart';

class Call {
  Call(this.method, this.url, this.fields);
  final String method;
  final Uri url;
  final Map<String, String> fields;
}

/// Records every request and answers from [handler] (path -> JSON body).
class FakeClient extends http.BaseClient {
  FakeClient(this.handler);
  final Map<String, dynamic> Function(Call) handler;
  final calls = <Call>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final fields = request is http.MultipartRequest ? Map<String, String>.from(request.fields) : <String, String>{...request.url.queryParameters};
    final call = Call(request.method, request.url, fields);
    calls.add(call);
    final body = utf8.encode(jsonEncode(handler(call)));
    return http.StreamedResponse(Stream.value(body), 200, headers: {'content-type': 'application/json'});
  }
}

Session _session() => Session(
      token: 'tok', userId: 9, subInstituteId: 3, clientId: 1, userProfileId: 6,
      userProfileName: 'Student', name: 'Asha Rao', email: 'a@x', schoolName: 'S', mobileSyear: '2026',
      raw: const {'std_name': 'Std 5', 'mobile': '9999999999', 'standard_id': '5'},
    );

ScreenArgs _args(FakeClient c, {String label = 'Screen', String api = '', String name = ''}) => ScreenArgs(
      FeedItem(label: label, iconUrl: '', api: api, apiParam: '', screenName: name, renderType: 'native', webUrl: ''),
      _session(),
      LegacyApi(_session(), client: c),
    );

Future<void> _pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(900, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: buildTheme(), home: w));
  await t.pumpAndSettle();
}

void main() {
  test('registry covers every student screen_name and its aliases', () {
    for (final k in ['home_work', 'assignment', 'photos_gallery', 'video_gallery', 'fees', 'capture_photos', 'reach_us', 'student_consent']) {
      expect(studentScreens.containsKey(k), isTrue, reason: k);
    }
    expect(studentScreens.length, greaterThanOrEqualTo(44));
  });

  test('helpers format times, entities and relative dates', () {
    expect(time12('14:05:00'), '2:05 PM');
    expect(time12('00:30'), '12:30 AM');
    expect(decodeEntities('&lt;b&gt;x&lt;/b&gt; &#65; &amp;'), '<b>x</b> A &');
    expect(relativeTime('2026-10-06 10:00:00', now: DateTime(2026, 10, 6, 10, 30)), '30 min ago');
    expect(relativeTime('2026-10-04 10:00:00', now: DateTime(2026, 10, 6, 10, 30)), '04 Oct 26 10:00 AM');
  });

  testWidgets('homework list sends the old request fields and shows the cards', (t) async {
    final c = FakeClient((_) => {
          'status': '1',
          'data': [
            {'title': 'Fractions', 'description': 'Do page 4 https://x.test/a', 'date': '2026-10-05', 'subject_name': 'Maths', 'file_name': '', 'user_image': ''},
          ],
        });
    await _pump(t, studentScreens['home_work']!(_args(c, label: 'Homework', api: 'https://erp.test/studentHomeworkAssignmentAPI')));
    expect(find.text('Fractions'), findsOneWidget);
    expect(find.text('Maths'), findsOneWidget);
    final call = c.calls.single;
    expect(call.url.toString(), 'https://erp.test/studentHomeworkAssignmentAPI');
    expect(call.fields['action'], 'Homework');
    expect(call.fields['student_id'], '9');
    expect(call.fields['syear'], '2026');
    expect(call.fields['token'], 'tok');
  });

  testWidgets('homework shows an empty state when the server returns status 0', (t) async {
    final c = FakeClient((_) => {'status': '0', 'message': 'No record'});
    await _pump(t, studentScreens['assignment']!(_args(c)));
    expect(find.text('No homework has been assigned.'), findsOneWidget);
  });

  testWidgets('a failed list shows the server message with a retry that reloads', (t) async {
    var n = 0;
    final c = FakeClient((_) => ++n == 1 ? {'status': '0', 'message': 'Not allowed here'} : {'status': '1', 'data': []});
    await _pump(t, studentScreens['child_remark']!(_args(c)));
    expect(find.text('Not allowed here'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('No remarks have been recorded.'), findsOneWidget);
    expect(c.calls.length, 2);
  });

  testWidgets('parent communication validates, submits once and refreshes the list', (t) async {
    final c = FakeClient((call) => call.url.path.endsWith('add_communicationAPI')
        ? {'status': '1', 'message': 'Sent to school'}
        : {'status_code': '1', 'data': [{'title': 'Old question', 'message': 'hello', 'created_at': '2026-10-01 10:00:00', 'reply': 'Answered', 'reply_by': 'Mrs K', 'reply_on': '2026-10-02'}]});
    await _pump(t, studentScreens['parent_communication']!(_args(c)));
    expect(find.text('Old question'), findsOneWidget);
    expect(find.text('Reply: Answered'), findsOneWidget);

    await t.tap(find.text('Submit'));
    await t.pumpAndSettle();
    expect(find.text('Please enter a subject.'), findsOneWidget);
    expect(c.calls.where((x) => x.url.path.endsWith('add_communicationAPI')), isEmpty);

    await t.enterText(find.widgetWithText(TextField, 'Subject'), 'Fee query');
    await t.enterText(find.widgetWithText(TextField, 'Ask question'), 'When is the due date?');
    await t.tap(find.text('Submit'));
    await t.pumpAndSettle();
    final posts = c.calls.where((x) => x.url.path.endsWith('add_communicationAPI')).toList();
    expect(posts, hasLength(1));
    expect(posts.single.fields['title'], 'Fee query');
    expect(posts.single.fields['message'], 'When is the due date?');
    expect(posts.single.fields['student_id'], '9');
  });

  testWidgets('leave form requires every field before sending', (t) async {
    final c = FakeClient((_) => {'status': '1', 'data': []});
    await _pump(t, studentScreens['leave_application']!(_args(c)));
    await t.tap(find.text('Apply leave'));
    await t.pumpAndSettle();
    expect(find.text('Please select from date.'), findsOneWidget);
    expect(c.calls.where((x) => x.method == 'POST' && x.url.path.contains('add_leave_application')), isEmpty);
    await t.tap(find.text('Status'));
    await t.pumpAndSettle();
    expect(find.text('You have not applied for any leave yet.'), findsOneWidget);
  });

  testWidgets('attendance calendar counts present, absent and holiday for the month', (t) async {
    final now = DateTime.now();
    String d(int day) => '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final c = FakeClient((_) => {
          'status': '1',
          'data': {
            'attendance_data': [
              {'attendance_date': d(1), 'attendance_code': 'P'},
              {'attendance_date': d(2), 'attendance_code': 'P'},
              {'attendance_date': d(3), 'attendance_code': 'A'},
            ],
            'calendar_data': {'holiday': [{'school_date': d(4)}]},
          },
        });
    await _pump(t, studentScreens['student_attendance']!(_args(c, label: 'Attendance', api: 'https://erp.test/att')));
    Finder tile(String label) => find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
    expect(find.descendant(of: tile('Present'), matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: tile('Absent'), matching: find.text('1')), findsOneWidget);
    expect(find.descendant(of: tile('Holiday'), matching: find.text('1')), findsOneWidget);
    expect(c.calls.single.fields['mobile_no'], '9999999999');
  });

  testWidgets('school information renders HTML cards and sends its action', (t) async {
    final c = FakeClient((_) => {'status': '1', 'data': [{'title': 'Our story', 'description': '<p>Founded in <b>1990</b></p>'}]});
    await _pump(t, studentScreens['rules']!(_args(c, label: 'School rules', api: 'https://erp.test/schoolDetailAPI')));
    expect(find.text('Our story'), findsOneWidget);
    expect(find.textContaining('Founded in', findRichText: true), findsOneWidget);
    expect(c.calls.single.fields['action'], 'Rules');
  });

  testWidgets('timetable switches days and shows start and end times', (t) async {
    final c = FakeClient((_) => {
          'status': '1',
          'data': [
            {'week_day': 'Mon', 'subject_name': 'Maths', 'teacher_name': 'Mr Shah', 'period_name': '1', 'start_time': '09:00', 'end_time': '09:45'},
            {'week_day': 'Tue', 'subject_name': 'Science', 'teacher_name': 'Ms Rao', 'period_name': '', 'start_time': '10:00', 'end_time': '10:45'},
          ],
        });
    await _pump(t, studentScreens['time_table']!(_args(c, api: 'https://erp.test/tt')));
    await t.tap(find.text('Mon'));
    await t.pumpAndSettle();
    expect(find.text('Maths'), findsOneWidget);
    expect(find.text('9:00 AM - 9:45 AM'), findsOneWidget);
    await t.tap(find.text('Tue'));
    await t.pumpAndSettle();
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('Maths'), findsNothing);
  });

  testWidgets('quiz: pick an answer, submit, and see the result', (t) async {
    final paper = {'question_paper_id': '77', 'paper_name': 'Unit test', 'time_allowed': '0'};
    final c = FakeClient((call) {
      if (call.url.path.endsWith('studentQuestionPaperAPI')) {
        return {
          'status': '1',
          'data': {
            'p': {
              'q1': {
                'id': 11,
                'question_title': '&lt;p&gt;What is 2+2?&lt;/p&gt;',
                'Answer': [
                  {'id': 1, 'answer': '3', 'correct_answer': '0'},
                  {'id': 2, 'answer': '4', 'correct_answer': '1'},
                ],
              },
            },
          },
        };
      }
      return {'status': '1', 'message': 'ok'};
    });
    final a = _args(c);
    await _pump(t, Builder(builder: (ctx) => Scaffold(body: TextButton(onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => QuizScreen(args: a, paper: paper))), child: const Text('go')))));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.textContaining('What is 2+2?', findRichText: true), findsOneWidget);
    await t.tap(find.text('4', findRichText: true));
    await t.pumpAndSettle();
    await t.tap(find.text('Submit'));
    await t.pumpAndSettle();
    final save = c.calls.firstWhere((x) => x.url.path.endsWith('studentQuestionPaperSaveAPI'));
    expect(save.fields['question_list'], '11');
    expect(save.fields['given_ans'], '2');
    expect(save.fields['original_ans'], '2');
    expect(save.fields['question_paper_id'], '77');
    expect(find.text('Result of practice'), findsOneWidget);
    expect(find.text('You chose the right answer'), findsOneWidget);
  });

  group('api-migration (new endpoint first, one legacy fallback)', () {
    testWidgets('result PDFs call the new path and show the links', (t) async {
      final c = FakeClient((_) => {
            'success': true,
            'message': 'ok',
            'data': {'title': 'Term 1 result', 'pdf_link': 'https://x.test/r.pdf'},
          });
      await _pump(t, studentScreens['result_pdf']!(_args(c, label: 'Results')));
      expect(find.text('Term 1 result'), findsOneWidget);
      expect(c.calls.single.url.path, '/api/result/cbse-1t5-result/pdf');
      expect(c.calls.single.fields['student_id'], '9');
    });

    testWidgets('result PDFs: 404 "No Record" is an empty state and does not fall back', (t) async {
      final c = FakeClient((_) => {'success': false, 'message': 'No Record', 'data': null});
      await _pump(t, studentScreens['result_pdf']!(_args(c)));
      expect(find.text('No results have been published for this term.'), findsOneWidget);
      expect(c.calls.map((x) => x.url.path), ['/api/result/cbse-1t5-result/pdf']);
    });

    testWidgets('result PDFs fall back to the legacy endpoint when the new one fails', (t) async {
      final c = FakeClient((call) => call.url.path.startsWith('/api/')
          ? {'success': false, 'message': 'Academic Term Date Expired'}
          : {'status': '1', 'data': [{'title': 'Legacy result', 'pdf_link': 'https://x.test/l.pdf'}]});
      await _pump(t, studentScreens['result_pdf']!(_args(c)));
      expect(find.text('Legacy result'), findsOneWidget);
      expect(c.calls.map((x) => x.url.path), ['/api/result/cbse-1t5-result/pdf', '/studentResultPDFAPI']);
    });

    testWidgets('leaderboard maps the new learner summary onto the three tiles', (t) async {
      final c = FakeClient((_) => {
            'success': true,
            'data': {'has_data': true, 'learner': {'total_points': 120, 'rank': 3, 'class_size': 30, 'medal': 'Silver'}},
          });
      await _pump(t, studentScreens['leaderboard']!(_args(c)));
      expect(c.calls.single.url.path, '/api/lms/leaderboard');
      expect(find.text('120'), findsOneWidget);
      expect(find.text('#3 of 30'), findsOneWidget);
      expect(find.text('Silver'), findsOneWidget);
    });

    testWidgets('leaderboard has_data:false is the empty state, no fallback', (t) async {
      final c = FakeClient((_) => {'success': true, 'data': {'has_data': false}});
      await _pump(t, studentScreens['leaderboard']!(_args(c)));
      expect(find.text('The leaderboard is empty for now.'), findsOneWidget);
      expect(c.calls, hasLength(1));
    });

    testWidgets('leaderboard falls back to studentLeaderBoardAPI when the new call is refused', (t) async {
      final c = FakeClient((call) => call.url.path.startsWith('/api/')
          ? {'success': false, 'message': 'Forbidden'}
          : {'status': '1', 'data': {'1': {'type': 'My Points', 'total_points': 7}, '2': {'type': 'My Leaderboard', 'student_rank': '#2 In Site'}}});
      await _pump(t, studentScreens['leaderboard']!(_args(c)));
      expect(c.calls.map((x) => x.url.path), ['/api/lms/leaderboard', '/studentLeaderBoardAPI']);
      expect(find.text('#2 In Site'), findsOneWidget);
    });

    testWidgets('social collaborative lists mine=1 and loads the thread on demand', (t) async {
      final c = FakeClient((call) {
        if (call.url.path == '/api/lms/social-collaborative') {
          return {
            'success': true,
            'data': [{'id': 5, 'title': 'Why is the sky blue?', 'description': 'asking', 'created_at': '2026-10-01', 'comment_count': 1, 'attachment_url': null}],
            'meta': {'current_page': 1, 'last_page': 1},
          };
        }
        return {
          'success': true,
          'data': {'id': 5, 'comments': [{'id': 1, 'message': 'Rayleigh scattering', 'created_at': '2026-10-02', 'author': {'name': 'Mrs K'}}]},
        };
      });
      await _pump(t, studentScreens['social_collabrative']!(_args(c)));
      expect(find.text('Why is the sky blue?'), findsOneWidget);
      expect(c.calls.first.url.queryParameters['mine'], '1');
      await t.tap(find.text('View replies (1)'));
      await t.pumpAndSettle();
      expect(c.calls.last.url.path, '/api/lms/social-collaborative/5');
      expect(find.text('Rayleigh scattering'), findsOneWidget);
      expect(find.textContaining('By Mrs K'), findsOneWidget);
    });

    testWidgets('social collaborative falls back to studentSocialCollabrativeAPI', (t) async {
      final c = FakeClient((call) => call.url.path.startsWith('/api/')
          ? {'success': false, 'message': 'Academic Term Date Expired'}
          : {'status': '1', 'data': {'8': {'title': 'Old doubt', 'ConversationData': []}}});
      await _pump(t, studentScreens['social_collabrative']!(_args(c)));
      expect(find.text('Old doubt'), findsOneWidget);
      expect(c.calls.map((x) => x.url.path), ['/api/lms/social-collaborative', '/studentSocialCollabrativeAPI']);
    });

    testWidgets('WRT exam dropdown uses exam-master/dropdown (id, name)', (t) async {
      final c = FakeClient((_) => {'success': true, 'data': [{'id': 4, 'name': 'Unit Test 1'}]});
      await _pump(t, studentScreens['wrt_progress']!(_args(c)));
      expect(c.calls.single.url.path, '/api/result/exam-master/dropdown');
      expect(c.calls.single.url.queryParameters['standard_id'], '5');
      await t.tap(find.text('Exam type'));
      await t.pumpAndSettle();
      expect(find.text('Unit Test 1'), findsWidgets);
    });

    testWidgets('WRT exam dropdown falls back to the legacy list and reads its capitalised keys', (t) async {
      final c = FakeClient((call) => call.url.path.startsWith('/api/')
          ? {'success': false, 'message': 'Unauthorized'}
          : {'data': [{'Id': 4, 'ExamTitle': 'Legacy Exam'}]});
      await _pump(t, studentScreens['wrt_progress']!(_args(c)));
      expect(c.calls.map((x) => x.url.path), ['/api/result/exam-master/dropdown', '/result/exam_master']);
      await t.tap(find.text('Exam type'));
      await t.pumpAndSettle();
      expect(find.text('Legacy Exam'), findsWidgets);
    });

    testWidgets('gallery and virtual classroom use the real legacy paths when the tile has none', (t) async {
      final c = FakeClient((_) => {'status': '1', 'data': []});
      await _pump(t, studentScreens['photos_gallery']!(_args(c)));
      await _pump(t, studentScreens['virtual_classroom']!(_args(c)));
      expect(c.calls.map((x) => x.url.path), ['/studentPhotoVideoGalleryAPI', '/studentVirtualClassroomAPI']);
    });
  });
}
