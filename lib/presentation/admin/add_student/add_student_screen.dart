import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter, TextInputType;

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'add_student_controller.dart';

/// Add Student: class, personal, family, contact and other details; the next GR number is filled in for you.
class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  late final AddStudentController _con = AddStudentController(args: widget.args)..addListener(_onChange);

  @override
  void initState() {
    super.initState();
    _con.init();
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

  Future<void> _save() async {
    final problem = _con.validate();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    final (ok, message) = await _con.submit();
    if (mounted) toast(context, message, error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final c = _con;
    final title = widget.args.item.label.isEmpty ? 'Add Student' : widget.args.item.label;
    if (c.loading) return KitPage(title: title, child: const Center(child: CircularProgressIndicator()));
    return KitPage(
      title: title,
      bottom: formBar(label: 'Save student', busy: c.saving, onPressed: _save),
      child: withStudentInputs(
        context,
        RefreshIndicator(
          onRefresh: c.init,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
            if (c.error != null) ...[
              Notice(c.error!, kind: NoticeKind.error),
              gap(12),
            ],
            StudentGroup(title: 'Class', icon: Icons.school_outlined, children: [
              CascadeFilter(key: ValueKey('cascade-${c.epoch}'), api: widget.args.api, onChanged: c.setCascade),
            ]),
            StudentGroup(title: 'Personal', icon: Icons.person_outline_rounded, children: [
              TextField(
                controller: c.text['enrollment_no'],
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'GR no. *',
                  helperText: 'Generated automatically',
                  suffixIcon: c.loadingGr
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(tooltip: 'Get a new GR number', icon: const Icon(Icons.refresh_rounded), onPressed: c.fetchGr),
                ),
              ),
              TextInput(label: 'First name *', controller: c.text['first_name']!),
              TextInput(label: 'Middle name', controller: c.text['middle_name']!),
              TextInput(label: 'Last name *', controller: c.text['last_name']!),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: [for (final g in AddStudentController.genders) ButtonSegment(value: g.id, label: Text(g.label))],
                  selected: c.gender.isEmpty ? <String>{} : {c.gender},
                  onSelectionChanged: (v) => c.setGender(v.isEmpty ? '' : v.first),
                ),
              ),
              DateField(label: 'Date of birth *', value: c.dob, last: DateTime.now(), onChanged: c.setDob),
              TextInput(label: 'Roll no', controller: c.text['roll_no']!),
            ]),
            StudentGroup(title: 'Family', icon: Icons.family_restroom_rounded, children: [
              TextInput(label: "Father's name", controller: c.text['father_name']!),
              TextInput(label: 'Mother name', controller: c.text['mother_name']!),
            ]),
            StudentGroup(title: 'Contact', icon: Icons.contact_phone_outlined, children: [
              TextField(
                controller: c.text['mobile'],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: const InputDecoration(labelText: 'Mobile *', hintText: '10 digits'),
              ),
              TextInput(label: 'Email *', controller: c.text['email']!, keyboard: TextInputType.emailAddress),
              TextInput(label: 'Address', controller: c.text['address']!, lines: 2),
            ]),
            StudentGroup(title: 'Other', icon: Icons.tune_rounded, children: [
              DropdownField(
                label: 'Blood group *',
                options: [for (final b in AddStudentController.bloodGroups) Opt(b, b)],
                value: c.bloodGroup,
                onChanged: c.setBlood,
              ),
              DropdownField(label: 'Student quota *', options: c.quotas, value: c.quota, onChanged: c.setQuota),
              DropdownField(label: 'House', options: c.houses, value: c.house, onChanged: c.setHouse),
            ]),
            const Text('Fields marked * are required. The student is enrolled in the current academic year.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}
