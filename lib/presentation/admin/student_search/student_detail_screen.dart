import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'student_search_controller.dart';

/// One student: a header, the details in clear cards, and Edit. Pops with true after a save so the list refreshes.
class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({super.key, required this.args, required this.student, required this.controller});
  final ScreenArgs args;
  final StudentRecord student;
  final StudentSearchController controller;

  @override
  Widget build(BuildContext context) {
    final st = student;
    return KitPage(
      title: 'Student',
      bottom: formBar(
        label: 'Edit student',
        busy: false,
        onPressed: () async {
          final saved = await push<bool>(context, StudentEditScreen(args: args, student: st, controller: controller));
          if (saved == true && context.mounted) Navigator.pop(context, true);
        },
      ),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            PersonAvatar(url: '', name: st.name, radius: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.name, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('GR ${st.enrollmentNo}', style: const TextStyle(color: Brand.champagne, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (st.cls.isNotEmpty) Tag(st.cls),
                  if (st.rollNo.isNotEmpty) Tag.neutral('Roll ${st.rollNo}'),
                  if (st.inactive) Tag.warn('Inactive'),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (st.mobile.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Expanded(child: FilledButton.tonalIcon(onPressed: () => openUrl(context, 'tel:${st.mobile}'), icon: const Icon(Icons.call_rounded, size: 18), label: const Text('Call'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.tonalIcon(onPressed: () => openUrl(context, 'sms:${st.mobile}'), icon: const Icon(Icons.sms_outlined, size: 18), label: const Text('Message'))),
            ]),
          ),
        _card('Personal', Icons.person_outline_rounded, [
          ('Gender', st.genderLabel),
          ('Date of birth', fmtDate(st.dob)),
          ('Blood group', st.bloodGroup),
          ('House', st.house),
        ]),
        _card('Family', Icons.family_restroom_rounded, [('Father', st.father), ('Mother', st.mother)]),
        _card('Contact', Icons.contact_phone_outlined, [('Mobile', st.mobile), ('Email', st.email), ('Address', st.address)]),
        _card('School', Icons.school_outlined, [
          ('Grade', st.grade),
          ('Standard', st.standard),
          ('Division', st.division),
          ('Roll no', st.rollNo),
          ('Student quota', st.quota),
          ('Unique id', st.uniqueId),
        ]),
      ]),
    );
  }

  Widget _card(String title, IconData icon, List<(String, String)> items) {
    final shown = items.where((e) => e.$2.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconTile(icon, size: 30),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          if (shown.isEmpty) Text('Nothing recorded yet.', style: TextStyle(color: Brand.muted, fontSize: 13)),
          for (final it in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 112, child: Text(it.$1, style: TextStyle(color: Brand.muted, fontSize: 13))),
                Expanded(child: Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Edit form for a student: the same fields as the web (name, GR, roll, class, house, family, contact…).
class StudentEditScreen extends StatefulWidget {
  const StudentEditScreen({super.key, required this.args, required this.student, required this.controller});
  final ScreenArgs args;
  final StudentRecord student;
  final StudentSearchController controller;

  @override
  State<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends State<StudentEditScreen> with SubmitGuard {
  late final StudentRecord _st = widget.student;
  late final _name = TextEditingController(text: _st.name);
  late final _admission = TextEditingController(text: _st.enrollmentNo);
  late final _roll = TextEditingController(text: _st.rollNo);
  late final _class = TextEditingController(text: _st.standard);
  late final _section = TextEditingController(text: _st.division);
  late final _house = TextEditingController(text: _st.house);
  late final _father = TextEditingController(text: _st.father);
  late final _mother = TextEditingController(text: _st.mother);
  late final _mobile = TextEditingController(text: _st.mobile);
  late final _email = TextEditingController(text: _st.email);
  late final _address = TextEditingController(text: _st.address);
  late final _blood = TextEditingController(text: _st.bloodGroup);
  String _gender = '';
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    final g = _st.gender.toLowerCase();
    _gender = g.startsWith('m') ? 'Male' : (g.startsWith('f') ? 'Female' : '');
    _dob = DateTime.tryParse(_st.dob.split(' ').first);
  }

  @override
  void dispose() {
    for (final c in [_name, _admission, _roll, _class, _section, _house, _father, _mother, _mobile, _email, _address, _blood]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (missing(context, _name.text, 'Please enter the student name.')) return;
    await guarded(() async {
      final (ok, message) = await widget.controller.update(_st, {
        'name': _name.text.trim(),
        'admission_no': _admission.text.trim(),
        'roll_no': _roll.text.trim(),
        'class_name': _class.text.trim(),
        'section_name': _section.text.trim(),
        'house': _house.text.trim(),
        'gender': _gender,
        'dob': _dob == null ? '' : ymd(_dob!),
        'father_name': _father.text.trim(),
        'mother_name': _mother.text.trim(),
        'mobile': _mobile.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'blood_group': _blood.text.trim(),
      });
      if (!mounted) return;
      toast(context, message, error: !ok);
      if (ok) Navigator.pop(context, true);
    });
  }

  InputDecorationTheme get _inputTheme => InputDecorationTheme(
        filled: true,
        fillColor: Brand.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.primary, width: 1.6)),
      );

  Widget _group(String title, IconData icon, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [IconTile(icon, size: 30), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]),
            const SizedBox(height: 14),
            for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Edit student',
        bottom: formBar(label: 'Save changes', busy: busy, onPressed: _save),
        child: Theme(
          data: Theme.of(context).copyWith(inputDecorationTheme: _inputTheme),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
            _group('Personal', Icons.person_outline_rounded, [
              TextInput(label: 'Full name *', controller: _name),
              SegmentedButton<String>(
                emptySelectionAllowed: true,
                segments: const [ButtonSegment(value: 'Male', label: Text('Male')), ButtonSegment(value: 'Female', label: Text('Female'))],
                selected: _gender.isEmpty ? <String>{} : {_gender},
                onSelectionChanged: (v) => setState(() => _gender = v.isEmpty ? '' : v.first),
              ),
              DateField(label: 'Date of birth', value: _dob, last: DateTime.now(), onChanged: (d) => setState(() => _dob = d)),
              Row(children: [
                Expanded(child: TextInput(label: 'Blood group', controller: _blood)),
                const SizedBox(width: 10),
                Expanded(child: TextInput(label: 'House', controller: _house)),
              ]),
            ]),
            _group('School', Icons.school_outlined, [
              TextInput(label: 'GR / admission no', controller: _admission),
              Row(children: [
                Expanded(child: TextInput(label: 'Class', controller: _class)),
                const SizedBox(width: 10),
                Expanded(child: TextInput(label: 'Division', controller: _section)),
              ]),
              TextInput(label: 'Roll no', controller: _roll),
            ]),
            _group('Family', Icons.family_restroom_rounded, [
              TextInput(label: 'Father name', controller: _father),
              TextInput(label: 'Mother name', controller: _mother),
            ]),
            _group('Contact', Icons.contact_phone_outlined, [
              TextInput(label: 'Mobile', controller: _mobile, keyboard: TextInputType.phone),
              TextInput(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
              TextInput(label: 'Address', controller: _address, lines: 2),
            ]),
          ]),
        ),
      );
}
