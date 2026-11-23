import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_common/student_common.dart';
import 'map_optional_subjects_controller.dart';

/// Map Optional Subjects: pick a class, tick the elective subjects each student takes, save.
class MapOptionalSubjectsScreen extends StatefulWidget {
  const MapOptionalSubjectsScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<MapOptionalSubjectsScreen> createState() => _MapOptionalSubjectsScreenState();
}

class _MapOptionalSubjectsScreenState extends State<MapOptionalSubjectsScreen> {
  late final MapOptionalSubjectsController _con = MapOptionalSubjectsController(args: widget.args)..addListener(_onChange);
  final _query = TextEditingController();
  bool _editingFilters = true;

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.loadSections();
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    await _con.search();
    if (mounted && _con.searched) setState(() => _editingFilters = false);
  }

  Future<void> _save() async {
    final n = _con.changed.length;
    if (n == 0) {
      toast(context, 'No changes to save.', error: true);
      return;
    }
    final yes = await confirm(
      context,
      'Save optional subjects?',
      'The optional subjects of $n student${n == 1 ? '' : 's'} will be replaced with the ticked choices.',
      yes: 'Save',
    );
    if (!yes || !mounted) return;
    final (ok, message) = await _con.save();
    if (mounted) toast(context, message, error: !ok);
  }

  List<OptionalStudent> get _visible {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _con.students;
    return [for (final st in _con.students) if (st.name.toLowerCase().contains(q) || st.gr.toLowerCase().contains(q)) st];
  }

  Widget _filters() => SoftCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Choose class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          DropdownField(label: 'Section', options: _con.sections, value: _con.section, loading: _con.loadingSections, onChanged: _con.pickSection),
          gap(12),
          DropdownField(label: 'Standard', options: _con.standards, value: _con.standard, loading: _con.loadingStandards, onChanged: _con.pickStandard),
          gap(12),
          DropdownField(label: 'Division', options: _con.divisionOptions, value: _con.division, loading: _con.loadingDivisions, onChanged: _con.pickDivision),
          gap(14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _con.canSearch ? _search : null,
              icon: _con.searching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded),
              label: const Text('Search students'),
            ),
          ),
        ]),
      );

  Widget _summary() {
    final cls = [
      _con.sections.where((o) => o.id == _con.section).map((o) => o.label).firstOrNull,
      _con.standards.where((o) => o.id == _con.standard).map((o) => o.label).firstOrNull,
      _con.divisionOptions.where((o) => o.id == _con.division).map((o) => o.label).firstOrNull ?? 'All divisions',
    ].where((e) => (e ?? '').isNotEmpty).join(' · ');
    return SoftCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        const IconTile(Icons.school_outlined, size: 34),
        const SizedBox(width: 10),
        Expanded(child: Text(cls, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
        TextButton(onPressed: () => setState(() => _editingFilters = true), child: const Text('Change')),
      ]),
    );
  }

  Widget _bulk(List<OptionalStudent> list) => SoftCard(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Give a subject to everyone', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 2),
          const Text('Tap to tick or untick it for all students.', style: TextStyle(color: Brand.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final sub in _con.subjects)
              PickChip(label: sub.label, selected: _con.allHave(sub.id, list), onTap: () => _con.toggleAll(sub.id, list)),
          ]),
        ]),
      );

  Widget _student(OptionalStudent st) {
    final count = _con.mapped[st.id]?.length ?? 0;
    return SoftCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonAvatar(url: '', name: st.name, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(st.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              if (st.gr.isNotEmpty) Text('GR No. ${st.gr}', style: const TextStyle(color: Brand.muted, fontSize: 12)),
            ]),
          ),
          Tag(count == 0 ? 'None' : '$count chosen', fg: count == 0 ? Brand.ink2 : Brand.primaryDark, bg: count == 0 ? Brand.field : Brand.tint),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final sub in _con.subjects) PickChip(label: sub.label, selected: _con.has(st.id, sub.id), onTap: () => _con.toggle(st.id, sub.id)),
        ]),
      ]),
    );
  }

  List<Widget> _results() {
    if (_con.students.isEmpty) return [const KitMessage(icon: Icons.people_outline, text: 'No students found for this class.')];
    if (_con.subjects.isEmpty) {
      return [const KitMessage(icon: Icons.menu_book_outlined, text: 'No optional subjects are set for this standard. Mark subjects as elective in the Standard-Subject mapping first.')];
    }
    final list = _visible;
    return [
      _bulk(_con.students),
      gap(12),
      TextField(
        controller: _query,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'Search by name or GR no.', prefixIcon: Icon(Icons.search_rounded)),
      ),
      gap(12),
      if (list.isEmpty) const KitMessage(icon: Icons.search_off_rounded, text: 'No student matches this search.'),
      for (final st in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _student(st)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _con.searched && !_editingFilters;
    final changed = _con.changed.length;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Map Optional Subjects' : widget.args.item.label,
      bottom: showResults && _con.students.isNotEmpty && _con.subjects.isNotEmpty
          ? formBar(label: changed == 0 ? 'Save mapping' : 'Save mapping ($changed changed)', busy: _con.saving, onPressed: _save)
          : null,
      child: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: studentInputTheme()),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          StudentHero(
            title: 'Optional subjects',
            subtitle: 'Choose the elective subjects each student takes.',
            icon: Icons.fact_check_outlined,
            stats: showResults ? [('Students', '${_con.students.length}'), ('Subjects', '${_con.subjects.length}'), ('Changed', '$changed')] : const [],
          ),
          if (showResults) _summary() else _filters(),
          if (_con.error != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_con.error!, style: const TextStyle(color: Brand.err, fontWeight: FontWeight.w600))),
          if (showResults) ...[gap(12), ..._results()],
        ]),
      ),
    );
  }
}
