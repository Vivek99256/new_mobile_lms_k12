import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';
import 'inward_outward.dart';

/// Add or edit an inward / outward entry. Pops with true after a save.
class RegisterFormScreen extends StatefulWidget {
  const RegisterFormScreen({super.key, required this.args, required this.kind, this.row});
  final ScreenArgs args;
  final RegisterKind kind;
  final Map<String, dynamic>? row;

  @override
  State<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends State<RegisterFormScreen> with SubmitGuard {
  List<Opt> places = [], files = [];
  bool loading = true;
  String? error;
  String? placeId, fileId;
  DateTime date = DateTime.now();
  late final number = TextEditingController(text: s(widget.row?[widget.kind.numberKey]));
  late final subject = TextEditingController(text: s(widget.row?['title']));
  late final desc = TextEditingController(text: s(widget.row?['description']));
  PickedFile? file;

  bool get isEdit => widget.row != null;
  RegisterKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    if (r != null) {
      date = DateTime.tryParse(s(r[kind.dateKey]).isEmpty ? s(r['outward_date']).split(' ').first : s(r[kind.dateKey]).split(' ').first) ?? date;
    }
    _loadOptions();
  }

  @override
  void dispose() {
    number.dispose();
    subject.dispose();
    desc.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = widget.args.api;
      final r = await Future.wait([
        api.get('/inward_outward/add_place_master'),
        api.get('/inward_outward/add_physical_file_location'),
      ]);
      if (!mounted) return;
      setState(() {
        places = [for (final x in rows(r[0]['data'])) Opt(s(x['id']), s(x['title']))];
        files = [for (final x in rows(r[1]['data'])) Opt(s(x['id']), s(x['title']))];
        final row = widget.row;
        if (row != null) {
          // Edit rows only carry display names, so match by label (or id as a fallback).
          placeId = places.where((o) => o.label == s(row['place_id']) || o.id == s(row['place_id'])).firstOrNull?.id;
          fileId = files
              .where((o) => o.label == s(row['file_name']) || o.label == s(row['file_location_id']) || o.id == s(row['file_location_id']))
              .firstOrNull
              ?.id;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    if (missing(context, placeId, 'Please select a place.')) return;
    if (missing(context, number.text, 'Please enter the ${kind.word.toLowerCase()} number.')) return;
    if (missing(context, subject.text, 'Please enter a subject.')) return;
    if (missing(context, desc.text, 'Please enter a description.')) return;
    if (missing(context, fileId, 'Please select a file.')) return;
    if (!isEdit && file == null) {
      toast(context, 'Please upload a file.', error: true);
      return;
    }
    final syear = syearOf(widget.args.session);
    await guarded(() async {
      final Map<String, dynamic> res;
      if (isEdit) {
        res = await AdminHttp.put(widget.args.session, '${kind.path}/${s(widget.row!['id'])}', {
          'title': subject.text.trim(),
          'place_id': placeId!,
          'file_location_id': fileId!,
          'outward_number': number.text.trim(),
          'description': desc.text.trim(),
          'acedemic_year': syear,
          'outward_date': ymd(date),
          // The inward form read these two keys as well.
          if (kind.isInward) 'inward_number': number.text.trim(),
          if (kind.isInward) 'inward_date': ymd(date),
        });
      } else {
        res = await widget.args.api.post(
          kind.path,
          body: {
            'place_id': placeId,
            'file_location_id': fileId,
            'outward_number': number.text.trim(),
            'title': subject.text.trim(),
            'description': desc.text.trim(),
            'acedemic_year': syear,
            'outward_date': ymd(date),
            if (kind.isInward) 'inward_number': number.text.trim(),
            if (kind.isInward) 'inward_date': ymd(date),
          },
          files: [file!.asUpload('attachment')],
        );
      }
      if (!mounted) return;
      final good = statusOf(res) != '0';
      toast(context, LegacyApi.messageOf(res, good ? 'Saved.' : 'Could not save.'), error: !good);
      if (good) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: '${isEdit ? 'Update' : 'Add'} ${kind.word.toLowerCase()}',
        bottom: loading || error != null ? null : formBar(label: isEdit ? 'Update' : 'Save', busy: busy, onPressed: _save),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? KitMessage(icon: Icons.cloud_off_outlined, text: error!, action: 'Try again', onAction: _loadOptions)
                : ListView(padding: const EdgeInsets.all(16), children: [
                    DropdownField(label: kind.isInward ? 'From place' : 'To place', options: places, value: placeId, onChanged: (v) => setState(() => placeId = v)),
                    gap(),
                    DateField(label: '${kind.word} date', value: date, onChanged: (d) => setState(() => date = d)),
                    gap(),
                    TextInput(label: '${kind.word} number', controller: number),
                    gap(),
                    TextInput(label: 'Subject', controller: subject),
                    gap(),
                    TextInput(label: 'Description', controller: desc, lines: 3),
                    gap(),
                    DropdownField(label: 'File name', options: files, value: fileId, onChanged: (v) => setState(() => fileId = v)),
                    gap(),
                    if (isEdit)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('The attached file cannot be replaced when editing.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                      )
                    else
                      FileField(label: 'Upload file', file: file, onChanged: (f) => setState(() => file = f)),
                  ]),
      );
}
