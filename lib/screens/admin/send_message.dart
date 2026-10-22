import 'package:flutter/material.dart';

import '../kit/kit.dart';
import '../screen_registry.dart';
import '../teacher/api_migration.dart';
import 'admin_common.dart';

enum MessageKind { sms, notification, email }

/// t_sms_parent / t_notification_parent / t_email_parent: pick students, write a message.
class SendMessageScreen extends StatefulWidget {
  const SendMessageScreen({super.key, required this.args, required this.kind});
  final ScreenArgs args;
  final MessageKind kind;

  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends State<SendMessageScreen> with SubmitGuard {
  final subject = TextEditingController();
  final text = TextEditingController();
  List<Map<String, dynamic>> all = const [];
  List<Map<String, dynamic>> selected = const [];
  CascadeSelection filter = CascadeSelection();

  MessageKind get kind => widget.kind;

  @override
  void dispose() {
    subject.dispose();
    text.dispose();
    super.dispose();
  }

  String get _defaultTitle => switch (kind) {
        MessageKind.sms => 'Send SMS',
        MessageKind.notification => 'Send notification',
        MessageKind.email => 'Send email',
      };

  Future<void> _send() async {
    if (selected.isEmpty) {
      toast(context, 'Select at least one student.', error: true);
      return;
    }
    if (kind == MessageKind.email && missing(context, subject.text, 'Please enter a subject.')) return;
    if (missing(context, text.text, 'Please enter a message.')) return;

    final Map<String, dynamic> body;
    final String url;
    final ParentSend sendKind;
    final String screen;
    switch (kind) {
      case MessageKind.sms:
        url = '/add_adminSendSmsAPI';
        sendKind = ParentSend.sms;
        screen = 't_sms_parent';
        final withMobile = selected.where((e) => s(e['mobile']).isNotEmpty).toList();
        if (withMobile.isEmpty) {
          toast(context, 'None of the selected students has a mobile number.', error: true);
          return;
        }
        body = {
          'sms_text': text.text.trim(),
          for (final e in withMobile) 'mobile_number[${s(e['id'])}]': s(e['mobile']),
        };
      case MessageKind.notification:
        url = '/add_SendNotificationAPI';
        sendKind = ParentSend.notification;
        screen = 't_notification_parent';
        body = {'student_id': selected.map((e) => s(e['id'])).join(','), 'description': text.text.trim()};
      case MessageKind.email:
        url = '/add_adminSendEmailAPI';
        sendKind = ParentSend.email;
        screen = 't_email_parent';
        final emails = selected.map((e) => s(e['email'])).where((e) => e.isNotEmpty).toList();
        if (emails.isEmpty) {
          toast(context, 'None of the selected students has an email address.', error: true);
          return;
        }
        body = {'all_email': emails.join(','), 'example-subject': subject.text.trim(), 'content': text.text.trim()};
    }
    await guarded(() async {
      // api/easy_com/send-* first (needs the section id as `grade`); the legacy endpoint only
      // when the new one refuses outright or the class ids are missing.
      final res = await sendParentMessage(
        api: widget.args.api,
        screen: screen,
        kind: sendKind,
        grade: filter.sectionId,
        standard: filter.standardId,
        division: filter.divisionId,
        text: text.text.trim(),
        subject: subject.text.trim(),
        chosen: selected,
        legacy: () => widget.args.api.post(url, body: body),
      );
      if (!mounted) return;
      if (report(res, ok: 'Sent.')) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? _defaultTitle : widget.args.item.label,
        bottom: all.isEmpty ? null : formBar(label: 'Send to ${selected.length}', busy: busy, onPressed: selected.isEmpty ? null : _send),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          StudentPicker(
            api: widget.args.api,
            onChanged: (a, sel, f) => setState(() {
              all = a;
              selected = sel;
              filter = f;
            }),
          ),
          if (all.isNotEmpty) ...[
            gap(8),
            SectionLabel(switch (kind) {
              MessageKind.sms => 'Message',
              MessageKind.notification => 'Notification',
              MessageKind.email => 'Email',
            }),
            if (kind == MessageKind.email) ...[
              TextInput(label: 'Subject', controller: subject),
              gap(),
            ],
            TextInput(
              label: kind == MessageKind.notification ? 'Notification text' : 'Message',
              controller: text,
              lines: 4,
            ),
          ],
        ]),
      );
}
