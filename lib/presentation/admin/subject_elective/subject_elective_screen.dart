import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_common/student_common.dart';
import 'subject_elective_controller.dart';
import '../../../ui/app_loader.dart';

/// Subject Elective: which optional subject each standard + division offers. List, add, change, delete.
class SubjectElectiveScreen extends StatefulWidget {
  const SubjectElectiveScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<SubjectElectiveScreen> createState() => _SubjectElectiveScreenState();
}

class _SubjectElectiveScreenState extends State<SubjectElectiveScreen> {
  late final SubjectElectiveController _con = SubjectElectiveController(args: widget.args)..addListener(_onChange);

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.load();
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _open([ElectiveRow? row]) async {
    await push<void>(context, _ElectiveForm(con: _con, args: widget.args, row: row));
  }

  Future<void> _delete(ElectiveRow row) async {
    final yes = await confirm(context, 'Delete mapping?', 'The elective of ${row.standard} - ${row.division} will be removed.', yes: 'Delete');
    if (!yes || !mounted) return;
    final (ok, message) = await _con.delete(row);
    if (mounted) toast(context, message, error: !ok);
  }

  Widget _tile(ElectiveRow r) => SoftCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(children: [
          const IconTile(Icons.menu_book_outlined, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.standard} - ${r.division}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                r.hasSubject ? Tag(r.subject.isEmpty ? 'Subject ${r.subjectId}' : r.subject) : Tag.neutral('No elective'),
                if (r.code.trim().isNotEmpty) Tag.neutral(r.code.trim()),
              ]),
            ]),
          ),
          IconButton(tooltip: 'Change', onPressed: () => _open(r), icon: Icon(Icons.edit_outlined, color: Brand.primaryDark)),
          IconButton(tooltip: 'Delete', onPressed: () => _delete(r), icon: Icon(Icons.delete_outline_rounded, color: Brand.err)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_con.loading && _con.items.isEmpty) {
      body = const AppLoader();
    } else if (_con.error != null && _con.items.isEmpty) {
      body = KitMessage(icon: Icons.cloud_off_outlined, text: _con.error!, action: 'Try again', onAction: _con.load);
    } else {
      final withSubject = _con.items.where((e) => e.hasSubject).length;
      body = RefreshIndicator(
        onRefresh: _con.load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          StudentHero(
            title: 'Subject elective',
            subtitle: 'The optional subject of each standard and division.',
            icon: Icons.menu_book_outlined,
            stats: [('Mappings', '${_con.items.length}'), ('With elective', '$withSubject')],
          ),
          if (_con.items.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: KitMessage(icon: Icons.menu_book_outlined, text: 'No elective mappings yet.')),
          for (final r in _con.items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _tile(r)),
        ]),
      );
    }
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Subject Elective' : widget.args.item.label,
      bottom: _con.loading && _con.items.isEmpty ? null : formBar(label: 'Add mapping', busy: false, onPressed: () => _open()),
      child: body,
    );
  }
}

/// Add (class pickers) or change (class fixed) the elective subject of one standard + division.
class _ElectiveForm extends StatefulWidget {
  const _ElectiveForm({required this.con, required this.args, this.row});
  final SubjectElectiveController con;
  final ScreenArgs args;
  final ElectiveRow? row;

  @override
  State<_ElectiveForm> createState() => _ElectiveFormState();
}

class _ElectiveFormState extends State<_ElectiveForm> {
  CascadeSelection _sel = CascadeSelection();
  List<Opt> _subjects = [];
  String? _subject;
  bool _loadingSubjects = false;
  String? _subjectsFor;

  bool get _editing => widget.row != null;
  String? get _standardId => _editing ? widget.row!.standardId : _sel.standardId;
  String? get _divisionId => _editing ? widget.row!.divisionId : _sel.divisionId;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _subject = widget.row!.hasSubject ? widget.row!.subjectId : '0';
      _loadSubjects(widget.row!.standardId);
    }
  }

  Future<void> _loadSubjects(String standardId) async {
    if (_subjectsFor == standardId) return;
    _subjectsFor = standardId;
    setState(() {
      _loadingSubjects = true;
      _subjects = [];
      if (!_editing) _subject = null;
    });
    try {
      final list = await widget.con.electiveSubjects(standardId);
      if (!mounted || _subjectsFor != standardId) return;
      setState(() => _subjects = [const Opt('0', 'None (no elective)'), ...list]);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted && _subjectsFor == standardId) setState(() => _loadingSubjects = false);
    }
  }

  void _onClass(CascadeSelection v) {
    setState(() => _sel = v);
    final std = v.standardId;
    if (std == null) {
      _subjectsFor = null;
      setState(() {
        _subjects = [];
        _subject = null;
      });
    } else {
      _loadSubjects(std);
    }
  }

  Future<void> _save() async {
    final std = _standardId, div = _divisionId;
    if (missing(context, std, 'Please select a standard.') || missing(context, div, 'Please select a division.')) return;
    if (missing(context, _subject, 'Please select the optional subject.')) return;
    if (!_editing && widget.con.exists(std!, div!)) {
      toast(context, 'A mapping for this standard and division already exists. Change it from the list.', error: true);
      return;
    }
    final (ok, message) = await widget.con.save(standardId: std!, divisionId: div!, subjectId: _subject!);
    if (!mounted) return;
    toast(context, message, error: !ok);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return KitPage(
      title: _editing ? 'Change elective' : 'Add elective mapping',
      bottom: formBar(label: _editing ? 'Save changes' : 'Save mapping', busy: widget.con.saving, onPressed: _save),
      child: Theme(
        data: Theme.of(context).copyWith(inputDecorationTheme: studentInputTheme()),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          StudentHero(
            title: _editing ? '${row!.standard} - ${row.division}' : 'New mapping',
            subtitle: _editing ? 'Pick the subject this class takes as its elective.' : 'Choose a class and its optional subject.',
            icon: Icons.menu_book_outlined,
          ),
          SoftCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!_editing) ...[
                const Text('Class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 12),
                CascadeFilter(api: widget.args.api, onChanged: _onClass),
                gap(16),
              ],
              const Text('Optional subject', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              DropdownField(label: 'Optional subject *', options: _subjects, value: _subject, loading: _loadingSubjects, onChanged: (v) => setState(() => _subject = v)),
              if (!_loadingSubjects && _standardId != null && _subjects.length <= 1)
                Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text('No elective subjects are marked for this standard.', style: TextStyle(fontSize: 12, color: Brand.muted)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
