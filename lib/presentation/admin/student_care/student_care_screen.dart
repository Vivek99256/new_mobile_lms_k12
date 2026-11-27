import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'care_common.dart';
import 'student_care_controller.dart';
import '../../../ui/app_loader.dart';

/// Student Vaccination / Height Weight / Health: one screen driven by a [CareSpec],
/// the same way the web builds all three from `StudentCareModule`.
class StudentCareScreen extends StatefulWidget {
  const StudentCareScreen({super.key, required this.args, required this.spec});
  final ScreenArgs args;
  final CareSpec spec;

  @override
  State<StudentCareScreen> createState() => _StudentCareScreenState();
}

class _StudentCareScreenState extends State<StudentCareScreen> {
  late final StudentCareController _con = StudentCareController(args: widget.args, spec: widget.spec)..addListener(_onChange);
  String _filter = '';

  CareSpec get spec => widget.spec;

  @override
  void initState() {
    super.initState();
    _con.load();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _openForm([CareRecord? r]) async {
    final saved = await push<bool>(context, CareFormScreen(con: _con, record: r));
    if (saved == true && mounted) toast(context, r == null ? '${spec.singular} record added.' : '${spec.singular} record updated.');
  }

  Future<void> _delete(CareRecord r) async {
    final yes = await confirm(context, 'Delete this ${spec.singular.toLowerCase()} record?', 'This removes the record of ${r.studentName}. It cannot be undone.', yes: 'Delete');
    if (!yes || !mounted) return;
    final res = await _con.remove(r);
    if (mounted) toast(context, res.$2, error: !res.$1);
  }

  @override
  Widget build(BuildContext context) {
    final q = _filter.trim().toLowerCase();
    final shown = q.isEmpty ? _con.records : _con.records.where((r) => r.searchText.contains(q)).toList();
    final students = _con.records.map((r) => r.studentId).toSet().length;
    return KitPage(
      title: widget.args.item.label.isEmpty ? spec.title : widget.args.item.label,
      bottom: _con.loading || _con.error != null ? null : PrimaryButton(label: 'Add ${spec.singular.toLowerCase()}', onPressed: () => _openForm()),
      child: _con.loading
          ? const AppLoader()
          : _con.error != null
              ? KitMessage(icon: Icons.error_outline_rounded, text: _con.error!, action: 'Try again', onAction: _con.load)
              : RefreshIndicator(
                  onRefresh: _con.load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                    CareHero(count: _con.records.length, label: 'records', chips: [Tag('$students students', fg: Colors.white, bg: Colors.white24)]),
                    const SizedBox(height: 12),
                    CareSearchBar(hint: 'Search records', onChanged: (v) => setState(() => _filter = v)),
                    const SizedBox(height: 12),
                    if (shown.isEmpty) Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('No records yet.', style: TextStyle(color: Brand.muted)))),
                    for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(r)),
                  ]),
                ),
    );
  }

  Widget _card(CareRecord r) {
    final facts = <CareFact>[];
    var hasDocument = false;
    for (final f in spec.fields) {
      if (f.key == 'date') continue;
      final v = r[f.key];
      if (f.kind == CareKind.file) {
        hasDocument = v.isNotEmpty;
        continue;
      }
      if (v.isEmpty) continue;
      facts.add(CareFact(f.label, f.unit.isEmpty ? v : '$v ${f.unit}'));
    }
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonAvatar(url: '', name: r.studentName, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.studentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Brand.ink)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                Tag(fmtDate(r['date'])),
                if (hasDocument) Tag.info('Document attached'),
              ]),
            ]),
          ),
          CareMenu(onEdit: () => _openForm(r), onDelete: () => _delete(r)),
        ]),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.only(right: 10), child: careFactGrid(facts)),
        ],
        if (hasDocument)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              onPressed: () => openUrl(context, StudentCareController.documentUrl(r['file'])),
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: const Text('Open document'),
            ),
          ),
      ]),
    );
  }
}

/// Add / edit form for one record, built from the spec's fields.
class CareFormScreen extends StatefulWidget {
  const CareFormScreen({super.key, required this.con, this.record});
  final StudentCareController con;
  final CareRecord? record;

  @override
  State<CareFormScreen> createState() => _CareFormScreenState();
}

