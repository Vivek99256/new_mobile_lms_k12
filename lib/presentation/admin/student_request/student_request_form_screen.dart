import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_common/student_common.dart';
import 'student_request_controller.dart';

/// Raise a student change request: pick a class, tick the students, choose a request type for each.
class StudentRequestFormScreen extends StatefulWidget {
  const StudentRequestFormScreen({super.key, required this.con, required this.args});
  final StudentRequestController con;
  final ScreenArgs args;

  @override
  State<StudentRequestFormScreen> createState() => _StudentRequestFormScreenState();
}

class _StudentRequestFormScreenState extends State<StudentRequestFormScreen> {
  StudentRequestController get _con => widget.con;
  CascadeSelection _sel = CascadeSelection();
  final _query = TextEditingController();

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.addListener(_onChange);
    // A fresh form each time it opens.
    _con.searched = false;
    _con.roster = [];
    _con.selected.clear();
    _con.formError = null;
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _query.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = _con.validate();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    final n = _con.selected.length;
    final yes = await confirm(context, 'Submit requests?', 'A request will be raised for $n student${n == 1 ? '' : 's'}.', yes: 'Submit');
    if (!yes || !mounted) return;
    final (ok, message) = await _con.submit();
    if (!mounted) return;
    toast(context, message, error: !ok);
    if (ok) Navigator.pop(context);
  }

  List<RosterStudent> get _visible {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _con.roster;
    return [for (final st in _con.roster) if (st.name.toLowerCase().contains(q) || st.gr.toLowerCase().contains(q)) st];
  }

  Widget _studentCard(RosterStudent st) {
    final on = _con.selected.contains(st.id);
    final d = _con.draft(st.id);
    final type = _con.typeOf(d.typeId);
    return SoftCard(
      radius: 16,
      borderColor: on ? Brand.primary : Brand.line,
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _con.toggleStudent(st.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
            child: Row(children: [
              Checkbox(value: on, onChanged: (_) => _con.toggleStudent(st.id)),
              PersonAvatar(url: st.image, name: st.name, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(st.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  Text([if (st.gr.isNotEmpty) 'GR ${st.gr}', st.cls].where((e) => e.isNotEmpty).join('  ·  '), style: const TextStyle(color: Brand.muted, fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),
        if (on)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(children: [
              DropdownField(
                label: 'Request type *',
                options: [for (final t in _con.types) Opt(t.id, t.title)],
                value: d.typeId.isEmpty ? null : d.typeId,
                onChanged: (v) => _con.setType(st.id, v ?? ''),
              ),
              gap(10),
              TextInput(label: type == null ? 'Document' : (type.proofRequired ? '${type.proofLabel} *' : type.proofLabel), controller: d.proof),
              gap(10),
              TextInput(label: 'Reason', controller: d.reason),
              gap(10),
              TextInput(label: 'Description', controller: d.description, lines: 2),
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showList = _con.searched;
    return KitPage(
      title: 'Raise request',
      bottom: showList && _con.roster.isNotEmpty
          ? formBar(label: _con.selected.isEmpty ? 'Submit' : 'Submit (${_con.selected.length} selected)', busy: _con.submitting, onPressed: _submit)
          : null,
      child: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: studentInputTheme()),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          const StudentHero(title: 'Raise a request', subtitle: 'Pick a class, tick students and choose the request type.', icon: Icons.note_add_outlined),
          SoftCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Find students', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              CascadeFilter(api: widget.args.api, onChanged: (v) => _sel = v),
              gap(14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _con.searching ? null : () => _con.searchStudents(_sel),
                  icon: _con.searching
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search_rounded),
                  label: const Text('Search students'),
                ),
              ),
            ]),
          ),
          if (_con.formError != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_con.formError!, style: const TextStyle(color: Brand.err, fontWeight: FontWeight.w600))),
          if (showList) ...[
            gap(12),
            if (_con.types.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Brand.warn0, borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'No request types are configured for this academic year, so a request type cannot be chosen yet. Add them in the Student Change Request Type master first.',
                  style: TextStyle(color: Brand.warn, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            if (_con.roster.isEmpty)
              const KitMessage(icon: Icons.people_outline, text: 'No students found for this selection.')
            else ...[
              TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Search by name or GR no.', prefixIcon: Icon(Icons.search_rounded)),
              ),
              gap(12),
              for (final st in _visible) Padding(padding: const EdgeInsets.only(bottom: 10), child: _studentCard(st)),
            ],
          ],
        ]),
      ),
    );
  }
}
