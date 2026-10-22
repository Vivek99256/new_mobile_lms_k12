import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'api_migration.dart';
import 'tk.dart';

// ---------------------------------------------------------------------------------------
// Parent communication (shared with admin)
// ---------------------------------------------------------------------------------------

class ParentCommScreen extends StatelessWidget {
  const ParentCommScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final ctrl = AsyncListController();
    final admin = isAdmin(args);
    return ListPage(
      title: args.title.isEmpty ? 'Parent communication' : args.title,
      controller: ctrl,
      emptyText: 'No messages from parents.',
      emptyIcon: Icons.question_answer_outlined,
      load: () async => dataRows(await postOk(args.api, admin ? '/get_adminParentCommunicationListAPI' : '/teacherParentcommunicationListAPI')),
      itemBuilder: (c, r, i) => _CommCard(
        key: ValueKey('${r['parent_comm_id']}'),
        row: r,
        onSend: (text) async {
          final res = await args.api.post(admin ? '/add_adminParentCommunicationSaveAPI' : '/teacherParentcommunicationSaveAPI', body: {
            'parent_comm_id': r['parent_comm_id'],
            'reply': text,
            'reply_on': DateTime.now().toString(),
          });
          if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
          ctrl.reload();
        },
      ),
    );
  }
}

class _CommCard extends StatefulWidget {
  const _CommCard({super.key, required this.row, required this.onSend});
  final Map<String, dynamic> row;
  final Future<void> Function(String) onSend;

  @override
  State<_CommCard> createState() => _CommCardState();
}

class _CommCardState extends State<_CommCard> with BusyMixin {
  final text = TextEditingController();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (text.text.trim().isEmpty) return toast(context, 'Write a reply first.', error: true);
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.onSend(text.text.trim());
      if (mounted) toast(context, 'Reply sent.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final replied = s(r['reply']).isNotEmpty;
    return KitCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonAvatar(url: s(r['student_image']), name: s(r['student_name'])),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(r['student_name']), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${s(r['standard_name'])} - ${s(r['division_name'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ]),
          ),
          Pill(replied ? 'Replied' : 'Awaiting reply', color: replied ? const Color(0xFF047857) : const Color(0xFFD97706)),
        ]),
        gap(4),
        KV('Date', s(r['parent_comm_date'])),
        if (s(r['mobile']).isNotEmpty) KV('Mobile', '+91${s(r['mobile'])}'),
        gap(6),
        Text(s(r['message'])),
        const Divider(height: 22),
        if (replied) ...[
          KV('Reply by', s(r['reply_by'])),
          KV('Reply on', s(r['reply_on'])),
          gap(4),
          Text(s(r['reply'])),
        ] else ...[
          TextInput(label: 'Your reply', controller: text, lines: 2),
          gap(8),
          Align(alignment: Alignment.centerRight, child: SizedBox(width: 140, child: PrimaryButton(label: 'Reply', busy: busy, onPressed: _send))),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Student leave approval
// ---------------------------------------------------------------------------------------

class ApproveLeaveScreen extends StatelessWidget {
  const ApproveLeaveScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final ctrl = AsyncListController();
    return ListPage(
      title: args.title.isEmpty ? 'Student leaves' : args.title,
      controller: ctrl,
      emptyText: 'No student leave applications.',
      emptyIcon: Icons.event_busy_outlined,
      load: () async => dataRows(await postOk(args.api, isAdmin(args) ? '/get_adminLeaveApplicationListAPI' : '/teacherLeaveApplicationListAPI')),
      itemBuilder: (c, r, i) => _LeaveCard(
        key: ValueKey('${r['leave_app_id']}'),
        row: r,
        onAct: (status, reply) async {
          await postOk(args.api, '/teacherLeaveApplicationSaveAPI', body: {'leave_app_id': r['leave_app_id'], 'reply': reply, 'status': status});
          ctrl.reload();
        },
      ),
    );
  }
}

