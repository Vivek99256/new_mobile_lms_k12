import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'tk.dart';

Widget _t(String t) => Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Brand.text));

// ---------------------------------------------------------------------------------------
// Homework
// ---------------------------------------------------------------------------------------

class HomeworkListScreen extends StatelessWidget {
  const HomeworkListScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => RangeListPage(
        title: args.title.isEmpty ? 'Homework' : args.title,
        emptyText: 'No homework was assigned in this date range.',
        emptyIcon: Icons.assignment_outlined,
        onAdd: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignHomeworkScreen(args: args))),
        load: (from, to) async {
          final res = await postOk(args.api, '/teacherHomeworkAssignmentAPI', body: {'action': 'Homework', 'from_date': ymd(from), 'to_date': ymd(to)});
          return dataRows(res);
        },
        itemBuilder: (c, r, i) => KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _t(s(r['student_name']))),
              attachmentButton(c, s(r['file_name'])),
            ]),
            Row(children: [
              if (s(r['subject_name']).isNotEmpty) Pill(s(r['subject_name'])),
              const SizedBox(width: 8),
              Text('${s(r['standard_name'])} - ${s(r['division_name'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ]),
            gap(8),
            Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(s(r['date']), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            if (s(r['description']).isNotEmpty) ...[gap(4), Text(s(r['description']))],
          ]),
        ),
      );
}

class AssignHomeworkScreen extends StatefulWidget {
  const AssignHomeworkScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AssignHomeworkScreen> createState() => _AssignHomeworkScreenState();
}

class _AssignHomeworkScreenState extends State<AssignHomeworkScreen> with BusyMixin {
  ClassSel sel = ClassSel();
  List<Map<String, dynamic>>? students;
  Set<String> picked = {};
  bool loading = false;
  String? error;
  final title = TextEditingController(), desc = TextEditingController();
  DateTime date = today();
  PickedFile? file;

  @override
  void dispose() {
    title.dispose();
    desc.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      loading = true;
      error = null;
      students = null;
      picked = {};
    });
    try {
      final r = await loadStudents(widget.args.api, sel);
      if (mounted) setState(() => students = r);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _submit() {
    if (title.text.trim().isEmpty) return toast(context, 'Please enter a title.', error: true);
    if (desc.text.trim().isEmpty) return toast(context, 'Please enter a description.', error: true);
    final ids = picked.toList();
    submit(() => postOk(
          widget.args.api,
          '/student/student_homework',
          body: {
            'title': title.text.trim(),
            'description': desc.text.trim(),
            'submission_date': dts(date),
            'standard_id': sel.stdId,
            'division_id': sel.divId,
            'subject_id': sel.subId,
            for (var i = 0; i < ids.length; i++) 'students[$i]': ids[i],
          },
          files: [if (file != null) file!.asUpload('image')],
        ));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final list = students;
    return KitPage(
      title: 'Assign homework',
      bottom: list == null || list.isEmpty ? null : PrimaryButton(label: 'Submit to ${picked.length} student${picked.length == 1 ? '' : 's'}', busy: busy, onPressed: picked.isEmpty ? null : _submit),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(title: 'Class', children: [
          ClassPicker(api: a.api, admin: isAdmin(a), withSubject: true, onChanged: (c) => setState(() => sel = c)),
          PrimaryButton(label: 'Find students', busy: loading, onPressed: sel.subId == null || sel.divId == null ? null : _search),
        ]),
        if (error != null) KitMessage(icon: Icons.search_off_rounded, text: error!, action: 'Try again', onAction: _search),
        if (list != null && list.isEmpty) const KitMessage(icon: Icons.groups_outlined, text: 'No students found in this class.'),
        if (list != null && list.isNotEmpty) ...[
          gap(),
          FormCard(title: 'Homework', children: [
            TextInput(label: 'Title', controller: title),
            TextInput(label: 'Description', controller: desc, lines: 3),
            DateField(label: 'Submission date', value: date, onChanged: (d) => setState(() => date = d)),
            FileField(label: 'Attachment (optional)', file: file, onChanged: (f) => setState(() => file = f)),
          ]),
          gap(),
          titleRow('Select students'),
          gap(8),
          StudentChecklist(students: list, selected: picked, onChanged: (v) => setState(() => picked = v)),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Circular
// ---------------------------------------------------------------------------------------

class CircularListScreen extends StatefulWidget {
  const CircularListScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<CircularListScreen> createState() => _CircularListScreenState();
}

class _CircularListScreenState extends State<CircularListScreen> {
  ClassSel sel = ClassSel();
  final ctrl = AsyncListController();
  bool searched = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return ListPage(
      title: a.title.isEmpty ? 'Circular' : a.title,
      controller: ctrl,
      emptyText: searched ? 'No circulars found for this standard.' : 'Select a standard to see its circulars.',
      emptyIcon: Icons.campaign_outlined,
      actions: [
        addAction(context, () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => AddCircularScreen(args: a)));
          if (mounted && searched) ctrl.reload();
        }),
      ],
      header: Column(children: [
        ClassPicker(
          api: a.api,
          admin: isAdmin(a),
          withDivision: false,
          autoSelectFirst: true,
          onChanged: (c) {
            sel = c;
            if (c.stdId != null) {
              searched = true;
              ctrl.reload();
            }
          },
        ),
      ]),
      load: () async {
        if (sel.stdId == null) return const [];
        return dataRows(await postOk(a.api, '/circular/TeacherFetchData', body: {'standard_id': sel.stdId}));
      },
      itemBuilder: (c, r, i) => KitCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _t('${s(r['std_name'])} - ${s(r['title'])}')),
            attachmentButton(c, s(r['file_name'])),
          ]),
          Text(s(r['date_']), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          gap(6),
          Text(s(r['message'])),
        ]),
      ),
    );
  }
}