class _CareFormScreenState extends State<CareFormScreen> with SubmitGuard {
  CareSpec get spec => widget.con.spec;
  CareRecord? get _r => widget.record;
  late String _studentId = _r?.studentId ?? '';
  late String _studentName = _r?.studentName ?? '';
  final _text = <String, TextEditingController>{};
  final _dates = <String, DateTime?>{};
  PickedFile? _file;

  @override
  void initState() {
    super.initState();
    for (final f in spec.fields) {
      final saved = _r?[f.key] ?? '';
      switch (f.kind) {
        case CareKind.date:
          _dates[f.key] = _r == null ? DateTime.now() : parseDay(saved);
        case CareKind.file:
          break;
        default:
          _text[f.key] = TextEditingController(text: saved);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _problem() {
    if (_studentId.isEmpty) return 'Select a student from the search results.';
    for (final f in spec.fields) {
      if (f.kind == CareKind.date && f.required && _dates[f.key] == null) return '${f.label} is required.';
      if (f.kind == CareKind.phone) {
        final bad = doctorContactError(_text[f.key]!.text);
        if (bad.isNotEmpty) return 'Enter a valid 10-digit doctor contact number starting with 6-9.';
      }
      if (f.kind == CareKind.number) {
        final t = _text[f.key]!.text.trim();
        if (t.isNotEmpty && double.tryParse(t) == null) return '${f.label} must be a number.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) return toast(context, problem, error: true);
    final values = <String, String>{};
    for (final f in spec.fields) {
      if (f.kind == CareKind.file) continue;
      values[f.key] = f.kind == CareKind.date ? ymd(_dates[f.key]!) : _text[f.key]!.text.trim();
    }
    String? message;
    var ok = false;
    await guarded(() async {
      final res = await widget.con.save(id: _r?.id, studentId: _studentId, values: values, file: _file);
      ok = res.$1;
      message = res.$2;
    });
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else if (message != null) {
      toast(context, message!, error: true);
    }
  }

  Widget _input(CareField f) {
    switch (f.kind) {
      case CareKind.date:
        return DateField(label: '${f.label}${f.required ? ' *' : ''}', value: _dates[f.key], onChanged: (d) => setState(() => _dates[f.key] = d));
      case CareKind.phone:
        final c = _text[f.key]!;
        final err = doctorContactError(c.text);
        return TextField(
          controller: c,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: f.label, counterText: '', errorText: err.isEmpty ? null : err),
        );
      case CareKind.number:
        return TextField(
          controller: _text[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: f.label, suffixText: f.unit.isEmpty ? null : f.unit),
        );
      case CareKind.multiline:
        return TextInput(label: f.label, controller: _text[f.key]!, lines: 3);
      case CareKind.file:
        final existing = _r?[f.key] ?? '';
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FileField(
            label: f.label,
            file: _file,
            extensions: const ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
            onChanged: (v) => setState(() => _file = v),
          ),
          if (existing.isNotEmpty && _file == null)
            Padding(padding: EdgeInsets.only(top: 6, left: 4), child: Text('A document is already attached. Choose a file to replace it.', style: TextStyle(color: Brand.muted, fontSize: 12))),
        ]);
      case CareKind.text:
        return TextInput(label: f.label, controller: _text[f.key]!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = spec.fields.where((f) => f.key == 'doctor_name' || f.key == 'doctor_contact').toList();
    final rest = spec.fields.where((f) => !people.contains(f)).toList();
    return KitPage(
      title: _r == null ? 'Add ${spec.singular.toLowerCase()}' : 'Edit ${spec.singular.toLowerCase()}',
      bottom: formBar(label: _r == null ? 'Save' : 'Update', busy: busy, onPressed: _save),
      child: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: careInputTheme()),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          careGroup('Student', Icons.person_outline_rounded, [
            StudentPickerField(
              api: widget.con.care,
              name: _studentName,
              locked: _r != null,
              onPicked: (st) => setState(() {
                _studentId = st.id;
                _studentName = '${st.enrollmentNo} / ${st.name}';
              }),
            ),
          ]),
          careGroup(spec.singular, spec.icon, [for (final f in rest) _input(f)]),
          if (people.isNotEmpty) careGroup('Doctor', Icons.local_hospital_outlined, [for (final f in people) _input(f)]),
        ]),
      ),
    );
  }
}
