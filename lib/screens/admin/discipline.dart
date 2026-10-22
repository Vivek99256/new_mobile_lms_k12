import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import '../teacher/api_migration.dart';
import 'admin_common.dart';

/// t_disclipline: record a discipline note for one student.
class DisciplineScreen extends StatefulWidget {
  const DisciplineScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<DisciplineScreen> createState() => _DisciplineScreenState();
}

class _DisciplineScreenState extends State<DisciplineScreen> with SubmitGuard {
  CascadeSelection sel = CascadeSelection();
  List<Opt> students = [];
  bool loadingStudents = false;
  String? studentId;
  String? performance;
  final message = TextEditingController();
  String? _loadedFor;

  static const levels = ['Excellent', 'Very Good', 'Good', 'Poor'];

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> _onFilter(CascadeSelection v) async {
    sel = v;
    final key = v.divisionId == null ? null : '${v.standardId}-${v.divisionId}';
    if (key == _loadedFor) return;
    _loadedFor = key;
    setState(() {
      students = [];
      studentId = null;
      loadingStudents = key != null;
    });
    if (key == null) return;
    try {
      final res = await widget.args.api.post('/allStudentListAPI', body: {
        'grade_id': v.sectionId,
        'standard_id': v.standardId,
        'division_id': v.divisionId,
      });
      if (!mounted || _loadedFor != key) return;
      setState(() => students = [for (final r in rows(res['data'])) Opt(s(r['id']), s(r['student_name']))]);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted && _loadedFor == key) setState(() => loadingStudents = false);
    }
  }

  Future<void> _save() async {
    if (missing(context, sel.standardId, 'Please select a standard.')) return;
    if (missing(context, sel.divisionId, 'Please select a division.')) return;
    if (missing(context, studentId, 'Please select a student.')) return;
    if (missing(context, performance, 'Please select the performance.')) return;
    if (missing(context, message.text, 'Please enter a message.')) return;
    await guarded(() async {
      final api = widget.args.api;
      final res = await writeNewThenLegacy(
        't_disclipline',
        () => api.post('/student-care/discipline', body: {
          'student_id': studentId,
          'dicipline': performance,
          'message': message.text.trim(),
          'date_': ymd(DateTime.now()),
        }),
        () => api.post('/add_teacherStudentDisciplineAPI', body: {
          'data': jsonEncode({'student_id': studentId, 'dicipline': performance, 'message': message.text.trim()}),
        }),
      );
      if (!mounted) return;
      if (report(res, ok: 'Discipline note saved.')) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Discipline' : widget.args.item.label,
        bottom: formBar(label: 'Save', busy: busy, onPressed: _save),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          CascadeFilter(api: widget.args.api, onChanged: _onFilter),
          gap(),
          DropdownField(label: 'Student', options: students, value: studentId, loading: loadingStudents, onChanged: (v) => setState(() => studentId = v)),
          gap(),
          DropdownField(
            label: 'Student performance',
            options: [for (final l in levels) Opt(l, l)],
            value: performance,
            onChanged: (v) => setState(() => performance = v),
          ),
          gap(),
          TextInput(label: 'Message', controller: message, lines: 3),
        ]),
      );
}