class _LeaveCard extends StatefulWidget {
  const _LeaveCard({super.key, required this.row, required this.onAct});
  final Map<String, dynamic> row;
  final Future<void> Function(String status, String reply) onAct;

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard> with BusyMixin {
  final reply = TextEditingController();

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> _act(String status) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.onAct(status, reply.text.trim());
      if (mounted) toast(context, 'Leave ${status.toLowerCase()}.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final done = s(r['reply']).isNotEmpty;
    final status = s(r['status']);
    return KitCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonAvatar(url: s(r['student_image']), name: s(r['student_name'])),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(r['student_name']), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('Class ${s(r['std_name'])}  |  ${fmtDate(r['apply_date'], out: 'dd-MM-yyyy')}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ]),
          ),
          if (status.isNotEmpty && done) Pill(status, color: status.toLowerCase().startsWith('appr') ? const Color(0xFF047857) : const Color(0xFFDC2626)),
        ]),
        gap(8),
        Text('Reason: ${s(r['title'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (s(r['message']).isNotEmpty) Text(s(r['message'])),
        attachmentButton(context, s(r['file_name'])),
        const Divider(height: 22),
        if (done) ...[
          KV('Reply', s(r['reply'])),
          KV('Replied on', fmtDate(r['reply_on'], out: 'dd-MM-yyyy hh:mm a')),
          KV('Replied by', s(r['reply_by'])),
        ] else ...[
          TextInput(label: 'Reply (optional)', controller: reply, lines: 2),
          gap(10),
          Row(children: [
            Expanded(child: PrimaryButton(label: 'Approve', busy: busy, color: const Color(0xFF047857), onPressed: () => _act('Approved'))),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(label: 'Reject', busy: busy, color: const Color(0xFFDC2626), onPressed: () => _act('Rejected'))),
          ]),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Student discipline
// ---------------------------------------------------------------------------------------

class DisciplineScreen extends StatefulWidget {
  const DisciplineScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<DisciplineScreen> createState() => _DisciplineScreenState();
}

class _DisciplineScreenState extends State<DisciplineScreen> with BusyMixin {
  ClassSel sel = ClassSel();
  List<Opt> students = [];
  bool loadingStudents = false;
  String? studentId, performance, _loadedFor;
  final message = TextEditingController();

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> _loadStudents(ClassSel c) async {
    final key = '${c.stdId}-${c.divId}';
    if (c.divId == null || key == _loadedFor) return;
    _loadedFor = key;
    setState(() {
      loadingStudents = true;
      students = [];
      studentId = null;
    });
    try {
      final r = await loadStudents(widget.args.api, c);
      if (mounted && _loadedFor == key) setState(() => students = [for (final x in r) Opt(s(x['id']), s(x['student_name']))]);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => loadingStudents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: a.title.isEmpty ? 'Student discipline' : a.title,
      bottom: PrimaryButton(
        label: 'Save',
        busy: busy,
        onPressed: () {
          if (sel.stdId == null) return toast(context, 'Please select a standard.', error: true);
          if (sel.divId == null) return toast(context, 'Please select a division.', error: true);
          if (studentId == null) return toast(context, 'Please select a student.', error: true);
          if (performance == null) return toast(context, 'Please select the performance.', error: true);
          if (message.text.trim().isEmpty) return toast(context, 'Please enter a message.', error: true);
          submit(() => writeNewThenLegacy(
                't_disclipline',
                () => a.api.post('/student-care/discipline', body: {
                  'student_id': studentId,
                  'dicipline': performance,
                  'message': message.text.trim(),
                  'date_': ymd(today()),
                }),
                () => postOk(a.api, '/add_teacherStudentDisciplineAPI', body: {
                  'data': jsonEncode({'student_id': studentId, 'dicipline': performance, 'message': message.text.trim()}),
                }),
              ));
        },
      ),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          ClassPicker(
            api: a.api,
            admin: isAdmin(a),
            onChanged: (c) {
              sel = c;
              _loadStudents(c);
            },
          ),
          DropdownField(label: 'Student', options: students, value: studentId, loading: loadingStudents, onChanged: (v) => setState(() => studentId = v)),
          DropdownField(
            label: 'Student performance',
            options: const [Opt('Excellent', 'Excellent'), Opt('Very Good', 'Very Good'), Opt('Good', 'Good'), Opt('Poor', 'Poor')],
            value: performance,
            onChanged: (v) => setState(() => performance = v),
          ),
          TextInput(label: 'Message', controller: message, lines: 3),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------
// SMS / notification / email to parents
// ---------------------------------------------------------------------------------------

enum ParentMessageKind { sms, notification, email }

class ParentMessageScreen extends StatefulWidget {
  const ParentMessageScreen({super.key, required this.args, required this.kind});
  final ScreenArgs args;
  final ParentMessageKind kind;

  @override
  State<ParentMessageScreen> createState() => _ParentMessageScreenState();
}

class _ParentMessageScreenState extends State<ParentMessageScreen> with BusyMixin {
  ClassSel sel = ClassSel();
  List<Map<String, dynamic>>? students;
  Set<String> picked = {};
  bool loading = false;
  String? error;
  final message = TextEditingController(), subject = TextEditingController();

  @override
  void dispose() {
    message.dispose();
    subject.dispose();
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

  void _send() {
    final chosen = [for (final st in students ?? const <Map<String, dynamic>>[]) if (picked.contains(s(st['id']))) st];
    final text = message.text.trim();
    final api = widget.args.api;
    Future<Map<String, dynamic>> viaNew(ParentSend kind, String screen, Future<Map<String, dynamic>> Function() legacy, {String subjectText = ''}) =>
        sendParentMessage(
          api: api,
          screen: screen,
          kind: kind,
          grade: sel.gradeId,
          standard: sel.stdId,
          division: sel.divId,
          text: text,
          subject: subjectText,
          chosen: chosen,
          legacy: legacy,
        );
    switch (widget.kind) {
      case ParentMessageKind.sms:
        if (!chosen.any((st) => s(st['mobile']).isNotEmpty)) return toast(context, 'None of the selected students has a mobile number.', error: true);
        submit(() => viaNew(ParentSend.sms, 't_sms_parent', () => postOk(api, '/teacherSendSmsParentsAPI', body: {
              'sms_text': text,
              for (final st in chosen) 'mobile_number[${s(st['id'])}]': s(st['mobile']),
            })), fallback: 'SMS sent.');
      case ParentMessageKind.notification:
        submit(() => viaNew(ParentSend.notification, 't_notification_parent', () => postOk(api, '/add_SendNotificationAPI', body: {
              'student_id': chosen.map((e) => s(e['id'])).join(','),
              'description': text,
            })), fallback: 'Notification sent.');
      case ParentMessageKind.email:
        final emails = [for (final st in chosen) if (s(st['email']).isNotEmpty) s(st['email'])];
        if (emails.isEmpty) return toast(context, 'None of the selected students has an email address.', error: true);
        submit(() => viaNew(ParentSend.email, 't_email_parent', () => postOk(api, '/teacherSendEmailParentsAPI', body: {
              'all_email': emails.join(','),
              'example-subject': subject.text.trim(),
              'content': text,
            }), subjectText: subject.text.trim()), fallback: 'Email sent.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final list = students;
    final k = widget.kind;
    final fallbackTitle = k == ParentMessageKind.sms ? 'SMS to parents' : k == ParentMessageKind.email ? 'Email to parents' : 'Notify parents';
    final canSend = picked.isNotEmpty && message.text.trim().isNotEmpty && (k != ParentMessageKind.email || subject.text.trim().isNotEmpty);
    return KitPage(
      title: a.title.isEmpty ? fallbackTitle : a.title,
      bottom: list == null || list.isEmpty ? null : PrimaryButton(label: 'Send to ${picked.length}', busy: busy, onPressed: canSend ? _send : null),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(title: 'Class', children: [
          ClassPicker(api: a.api, admin: isAdmin(a), onChanged: (c) => setState(() => sel = c)),
          PrimaryButton(label: 'Find students', busy: loading, onPressed: sel.divId == null ? null : _search),
        ]),
        if (error != null) KitMessage(icon: Icons.search_off_rounded, text: error!, action: 'Try again', onAction: _search),
        if (list != null && list.isEmpty) const KitMessage(icon: Icons.groups_outlined, text: 'No students found in this class.'),
        if (list != null && list.isNotEmpty) ...[
          gap(),
          FormCard(title: 'Message', children: [
            if (k == ParentMessageKind.email) TextField(controller: subject, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Subject')),
            TextField(
              controller: message,
              onChanged: (_) => setState(() {}),
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: k == ParentMessageKind.notification ? 'Notification text' : 'Message', alignLabelWithHint: true),
            ),
          ]),
          gap(),
          titleRow('Recipients'),
          gap(8),
          StudentChecklist(students: list, selected: picked, onChanged: (v) => setState(() => picked = v)),
        ],
      ]),
    );
  }
}