class AddCircularScreen extends StatefulWidget {
  const AddCircularScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AddCircularScreen> createState() => _AddCircularScreenState();
}

class _AddCircularScreenState extends State<AddCircularScreen> with BusyMixin {
  ClassSel sel = ClassSel();
  DateTime date = today();
  final title = TextEditingController(), message = TextEditingController();
  String? type;
  PickedFile? file;

  @override
  void dispose() {
    title.dispose();
    message.dispose();
    super.dispose();
  }

  void _submit() {
    if (sel.stdId == null) return toast(context, 'Please select a standard.', error: true);
    if (sel.divId == null) return toast(context, 'Please select a division.', error: true);
    if (title.text.trim().isEmpty) return toast(context, 'Please enter a title.', error: true);
    if (type == null) return toast(context, 'Please select a type.', error: true);
    if (message.text.trim().isEmpty) return toast(context, 'Please enter a message.', error: true);
    submit(() => postOk(
          widget.args.api,
          '/add_adminCircularAPI',
          body: {
            'title': title.text.trim(),
            'message': message.text.trim(),
            'type': type,
            'date_': dts(date),
            'standard_id': sel.stdId,
            'division_id': sel.divId,
            'action': 'API',
          },
          files: [if (file != null) file!.asUpload('attachment[0]')],
        ));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: 'Add circular',
      bottom: PrimaryButton(label: 'Submit', busy: busy, onPressed: _submit),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          ClassPicker(api: a.api, admin: isAdmin(a), onChanged: (c) => sel = c),
          DateField(label: 'Date', value: date, onChanged: (d) => setState(() => date = d)),
          TextInput(label: 'Title', controller: title),
          DropdownField(label: 'Type', options: const [Opt('1', 'Circular'), Opt('2', 'Event')], value: type, onChanged: (v) => setState(() => type = v)),
          TextInput(label: 'Message', controller: message, lines: 3),
          FileField(label: 'Attachment (optional)', file: file, onChanged: (f) => setState(() => file = f)),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Exam schedule
// ---------------------------------------------------------------------------------------

class ExamScheduleScreen extends StatelessWidget {
  const ExamScheduleScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final ctrl = AsyncListController();
    return ListPage(
      title: args.title.isEmpty ? 'Exam schedule' : args.title,
      controller: ctrl,
      emptyText: 'No exam schedules have been published.',
      emptyIcon: Icons.event_note_outlined,
      actions: [
        addAction(context, () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => AddExamScreen(args: args)));
          ctrl.reload();
        }),
      ],
      load: () async => dataRows(await postOk(args.api, '/get_teacherExamSchedule')),
      itemBuilder: (c, r, i) => KitCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _t(s(r['title'])),
              Text(fmtDate(r['date_'], out: 'dd MMM, yyyy'), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ]),
          ),
          attachmentButton(c, s(r['file_name'])),
        ]),
      ),
    );
  }
}

class AddExamScreen extends StatefulWidget {
  const AddExamScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> with BusyMixin {
  ClassSel sel = ClassSel();
  DateTime date = today();
  final title = TextEditingController();
  PickedFile? file;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: 'Add exam schedule',
      bottom: PrimaryButton(
        label: 'Submit',
        busy: busy,
        onPressed: () {
          if (sel.stdId == null || sel.divId == null) return toast(context, 'Select a standard and division.', error: true);
          if (title.text.trim().isEmpty) return toast(context, 'Please enter a title.', error: true);
          if (file == null) return toast(context, 'Please attach the schedule.', error: true);
          submit(() => postOk(a.api, '/add_teacherExamSchedule',
              body: {'title': title.text.trim(), 'date': dts(date), 'standard_id': sel.stdId, 'division_id': sel.divId},
              files: [file!.asUpload('attachment')]));
        },
      ),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          ClassPicker(api: a.api, admin: isAdmin(a), onChanged: (c) => sel = c),
          DateField(label: 'Date', value: date, onChanged: (d) => setState(() => date = d)),
          TextInput(label: 'Title', controller: title),
          FileField(label: 'Attachment', file: file, onChanged: (f) => setState(() => file = f)),
        ]),
      ]),
    );
  }
}
