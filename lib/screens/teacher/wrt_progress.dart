import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'tk.dart';

/// t_wrt_progress: pick a class, date range and (optionally) exam type, then open a
/// student's progress report.
class WrtProgressScreen extends StatefulWidget {
  const WrtProgressScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<WrtProgressScreen> createState() => _WrtProgressScreenState();
}

class _WrtProgressScreenState extends State<WrtProgressScreen> {
  ClassSel sel = ClassSel();
  DateTime from = today(), to = today();
  List<Opt> exams = [];
  bool loadingExams = false, loading = false;
  String? examId, error, _examFor, opening;
  List<Map<String, dynamic>>? students;

  Future<void> _loadExams() async {
    final std = sel.stdId;
    if (std == null || std == _examFor) return;
    _examFor = std;
    setState(() {
      loadingExams = true;
      exams = [];
      examId = null;
    });
    try {
      final res = await widget.args.api.get('/result/exam_master', query: {'standard_id': std});
      if (mounted && _examFor == std) setState(() => exams = [for (final r in dataRows(res)) Opt(s(r['Id']), s(r['ExamTitle']))]);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => loadingExams = false);
    }
  }

  Future<void> _search() async {
    final a = widget.args;
    setState(() {
      loading = true;
      error = null;
      students = null;
    });
    try {
      final r = await loadStudents(a.api, sel, url: isAdmin(a) ? '/get_adminStudentList' : '/allStudentListAPI');
      if (mounted) setState(() => students = r);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> st) async {
    if (opening != null) return;
    setState(() => opening = s(st['id']));
    try {
      final res = await widget.args.api.post('/get_wrtreportAPI', body: {
        'student_id': st['id'],
        'from_date': ymd(from),
        'to_date': ymd(to),
        if (examId != null) 'exam_type': examId,
      });
      if (!mounted) return;
      final file = s(m(res['data'])['file_name']);
      if (LegacyApi.ok(res) && file.isNotEmpty) {
        await openUrl(context, file);
      } else {
        toast(context, LegacyApi.messageOf(res, 'No report is available for this student.'), error: true);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: a.title.isEmpty ? 'WRT progress' : a.title,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          // Both roles pick Section > Standard > Division here, as the old screen did.
          ClassPicker(
            api: a.api,
            admin: true,
            onChanged: (c) {
              setState(() => sel = c);
              _loadExams();
            },
          ),
          DropdownField(label: 'Exam type (optional)', options: exams, value: examId, loading: loadingExams, onChanged: (v) => setState(() => examId = v)),
          DateRangeBar(from: from, to: to, onChanged: (f, t) => setState(() {
                from = f;
                to = t;
              })),
          PrimaryButton(label: 'Search', busy: loading, onPressed: sel.divId == null ? null : _search),
        ]),
        gap(),
        if (error != null) KitMessage(icon: Icons.search_off_rounded, text: error!, action: 'Try again', onAction: _search),
        if (students != null && students!.isEmpty) const KitMessage(icon: Icons.groups_outlined, text: 'No students found in this class.'),
        for (final st in students ?? const <Map<String, dynamic>>[]) ...[
          StudentTile(
            st: st,
            onTap: () => _open(st),
            trailing: opening == s(st['id']) ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.description_outlined),
          ),
          gap(8),
        ],
      ]),
    );
  }
}
