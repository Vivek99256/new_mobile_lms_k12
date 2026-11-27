import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'bulk_student_update_controller.dart';
import '../../../ui/app_loader.dart';

/// Bulk Student Update: pick a class and the fields to change, edit students one by one (or fill a value into
/// everyone at once), and save only what changed.
class BulkStudentUpdateScreen extends StatefulWidget {
  const BulkStudentUpdateScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<BulkStudentUpdateScreen> createState() => _BulkStudentUpdateScreenState();
}

class _BulkStudentUpdateScreenState extends State<BulkStudentUpdateScreen> {
  late final BulkStudentUpdateController _con = BulkStudentUpdateController(args: widget.args)..addListener(_onChange);

  bool _changing = false; // show the search card again after students are loaded
  bool _showFields = false;
  bool _showFill = false;
  bool _onlyEdited = false;
  String _q = '';

  /// Students whose fields are open. Closed cards are one line, so a big class with every field stays light.
  final Set<String> _open = {};

  // Quick fill
  String? _fillField;
  String _fillValue = '';
  final _fillText = TextEditingController();

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
    _fillText.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ actions

  Future<bool> _discardOk() async {
    if (_con.searched && _con.dirtyCount > 0) {
      return confirm(context, 'Discard changes?', 'Changing the fields clears the loaded students and your unsaved edits.', yes: 'Discard');
    }
    return true;
  }

  Future<void> _toggle(String key) async {
    if (!await _discardOk() || !mounted) return;
    _con.toggleField(key);
    if (_con.searched) _con.clearResult();
  }

  Future<void> _selectAll() async {
    if (!await _discardOk() || !mounted) return;
    _con.toggleAllFields();
    if (_con.searched) _con.clearResult();
  }

  Future<void> _search() async {
    _open.clear();
    _fillField = null;
    _fillValue = '';
    _fillText.clear();
    await _con.search();
    if (mounted && _con.students.isNotEmpty) setState(() => _changing = false);
  }

  Future<void> _save() async {
    final n = _con.dirtyCount;
    if (n == 0) {
      toast(context, 'No changes to save.', error: true);
      return;
    }
    final go = await confirm(
      context,
      'Update $n student${n == 1 ? '' : 's'}?',
      'The changed values of $n student${n == 1 ? '' : 's'} will be saved now. This overwrites their current details.',
      yes: 'Update',
    );
    if (!go || !mounted) return;
    final (ok, message) = await _con.save();
    if (mounted) toast(context, message, error: !ok);
  }

  Future<void> _applyFill(List<Map<String, String>> targets) async {
    final field = _fillField;
    if (field == null) {
      toast(context, 'Choose a field first.', error: true);
      return;
    }
    final value = _con.fieldOf(field)?.type == 'select' || _con.fieldOf(field)?.type == 'date' ? _fillValue : _fillText.text.trim();
    final label = _con.fieldOf(field)?.label ?? field;
    final go = await confirm(
      context,
      'Fill $label for ${targets.length} students?',
      value.isEmpty ? 'This clears $label for ${targets.length} students (not saved until you press Update).' : 'Set $label to the chosen value for ${targets.length} students (not saved until you press Update).',
      yes: 'Fill',
    );
    if (!go || !mounted) return;
    _con.applyToAll(field, value, targets);
    toast(context, '$label filled for ${targets.length} students. Review, then press Update.');
  }

  // ------------------------------------------------------------------ data

  List<Map<String, String>> get _visible {
    final q = _q.trim().toLowerCase();
    return [
      for (final r in _con.students)
        if ((!_onlyEdited || _con.isDirty(r)) && (q.isEmpty || '${r['student_name']} ${r['enrollment_no']} ${r['roll_no']}'.toLowerCase().contains(q))) r,
    ];
  }

