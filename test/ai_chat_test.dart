import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:new_mobile_lms_k12/core/legacy_api.dart';
import 'package:new_mobile_lms_k12/core/session.dart';
import 'package:new_mobile_lms_k12/presentation/ai_chat/ai_chat_controller.dart';

class _Fake extends http.BaseClient {
  _Fake(this.reply, {this.status = 200});
  final Object? reply;
  final int status;
  final sent = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request);
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(reply))), status, headers: {'content-type': 'application/json'});
  }
}

LegacyApi _api(_Fake c) => LegacyApi(
      Session(
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
      ),
      client: c,
    );

void main() {
  test('a reply becomes a headline, sections and follow-ups, and the thread id is kept for the next turn', () async {
    final fake = _Fake({
      'success': true,
      'message': 'There are 20 students in total.',
      'data': {
        'conversation': {'id': 42},
        'answer': {
          'headline': 'There are 20 students in total.',
          'sections': [
            {'type': 'text', 'title': 'Detail', 'body': 'Across all classes.'},
            {
              'type': 'list',
              'title': 'By class',
              'items': [
                'Class 1: 10',
                {'standard': 'Class 2', 'count': 10},
              ],
            },
          ],
          'actions': [],
          'follow_ups': ['Show boys and girls', ''],
        },
      },
    });
    final c = AiChatController(_api(fake));
    await c.send('How many students?');

    expect(c.messages.first.mine, isTrue);
    final bot = c.messages.last;
    expect(bot.headline, 'There are 20 students in total.');
    expect(bot.sections.length, 2);
    expect(bot.sections[1].items, ['Class 1: 10', 'Standard: Class 2  ·  Count: 10']);
    expect(bot.followUps, ['Show boys and girls']);
    expect(fake.sent.single.url.path, '/api/ai/ask');

    await c.send('And girls?');
    final body = (fake.sent.last as http.MultipartRequest).fields;
    expect(body['conversation_id'], '42');
    expect(body['question'], 'And girls?');
    expect(body.containsKey('token'), isFalse); // identity fields are not needed; the bearer carries it
  });

  test('a refusal is shown as an error reply that can be retried', () async {
    final fake = _Fake({'success': false, 'message': 'AI request blocked by policy.', 'data': null}, status: 403);
    final c = AiChatController(_api(fake));
    await c.send('hello');
    expect(c.messages.last.error, isTrue);
    expect(c.messages.last.headline, 'AI request blocked by policy.');
    await c.retry();
    expect(c.messages.where((m) => m.mine).length, 1); // the question is not duplicated
    expect(c.messages.length, 2);
  });

  test('the module is sent only when one is set', () async {
    final fake = _Fake({'success': true, 'message': 'ok', 'data': {'answer': {'headline': 'ok'}}});
    await AiChatController(_api(fake), module: 'students').send('How many students?');
    expect((fake.sent.single as http.MultipartRequest).fields['module'], 'students');
    final fake2 = _Fake({'success': true, 'message': 'ok', 'data': {'answer': {'headline': 'ok'}}});
    await AiChatController(_api(fake2)).send('hi');
    expect((fake2.sent.single as http.MultipartRequest).fields.containsKey('module'), isFalse);
  });

  test('newChat clears the thread', () async {
    final fake = _Fake({'success': true, 'message': 'ok', 'data': {'conversation': {'id': 5}, 'answer': {'headline': 'ok'}}});
    final c = AiChatController(_api(fake));
    await c.send('hi');
    c.newChat();
    expect(c.messages, isEmpty);
    await c.send('again');
    expect((fake.sent.last as http.MultipartRequest).fields.containsKey('conversation_id'), isFalse);
  });
}
