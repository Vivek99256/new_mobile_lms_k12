import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'api_migration.dart';
import 'tk.dart';

/// t_marks: choose term, class, subject and exam, then enter marks per student.
class MarksSelectorScreen extends StatefulWidget {
  const MarksSelectorScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<MarksSelectorScreen> createState() => _MarksSelectorScreenState();
}

class _MarksSelectorScreenState extends State<MarksSelectorScreen> {
  ClassSel sel = ClassSel();
  List<Opt> terms = [];
  bool loadingTerms = true, loadingExams = false;
  String? termId, examId, _examKey;
  List<Map<String, dynamic>> exams = [];

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    final a = widget.args;
    // The old login carried `term_data`; the new one may not, so fall back to the academic years.
    var list = rows(a.session.raw['term_data']);
    if (list.isEmpty) {
      try {
        // api/academic-terms is JWT protected and returns the same academic_year rows
        // (term_id, title) the unauthenticated lms_data table read used to.
        list = await readNewThenLegacy('t_marks terms', () async {
          final res = await getNew(a.api, '/api/academic-terms');
          final terms = dataRows(res);
          if (terms.isEmpty) throw ApiException('no terms returned');
          return terms;
        }, () async {
          final res = await a.api.get('/lms_data', query: {
            'table': 'academic_year',
            'filters[sub_institute_id]': '${a.session.subInstituteId}',
            if (a.session.mobileSyear != null) 'filters[syear]': a.session.mobileSyear,
          });
          return dataRows(res);
        });
      } on ApiException catch (e) {
        if (mounted) toast(context, e.message, error: true);
      }
    }
    if (!mounted) return;
    final seen = <String>{};
    setState(() {
      terms = [for (final t in list) if (s(t['term_id']).isNotEmpty && seen.add(s(t['term_id']))) Opt(s(t['term_id']), s(t['title']).isEmpty ? 'Term ${s(t['term_id'])}' : s(t['title']))];
      loadingTerms = false;
    });
  }

  Future<void> _loadExams() async {
    final key = '$termId-${sel.stdId}-${sel.subId}';
    if (termId == null || sel.stdId == null || sel.subId == null || key == _examKey) return;
    _examKey = key;
    setState(() {
      loadingExams = true;
      exams = [];
      examId = null;
    });
    try {
      final res = await postOk(widget.args.api, '/get_teacherResultExamList',
          body: {'standard_id': sel.stdId, 'term_id': termId, 'grade_id': sel.gradeId ?? '', 'subject_id': sel.subId});
      if (mounted && _examKey == key) setState(() => exams = dataRows(res));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => loadingExams = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final exam = exams.where((e) => s(e['id']) == examId).firstOrNull;
    return KitPage(
      title: a.title.isEmpty ? 'Marks' : a.title,
      bottom: PrimaryButton(
        label: 'Enter marks',
        onPressed: exam == null
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => MarksEntryScreen(args: a, sel: sel, exam: exam, termName: terms.where((t) => t.id == termId).firstOrNull?.label ?? ''))),
      ),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          DropdownField(
            label: 'Term',
            options: terms,
            value: termId,
            loading: loadingTerms,
            onChanged: (v) {
              setState(() => termId = v);
              _loadExams();
            },
          ),
          ClassPicker(
            api: a.api,
            admin: isAdmin(a),
            withSubject: true,
            onChanged: (c) {
              sel = c;
              if (c.subId == null && (exams.isNotEmpty || examId != null)) {
                setState(() {
                  exams = [];
                  examId = null;
                  _examKey = null;
                });
              }
              _loadExams();
            },
          ),
          DropdownField(
            label: 'Exam',
            options: [for (final e in exams) Opt(s(e['id']), s(e['title']))],
            value: examId,
            loading: loadingExams,
            onChanged: (v) => setState(() => examId = v),
          ),
          if (!loadingExams && exams.isEmpty && termId != null && sel.subId != null)
            const Text('No exams have been created for this term and subject.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
        ]),
      ]),
    );
  }
}

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key, required this.args, required this.sel, required this.exam, required this.termName});
  final ScreenArgs args;
  final ClassSel sel;
  final Map<String, dynamic> exam;
  final String termName;

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> with BusyMixin {
  final Map<String, TextEditingController> ctrls = {};
  late final Future<List<Map<String, dynamic>>> future = loadStudents(widget.args.api, widget.sel);

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get maxPoints => double.tryParse(s(widget.exam['points'])) ?? 0;

  void _save(List<Map<String, dynamic>> list) {
    final data = <String, dynamic>{};
    for (final st in list) {
      final id = s(st['id']);
      final text = ctrls[id]?.text.trim() ?? '';
      if (text.isEmpty) continue; // leave untouched rather than overwrite with 0
      final upper = text.toUpperCase();
      final isAbsent = upper == 'AB' || upper == 'EX' || upper == 'N.A.';
      final p = double.tryParse(text);
      if (!isAbsent && p == null) return toast(context, 'Marks for ${s(st['student_name'])} must be a number or AB.', error: true);
      if (!isAbsent && maxPoints > 0 && p! > maxPoints) return toast(context, 'Marks for ${s(st['student_name'])} are above the maximum ($maxPoints).', error: true);
      data[id] = {
        'exam_id': s(widget.exam['id']),
        'points': isAbsent ? upper : p,
        'per': isAbsent || maxPoints <= 0 ? '0%' : '${(p! / maxPoints * 100).toStringAsFixed(2)}%',
        'grade': '-',
        'comment': '-',
      };
    }
    if (data.isEmpty) return toast(context, 'Enter marks for at least one student.', error: true);
    submit(() => postOk(widget.args.api, '/result/marks_entry', body: {'data': jsonEncode(data)}), fallback: 'Marks saved.');
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exam;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        final list = snap.data;
        return KitPage(
          title: 'Enter marks',
          bottom: list == null || list.isEmpty ? null : PrimaryButton(label: 'Save marks', busy: busy, onPressed: () => _save(list)),
          child: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snap.hasError
                  ? KitMessage(icon: Icons.cloud_off_outlined, text: '${snap.error}', action: 'Go back', onAction: () => Navigator.pop(context))
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      KitCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          KV('Term', widget.termName),
                          KV('Class', widget.sel.classLabel),
                          KV('Subject', widget.sel.subName ?? ''),
                          KV('Exam', s(e['title'])),
                          KV('Max marks', s(e['points'])),
                        ]),
                      ),
                      if (list!.isEmpty) const KitMessage(icon: Icons.groups_outlined, text: 'No students found in this class.'),
                      for (final st in list) ...[
                        gap(8),
                        KitCard(
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s(st['student_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('Roll ${s(st['roll_no'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                              ]),
                            ),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: ctrls.putIfAbsent(s(st['id']), TextEditingController.new),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(hintText: 'Marks'),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]),
        );
      },
    );
  }
}
