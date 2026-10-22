import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'student_common.dart';

class ReviewItem {
  const ReviewItem({required this.question, required this.correct, required this.given});
  final String question;
  final String correct;
  final String given;
}

String _plain(String html) => decodeEntities(html.replaceAll(RegExp(r'<[^>]*>'), '')).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Three stats on top, then each question with the right answer and what the student chose.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.title, required this.items, required this.stats});
  final String title;
  final List<ReviewItem> items;
  final List<(String, String, Color)> stats;

  @override
  Widget build(BuildContext context) => KitPage(
        title: title,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [for (final st in stats) StatTile(st.$1, st.$2, st.$3)]),
          const SizedBox(height: 16),
          if (items.isEmpty) const KitMessage(icon: Icons.inbox_outlined, text: 'There are no questions to review.'),
          for (var i = 0; i < items.length; i++) _ReviewCard(index: i, item: items[i]),
        ]),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.index, required this.item});
  final int index;
  final ReviewItem item;

  @override
  Widget build(BuildContext context) {
    final answered = _plain(item.given).isNotEmpty;
    final right = answered && _plain(item.given) == _plain(item.correct);
    final tone = right ? const Color(0xFF16A34A) : const Color(0xFFE11D48);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KitCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 14, backgroundColor: Brand.primary, child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Expanded(child: HtmlBlock(item.question, style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 10),
          _box('Correct answer', item.correct, Brand.primary, Icons.check_circle_outline),
          const SizedBox(height: 8),
          if (answered)
            _box(right ? 'You chose the right answer' : 'You chose the wrong answer', item.given, tone, right ? Icons.check_circle_rounded : Icons.cancel_rounded)
          else
            const Text('You did not answer this question.', style: TextStyle(color: Brand.muted, fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }

  Widget _box(String label, String html, Color color, IconData icon) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          HtmlBlock(html),
        ]),
      );
}

/// Attempts of one test (studentAssessmentAPI).
class TestReportListScreen extends StatelessWidget {
  const TestReportListScreen({super.key, required this.args, required this.paper});
  final ScreenArgs args;
  final Map<String, dynamic> paper;

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Report',
        child: AsyncList(
          emptyText: 'You have not attempted this test yet.',
          emptyIcon: Icons.assessment_outlined,
          load: () async {
            final res = await args.api.post('/studentAssessmentAPI', body: {
              'question_paper_id': s(paper['question_paper_id']).isNotEmpty ? s(paper['question_paper_id']) : s(paper['id']),
            });
            if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
            return rows(m(res['data'])['attempted_data']);
          },
          itemBuilder: (c, at, i) {
            final total = numOf(at['total_right']) + numOf(at['total_wrong']);
            return KitCard(
              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => TestReportScreen(args: args, attempt: at))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s(at['paper_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('At ${s(at['created_at'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                    Text('Time ${s(at['start_time'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFE3F5E9), borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Text('${s(at['obtain_marks'])}/${total % 1 == 0 ? total.toInt() : total}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 17)),
                    const Text('Total mark', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                  ]),
                ),
              ]),
            );
          },
        ),
      );
}

/// Question-by-question review of one attempt (studentAssessmentDetailAPI).
class TestReportScreen extends StatelessWidget {
  const TestReportScreen({super.key, required this.args, required this.attempt});
  final ScreenArgs args;
  final Map<String, dynamic> attempt;

  @override
  Widget build(BuildContext context) {
    final right = numOf(attempt['total_right']).toInt();
    final wrong = numOf(attempt['total_wrong']).toInt();
    return KitPage(
      title: 'Result of practice',
      child: AsyncBody<List<ReviewItem>>(
        emptyText: 'No answers were recorded for this attempt.',
        isEmpty: (d) => d.isEmpty,
        load: () async {
          final res = await args.api.post('/studentAssessmentDetailAPI', body: {'online_exam_id': s(attempt['online_exam_id'])});
          if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
          final out = <ReviewItem>[];
          for (final e in m(res['data'])['online_answer_data'] is List ? m(res['data'])['online_answer_data'] as List : const []) {
            if (e is! Map) continue;
            final inner = e.containsKey('QUESTION_TEXT') ? e : (e.values.isNotEmpty && e.values.first is Map ? e.values.first as Map : e);
            out.add(ReviewItem(
              question: decodeEntities(s(inner['QUESTION_TEXT'])),
              correct: decodeEntities(s(inner['ACTUAL_ANSWER'])),
              given: decodeEntities(s(inner['GIVEN_ANSWER'])),
            ));
          }
          return out;
        },
        builder: (c, items, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              StatTile('Total', '${right + wrong}', const Color(0xFF16A34A)),
              StatTile('Right', '$right', Brand.primary),
              StatTile('Wrong', '$wrong', const Color(0xFFE11D48)),
            ]),
            const SizedBox(height: 16),
            for (var i = 0; i < items.length; i++) _ReviewCard(index: i, item: items[i]),
          ]),
        ),
      ),
    );
  }
}
