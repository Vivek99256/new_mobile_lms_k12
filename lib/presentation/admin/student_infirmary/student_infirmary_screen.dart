import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_care/care_common.dart';
import 'student_infirmary_controller.dart';
import '../../../ui/app_loader.dart';

/// Student Infirmary: record medical visits (complaint, treatment, case closure) for students.
class StudentInfirmaryScreen extends StatefulWidget {
  const StudentInfirmaryScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentInfirmaryScreen> createState() => _StudentInfirmaryScreenState();
}

class _StudentInfirmaryScreenState extends State<StudentInfirmaryScreen> {
  late final StudentInfirmaryController _con = StudentInfirmaryController(args: widget.args)..addListener(_onChange);
  String _filter = '';
  String _status = 'all'; // all | open | closed

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

  Future<void> _openForm([InfirmaryRecord? r]) async {
    final saved = await push<bool>(context, _InfirmaryFormScreen(con: _con, record: r));
    if (saved == true && mounted) toast(context, r == null ? 'Infirmary record added.' : 'Infirmary record updated.');
  }

  Future<void> _delete(InfirmaryRecord r) async {
    final yes = await confirm(context, 'Delete case ${r.caseNo}?', 'This removes the infirmary record of ${r.studentName}. It cannot be undone.', yes: 'Delete');
    if (!yes || !mounted) return;
    final res = await _con.remove(r);
    if (mounted) toast(context, res.$2, error: !res.$1);
  }

  List<InfirmaryRecord> get _shown {
    final q = _filter.trim().toLowerCase();
    return _con.records.where((r) {
      if (_status == 'open' && !r.isOpen) return false;
      if (_status == 'closed' && r.isOpen) return false;
      return q.isEmpty || r.searchText.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final open = _con.records.where((r) => r.isOpen).length;
    final shown = _shown;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Student Infirmary' : widget.args.item.label,
      bottom: _con.loading || _con.error != null
          ? null
          : PrimaryButton(label: 'Add infirmary record', onPressed: () => _openForm()),
      child: _con.loading
          ? const AppLoader()
          : _con.error != null
              ? KitMessage(icon: Icons.error_outline_rounded, text: _con.error!, action: 'Try again', onAction: _con.load)
              : RefreshIndicator(
                  onRefresh: _con.load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                    CareHero(
                      count: _con.records.length,
                      label: 'cases',
                      chips: [Tag('$open open', fg: Colors.white, bg: Colors.white24), Tag('${_con.records.length - open} closed', fg: Colors.white, bg: Colors.white24)],
                    ),
                    const SizedBox(height: 12),
                    CareSearchBar(hint: 'Search student, case, doctor or complaint', onChanged: (v) => setState(() => _filter = v)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, children: [
                      for (final f in const [('all', 'All'), ('open', 'Open'), ('closed', 'Closed')])
                        PillChip(label: f.$2, selected: _status == f.$1, onTap: () => setState(() => _status = f.$1)),
                    ]),
                    const SizedBox(height: 12),
                    if (shown.isEmpty)
                      Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('No infirmary records found.', style: TextStyle(color: Brand.muted)))),
                    for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(r)),
                  ]),
                ),
    );
  }

  Widget _card(InfirmaryRecord r) => SoftCard(
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
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Tag.neutral('Case ${r.caseNo}'),
                  r.isOpen ? Tag.warn('Open') : Tag.ok('Closed'),
                ]),
              ]),
            ),
            CareMenu(onEdit: () => _openForm(r), onDelete: () => _delete(r)),
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: careFactGrid([
              CareFact('Opened', fmtDate(r.date)),
              CareFact('Closed', r.isOpen ? 'Open' : fmtDate(r.closeDate)),
              CareFact('Complaint', r.complaint),
              CareFact('Disease', r.disease),
              CareFact('Symptoms', r.symptoms),
              CareFact('Treatments', r.treatments),
              CareFact('Doctor', r.doctorName),
              CareFact('Health center', r.healthCenter),
            ]),
          ),
          if (r.doctorContact.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Doctor contact  ${r.doctorContact}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
            ),
        ]),
      );
}

/// Add / edit form (same fields and rules as the web modal).
class _InfirmaryFormScreen extends StatefulWidget {
  const _InfirmaryFormScreen({required this.con, this.record});
  final StudentInfirmaryController con;
  final InfirmaryRecord? record;

