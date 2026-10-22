import 'package:flutter/material.dart';

import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';

/// t_circular: publish a circular or event to a class.
class AdminCircularScreen extends StatefulWidget {
  const AdminCircularScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AdminCircularScreen> createState() => _AdminCircularScreenState();
}

class _AdminCircularScreenState extends State<AdminCircularScreen> with SubmitGuard {
  CascadeSelection sel = CascadeSelection();
  DateTime date = DateTime.now();
  final title = TextEditingController();
  final message = TextEditingController();
  String? type; // '1' circular, '2' event
  PickedFile? file;

  @override
  void dispose() {
    title.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (missing(context, sel.standardId, 'Please select a standard.')) return;
    if (missing(context, sel.divisionId, 'Please select a division.')) return;
    if (missing(context, title.text, 'Please enter a title.')) return;
    if (missing(context, type, 'Please select a type.')) return;
    if (missing(context, message.text, 'Please enter a message.')) return;
    await guarded(() async {
      final res = await widget.args.api.post(
        '/add_adminCircularAPI',
        body: {
          'title': title.text.trim(),
          'message': message.text.trim(),
          'type': type,
          'date_': ymd(date),
          'standard_id': sel.standardId,
          'division_id': sel.divisionId,
        },
        files: [if (file != null) file!.asUpload('attachment[0]')],
      );
      if (!mounted) return;
      if (report(res, ok: 'Circular published.')) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Circular' : widget.args.item.label,
        bottom: formBar(label: 'Submit', busy: busy, onPressed: _submit),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          CascadeFilter(api: widget.args.api, onChanged: (v) => setState(() => sel = v)),
          gap(),
          DateField(label: 'Date', value: date, onChanged: (d) => setState(() => date = d)),
          gap(),
          TextInput(label: 'Title', controller: title),
          gap(),
          DropdownField(
            label: 'Type',
            options: const [Opt('1', 'Circular'), Opt('2', 'Event')],
            value: type,
            onChanged: (v) => setState(() => type = v),
          ),
          gap(),
          TextInput(label: 'Message', controller: message, lines: 3),
          gap(),
          FileField(label: 'Attachment (optional)', file: file, onChanged: (f) => setState(() => file = f)),
        ]),
      );
}
