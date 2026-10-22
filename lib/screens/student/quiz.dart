import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'quiz_reports.dart';
import 'student_common.dart';

/// Parses studentQuestionPaperAPI: `data` is a map whose first value is a map of questions.
List<Map<String, dynamic>> parseQuestions(dynamic d) {
  Iterable<dynamic> qs = const [];
  if (d is Map && d.isNotEmpty) {
    final first = d.values.first;
    if (first is Map && !first.containsKey('question_title')) {
      qs = first.values;
    } else if (first is List) {
      qs = first;
    } else {
      qs = d.values;
    }
  } else if (d is List) {
    qs = d;
  }
  return [for (final q in qs) if (q is Map) Map<String, dynamic>.from(q)];
}

/// The Test tab's quiz: one question at a time, single choice, timer, submit.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.args, required this.paper});
  final ScreenArgs args;
  final Map<String, dynamic> paper;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> _qs = [];
  final Map<int, String> _chosen = {}; // question index -> answer id
  int _i = 0;
  bool _loading = true, _submitting = false;
  String? _error;
  Timer? _timer;
  int _left = 0;

  String get _paperId => s(widget.paper['question_paper_id']).isNotEmpty ? s(widget.paper['question_paper_id']) : s(widget.paper['id']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.args.api.post('/studentQuestionPaperAPI', body: {'question_paper_id': _paperId});
      if (!mounted) return;
      if (!LegacyApi.ok(res)) {
        setState(() => _error = LegacyApi.messageOf(res));
      } else {
        _qs = parseQuestions(res['data']);
        _startTimer();
      }
    } on ApiException catch (e) {
      if (mounted) _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _startTimer() {
    final minutes = int.tryParse(s(widget.paper['time_allowed'])) ?? 0;
    if (minutes <= 0 || _qs.isEmpty) return;
    _left = minutes * 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        toast(context, 'Time is up. Submitting your answers.', error: true);
        _submit();
      }
    });
  }

  List<Map<String, dynamic>> _answers(int q) => rows(_qs[q]['Answer']);

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final ids = <String>[], given = <String>[], original = <String>[];
    final review = <ReviewItem>[];
    var correct = 0;
    for (var q = 0; q < _qs.length; q++) {
      final answers = _answers(q);
      final right = answers.where((a) => s(a['correct_answer']) == '1').firstOrNull;
      final pick = answers.where((a) => s(a['id']) == _chosen[q]).firstOrNull;
      ids.add(s(_qs[q]['id']));
      given.add(pick == null ? '0' : s(pick['id']));
      original.add(right == null ? '0' : s(right['id']));
      final isRight = pick != null && right != null && s(pick['id']) == s(right['id']);
      if (isRight) correct++;
      review.add(ReviewItem(
        question: decodeEntities(s(_qs[q]['question_title'])),
        correct: decodeEntities(s(right?['answer'])),
        given: pick == null ? '' : decodeEntities(s(pick['answer'])),
      ));
    }
    try {
      final res = await widget.args.api.post('/studentQuestionPaperSaveAPI', body: {
        'question_paper_id': _paperId,
        'question_list': ids.join(','),
        'given_ans': given.join(','),
        'original_ans': original.join(','),
        'total_marks': '1',
      });
      if (!mounted) return;
      if (LegacyApi.ok(res)) {
        _timer?.cancel();
        toast(context, 'Submitted successfully.');
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => ReviewScreen(
                    title: 'Result of practice',
                    items: review,
                    stats: [('Total', '${_qs.length}', const Color(0xFF16A34A)), ('Right', '$correct', Brand.primary), ('Skipped', '${given.where((g) => g == '0').length}', const Color(0xFFE11D48))])));
        return;
      }
      toast(context, LegacyApi.messageOf(res), error: true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
    if (mounted) setState(() => _submitting = false);
  }

  String get _clock => '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final timed = _timer?.isActive ?? false;
    return KitPage(
      title: 'Q & A',
      actions: [
        if (timed)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _left <= 10 ? const Color(0xFFE11D48) : Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text(_clock, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
      ],
      bottom: _qs.isEmpty || _loading || _error != null
          ? null
          : Row(children: [
              if (_i < _qs.length - 1)
                TextButton(onPressed: () => setState(() => _i++), child: const Text('Skip')),
              Expanded(
                child: PrimaryButton(
                  label: _i < _qs.length - 1 ? 'Next' : 'Submit',
                  busy: _submitting,
                  onPressed: _i < _qs.length - 1 ? () => setState(() => _i++) : _submit,
                ),
              ),
            ]),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _load);
    if (_qs.isEmpty) return const KitMessage(icon: Icons.quiz_outlined, text: 'This test has no questions yet.');
    final q = _qs[_i];
    final answers = _answers(_i);
    return Column(children: [
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          itemCount: _qs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (c, n) => GestureDetector(
            onTap: () => setState(() => _i = n),
            child: Container(
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: n == _i ? Brand.primary : (_chosen.containsKey(n) ? const Color(0xFFE8EDFC) : Colors.white),
                border: Border.all(color: n == _i ? Brand.primary : Brand.border),
              ),
              child: Text('${n + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: n == _i ? Colors.white : Brand.text)),
            ),
          ),
        ),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
          KitCard(child: HtmlBlock(decodeEntities(s(q['question_title'])), style: const TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          for (final a in answers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _chosen[_i] = s(a['id'])),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _chosen[_i] == s(a['id']) ? const Color(0xFFE8EDFC) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _chosen[_i] == s(a['id']) ? Brand.primary : Brand.border, width: 1.5),
                  ),
                  child: Row(children: [
                    Expanded(child: HtmlBlock(decodeEntities(s(a['answer'])))),
                    if (_chosen[_i] == s(a['id'])) const Icon(Icons.check_circle_rounded, color: Brand.primary),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}
