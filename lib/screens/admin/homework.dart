import 'package:flutter/material.dart';

import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';

/// t_homework: pick class + subject + students, then compose and assign homework.
class AdminHomeworkScreen extends StatefulWidget {
  const AdminHomeworkScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AdminHomeworkScreen> createState() => _AdminHomeworkScreenState();
}

class _AdminHomeworkScreenState extends State<AdminHomeworkScreen> with SubmitGuard {
  final title = TextEditingController();
  final desc = TextEditingController();
  DateTime date = DateTime.now();
  PickedFile? file;
  List<Map<String, dynamic>> all = const [];
  List<Map<String, dynamic>> selected = const [];
  CascadeSelection filter = CascadeSelection();

  @override
  void dispose() {
    title.dispose();
    desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (missing(context, title.text, 'Please enter a title.')) return;
    if (missing(context, desc.text, 'Please enter a description.')) return;
    if (file == null) {
      toast(context, 'Please attach an image or PDF.', error: true);
      return;
    }
    await guarded(() async {
      final res = await widget.args.api.post(
        '/student/student_homework',
        body: {
          'title': title.text.trim(),
          'description': desc.text.trim(),
          'submission_date': ymd(date),
          'standard_id': filter.standardId,
          'division_id': filter.divisionId,
          'subject_id': filter.subjectId,
          'students[]': selected.map((e) => s(e['id'])).join(','),
        },
        files: [file!.asUpload('image')],
      );
      if (!mounted) return;
      if (report(res, ok: 'Homework assigned.')) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Homework' : widget.args.item.label,
        bottom: all.isEmpty ? null : formBar(label: 'Assign homework (${selected.length})', busy: busy, onPressed: selected.isEmpty ? null : _submit),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          StudentPicker(
            api: widget.args.api,
            withSubject: true,
            onChanged: (a, sel, f) => setState(() {
              all = a;
              selected = sel;
              filter = f;
            }),
          ),
          if (all.isNotEmpty) ...[
            gap(8),
            const SectionLabel('Homework details'),
            TextInput(label: 'Title', controller: title),
            gap(),
            TextInput(label: 'Description', controller: desc, lines: 3),
            gap(),
            DateField(label: 'Submission date', value: date, onChanged: (d) => setState(() => date = d)),
            gap(),
            FileField(label: 'Attachment (image or PDF)', file: file, onChanged: (f) => setState(() => file = f)),
          ],
        ]),
      );
}