  @override
  State<_InfirmaryFormScreen> createState() => _InfirmaryFormScreenState();
}

class _InfirmaryFormScreenState extends State<_InfirmaryFormScreen> with SubmitGuard {
  InfirmaryRecord? get _r => widget.record;
  late String _studentId = _r?.studentId ?? '';
  late String _studentName = _r?.studentName ?? '';
  late final _caseNo = TextEditingController(text: _r?.caseNo ?? widget.con.nextCaseNo);
  late final _doctor = TextEditingController(text: _r?.doctorName ?? '');
  late final _contact = TextEditingController(text: _r?.doctorContact ?? '');
  late final _complaint = TextEditingController(text: _r?.complaint ?? '');
  late final _symptoms = TextEditingController(text: _r?.symptoms ?? '');
  late final _disease = TextEditingController(text: _r?.disease ?? '');
  late final _treatments = TextEditingController(text: _r?.treatments ?? '');
  late final _center = TextEditingController(text: _r?.healthCenter ?? '');
  late DateTime? _date = _r == null ? DateTime.now() : parseDay(_r!.date);
  late DateTime? _close = _r == null ? null : parseDay(_r!.closeDate);

  @override
  void dispose() {
    for (final c in [_caseNo, _doctor, _contact, _complaint, _symptoms, _disease, _treatments, _center]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_studentId.isEmpty) return toast(context, 'Please select a student from the search results.', error: true);
    if (_caseNo.text.trim().isEmpty) return toast(context, 'Medical case number is required.', error: true);
    if (_date == null) return toast(context, 'Open date is required.', error: true);
    final bad = doctorContactError(_contact.text);
    if (bad.isNotEmpty) return toast(context, bad, error: true);
    String? message;
    var ok = false;
    await guarded(() async {
      final res = await widget.con.save(
        id: _r?.id,
        studentId: _studentId,
        caseNo: _caseNo.text.trim(),
        doctorName: _doctor.text,
        doctorContact: _contact.text,
        date: _date!,
        complaint: _complaint.text,
        symptoms: _symptoms.text,
        disease: _disease.text,
        treatments: _treatments.text,
        closeDate: _close,
        healthCenter: _center.text,
      );
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

  @override
  Widget build(BuildContext context) => KitPage(
        title: _r == null ? 'Add infirmary record' : 'Edit infirmary record',
        bottom: formBar(label: _r == null ? 'Save record' : 'Update record', busy: busy, onPressed: _save),
        child: Theme(
          data: Theme.of(context).copyWith(inputDecorationTheme: careInputTheme()),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
            careGroup('Case', Icons.medical_services_outlined, [
              StudentPickerField(
                api: widget.con.care,
                name: _studentName,
                locked: _r != null,
                onPicked: (st) => setState(() {
                  _studentId = st.id;
                  _studentName = '${st.enrollmentNo} / ${st.name}';
                }),
              ),
              Row(children: [
                Expanded(child: _readOnly('Case no', _caseNo.text)),
                const SizedBox(width: 10),
                Expanded(child: DateField(label: 'Open date *', value: _date, onChanged: (d) => setState(() => _date = d))),
              ]),
              DateField(label: 'Close date', value: _close, onChanged: (d) => setState(() => _close = d)),
            ]),
            careGroup('Visit', Icons.healing_outlined, [
              TextInput(label: 'Complaint', controller: _complaint, lines: 2),
              TextInput(label: 'Symptoms', controller: _symptoms, lines: 2),
              TextInput(label: 'Disease', controller: _disease),
              TextInput(label: 'Treatments', controller: _treatments, lines: 2),
            ]),
            careGroup('Doctor', Icons.local_hospital_outlined, [
              TextInput(label: 'Doctor name', controller: _doctor),
              TextField(
                controller: _contact,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Doctor contact',
                  counterText: '',
                  errorText: doctorContactError(_contact.text).isEmpty ? null : doctorContactError(_contact.text),
                ),
              ),
              TextInput(label: 'Health center', controller: _center),
            ]),
          ]),
        ),
      );

  /// The case number is assigned by the server (next number), so it is shown but not editable.
  Widget _readOnly(String label, String value) => InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18)),
        child: Text(value.isEmpty ? '-' : value),
      );
}