  String _classLabel() {
    final c = _con.cascade;
    final parts = [c.sectionName, c.standardName, c.divisionName].where((e) => (e ?? '').isNotEmpty).toList();
    return parts.isEmpty ? 'All students' : parts.join(' · ');
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final c = _con;
    final title = widget.args.item.label.isEmpty ? 'Bulk Student Update' : widget.args.item.label;
    if (c.loading) return KitPage(title: title, child: const AppLoader());
    if (c.fields.isEmpty) {
      return KitPage(title: title, child: KitMessage(icon: Icons.cloud_off_outlined, text: c.error ?? 'Nothing to update.', action: 'Try again', onAction: c.init));
    }
    final visible = c.searched ? _visible : const <Map<String, String>>[];
    return KitPage(
      title: title,
      bottom: c.students.isEmpty ? null : _saveBar(c),
      child: withStudentInputs(
        context,
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: 1 + visible.length,
          itemBuilder: (_, i) => i == 0 ? _top(c, visible) : _studentCard(c, visible[i - 1]),
        ),
      ),
    );
  }

  /// Everything above the student list.
  Widget _top(BulkStudentUpdateController c, List<Map<String, String>> visible) {
    final loaded = c.students.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _hero(c),
      gap(14),
      if (loaded && !_changing) _summaryStrip(c) else _searchCard(c),
      if (c.error != null) ...[gap(12), Notice(c.error!, kind: NoticeKind.error)],
      if (c.searched && c.students.isEmpty && c.error == null) ...[gap(8), const KitMessage(icon: Icons.people_outline, text: 'No students found.')],
      if (loaded) ...[
        gap(12),
        _quickFill(c, visible),
        gap(12),
        _filterRow(c),
        gap(12),
        if (visible.isEmpty) const Padding(padding: EdgeInsets.only(top: 24), child: KitMessage(icon: Icons.filter_alt_off_outlined, text: 'No student matches this filter.')),
      ],
    ]);
  }

  // ------------------------------------------------------------------ hero

  Widget _hero(BulkStudentUpdateController c) {
    final loaded = c.students.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.edit_note_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Update many students', style: TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Choose fields, edit, save only what changed.', style: TextStyle(color: Brand.champagne, fontSize: 12.5)),
            ]),
          ),
        ]),
        if (loaded) ...[
          const SizedBox(height: 14),
          Row(children: [
            _stat('${c.students.length}', 'Students', Colors.white),
            _vline(),
            _stat('${c.dirtyCount}', 'Edited', c.dirtyCount > 0 ? const Color(0xFFFDE68A) : Colors.white),
            _vline(),
            _stat('${c.searchedFields.length}', 'Fields', const Color(0xFF93C5FD)),
          ]),
        ],
      ]),
    );
  }

  Widget _vline() => Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 12), color: Colors.white.withValues(alpha: 0.16));

  Widget _stat(String v, String label, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Brand.champagne, fontSize: 11.5)),
        ]),
      );

  // ------------------------------------------------------------------ search card / summary

  Widget _searchCard(BulkStudentUpdateController c) => SoftCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _stepTitle('1', 'Choose students'),
          const SizedBox(height: 4),
          Text('Pick a class. (Leaving it empty loads the whole school, which is slow.)', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
          const SizedBox(height: 12),
          CascadeFilter(api: widget.args.api, onChanged: c.setCascade),
          gap(12),
          DropdownField(label: 'Order by', options: BulkStudentUpdateController.orderOptions, value: c.orderBy, onChanged: c.setOrder),
          gap(16),
          _stepTitle('2', 'Fields to update'),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _showFields = !_showFields),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.line)),
              child: Row(children: [
                const IconTile(Icons.tune_rounded, size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text('${c.selected.length} of ${c.fields.length} fields chosen', style: const TextStyle(fontWeight: FontWeight.w700))),
                Icon(_showFields ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.muted),
              ]),
            ),
          ),
          if (_showFields) ...[
            gap(8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _selectAll, child: Text(c.selected.length == c.fields.length ? 'Clear all' : 'Select all')),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in c.fields) _fieldChip(c, f),
            ]),
          ] else if (c.selected.isNotEmpty) ...[
            gap(10),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final k in c.selected) Tag.neutral(c.fieldOf(k)?.label ?? k)]),
          ],
          gap(16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: c.searching ? null : _search,
              icon: c.searching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded),
              label: Text(c.searching ? 'Searching…' : 'Load students'),
            ),
          ),
        ]),
      );

  Widget _fieldChip(BulkStudentUpdateController c, BulkField f) {
    final on = c.selected.contains(f.key);
    return ChoiceChip(
      label: Text(f.label),
      selected: on,
      onSelected: (_) => _toggle(f.key),
      showCheckmark: false,
      avatar: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
      selectedColor: Brand.primary,
      backgroundColor: Brand.surface,
      labelStyle: TextStyle(color: on ? Colors.white : Brand.ink2, fontWeight: FontWeight.w600, fontSize: 13),
      side: BorderSide(color: on ? Brand.primary : Brand.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _stepTitle(String n, String label) => Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Brand.primary, shape: BoxShape.circle),
          child: Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ]);

  Widget _summaryStrip(BulkStudentUpdateController c) => SoftCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          const IconTile(Icons.school_outlined, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_classLabel(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(c.searchedDefs.map((f) => f.label).take(4).join(', ') + (c.searchedDefs.length > 4 ? ' +${c.searchedDefs.length - 4}' : ''),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted, fontSize: 12)),
            ]),
          ),
          TextButton(
            onPressed: () async {
              if (!await _discardOk() || !mounted) return;
              setState(() => _changing = true);
            },
            child: const Text('Change'),
          ),
        ]),
      );

  // ------------------------------------------------------------------ quick fill

  Widget _quickFill(BulkStudentUpdateController c, List<Map<String, String>> visible) {
    final def = _fillField == null ? null : c.fieldOf(_fillField!);
    return Container(
      decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _showFill = !_showFill),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              IconTile(Icons.bolt_rounded, size: 32, fg: Color(0xFFB45309), bg: Brand.warn0),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Quick fill', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  Text('Put one value into a field for everyone shown', style: TextStyle(color: Brand.muted, fontSize: 12)),
                ]),
              ),
              Icon(_showFill ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.ink3),
            ]),
          ),
        ),
        if (_showFill)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(children: [
              DropdownField(
                label: 'Field',
                options: [for (final f in c.searchedDefs) Opt(f.key, f.label)],
                value: _fillField,
                onChanged: (v) => setState(() {
                  _fillField = v;
                  _fillValue = '';
                  _fillText.clear();
                }),
              ),
              if (def != null) ...[
                gap(12),
                if (def.type == 'select')
                  DropdownField(label: 'Value', options: c.options[def.key] ?? const [], value: _fillValue.isEmpty ? null : _fillValue, onChanged: (v) => setState(() => _fillValue = v ?? ''))
                else if (def.type == 'date')
                  DateField(label: 'Value', value: DateTime.tryParse(_fillValue), onChanged: (d) => setState(() => _fillValue = ymd(d)))
                else
                  TextField(controller: _fillText, decoration: InputDecoration(labelText: 'Value for ${def.label}')),
                gap(12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: visible.isEmpty ? null : () => _applyFill(visible),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: Text('Apply to ${visible.length} student${visible.length == 1 ? '' : 's'}'),
                  ),
                ),
              ],
            ]),
          ),
      ]),
    );
  }

  // ------------------------------------------------------------------ filter row

  Widget _filterRow(BulkStudentUpdateController c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Find a student by name, GR or roll',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: Brand.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          PillChip(label: 'All', selected: !_onlyEdited, onTap: () => setState(() => _onlyEdited = false)),
          PillChip(label: 'Edited (${c.dirtyCount})', selected: _onlyEdited, onTap: () => setState(() => _onlyEdited = true)),
          const Spacer(),
          if (c.dirtyCount > 0)
            TextButton.icon(
              onPressed: () async {
                final go = await confirm(context, 'Undo all edits?', 'All ${c.dirtyCount} edited students go back to their saved values.', yes: 'Undo all');
                if (go && mounted) c.resetAll();
              },
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Undo all'),
            ),
        ]),
      ]);

  // ------------------------------------------------------------------ student card

  /// A one-line summary of a closed card: the first few filled values.
  String _summary(BulkStudentUpdateController c, Map<String, String> row) {
    final vals = <String>[];
    for (final f in c.searchedDefs) {
      final v = (row[f.key] ?? '').trim();
      if (v.isEmpty) continue;
      vals.add(f.type == 'select' ? (c.options[f.key]?.where((o) => o.id == v).map((o) => o.label).firstOrNull ?? v) : v);
      if (vals.length == 3) break;
    }
    return vals.join('  ·  ');
  }

  Widget _studentCard(BulkStudentUpdateController c, Map<String, String> row) {
    final edited = c.isDirty(row);
    final id = row['id'] ?? '';
    final open = _open.contains(id);
    final summary = open ? '' : _summary(c, row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Brand.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: edited ? Brand.primary : Brand.line, width: edited ? 1.4 : 1),
          boxShadow: Brand.softShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => open ? _open.remove(id) : _open.add(id)),
            child: Container(
              color: edited ? Brand.tint : Colors.transparent,
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(children: [
                PersonAvatar(url: '', name: row['student_name'] ?? '', radius: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(row['student_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    if (summary.isNotEmpty) Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted, fontSize: 12)),
                  ]),
                ),
                if (edited) const Padding(padding: EdgeInsets.only(right: 6), child: Tag('Edited')),
                Icon(open ? Icons.expand_less_rounded : Icons.edit_outlined, color: open ? Brand.ink3 : Brand.primary, size: 20),
              ]),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              decoration: BoxDecoration(color: Brand.surface, border: Border(top: BorderSide(color: Brand.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final pair in _pairs(c.searchedDefs))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (var i = 0; i < pair.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: _cell(c, row, pair[i])),
                      ],
                    ]),
                  ),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (edited) TextButton.icon(onPressed: () => c.resetRow(row), icon: const Icon(Icons.undo_rounded, size: 17), label: const Text('Undo')),
                  TextButton.icon(onPressed: () => setState(() => _open.remove(id)), icon: const Icon(Icons.check_rounded, size: 17), label: const Text('Done')),
                ]),
              ]),
            ),
        ]),
      ),
    );
  }

  /// Two fields per row (address gets a full row) without LayoutBuilder / Wrap, which are costly per card.
  List<List<BulkField>> _pairs(List<BulkField> defs) {
    final out = <List<BulkField>>[];
    List<BulkField>? cur;
    for (final f in defs) {
      if (f.key == 'address') {
        out.add([f]);
        cur = null;
      } else if (cur == null) {
        cur = [f];
        out.add(cur);
      } else {
        cur.add(f);
        cur = null;
      }
    }
    return out;
  }

  /// One input. A changed value is tinted so you can see at a glance what will be saved.
  Widget _cell(BulkStudentUpdateController c, Map<String, String> row, BulkField f) {
    final changed = c.cellChanged(row, f.key);
    Widget field;
    switch (f.type) {
      case 'select':
        field = DropdownField(
          label: f.label,
          options: c.options[f.key] ?? const [],
          value: (row[f.key] ?? '').isEmpty ? null : row[f.key],
          onChanged: (v) => c.setValue(row, f.key, v ?? '', notify: true),
        );
      case 'date':
        field = DateField(
          label: f.label,
          value: DateTime.tryParse((row[f.key] ?? '').split(' ').first),
          onChanged: (v) => c.setValue(row, f.key, ymd(v), notify: true),
        );
      default:
        field = TextField(
          controller: c.textFor(row, f.key),
          keyboardType: f.type == 'email' ? TextInputType.emailAddress : TextInputType.text,
          onChanged: (v) => c.setValue(row, f.key, v),
          decoration: InputDecoration(labelText: f.label),
        );
    }
    return Container(
      decoration: BoxDecoration(color: changed ? Brand.tint : Colors.transparent, borderRadius: BorderRadius.circular(14)),
      child: field,
    );
  }

  // ------------------------------------------------------------------ save bar

  Widget _saveBar(BulkStudentUpdateController c) {
    final n = c.dirtyCount;
    return Row(children: [
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n == 0 ? 'No changes yet' : '$n student${n == 1 ? '' : 's'} changed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: n == 0 ? Brand.muted : Brand.ink)),
          Text(n == 0 ? 'Edit a student to enable saving' : 'Only these will be saved', style: TextStyle(color: Brand.muted, fontSize: 12)),
        ]),
      ),
      const SizedBox(width: 12),
      SizedBox(
        height: 48,
        width: 140,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Brand.ok, minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 20)),
          onPressed: c.saving || n == 0 ? null : _save,
          icon: c.saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded),
          label: Text(c.saving ? 'Saving…' : 'Update'),
        ),
      ),
    ]);
  }
}
