import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'report_common.dart';

class DocStudent {
  DocStudent({required this.name, required this.enrollmentNo, required this.cls, required this.have, required this.missing});
  final String name;
  final String enrollmentNo;
  final String cls;
  final List<String> have;
  final List<String> missing;
  bool get complete => missing.isEmpty;
}

/// State and API calls for the Missing Document Report: `GET /student/missing_document_report/create` with
/// `user_type=student` and the class. The server gives each student's received document ids
/// (`document_list`) and the document types the class needs (`docment_type_data`); what is missing is the difference.
class MissingDocumentsController extends ChangeNotifier {
  MissingDocumentsController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  CascadeSelection cascade = CascadeSelection();
  bool busy = false;
  bool searched = false;
  String? error;
  List<DocStudent> students = [];
  int documentTypes = 0;

  int get completeCount => students.where((e) => e.complete).length;
  int get missingCount => students.length - completeCount;

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  /// A standard is needed: the required documents are mapped per standard, and without one every type would count.
  String? validate() {
    if (cascade.sectionId == null || cascade.standardId == null) return 'Please select a section and a standard.';
    return null;
  }

  Future<void> search() async {
    busy = true;
    searched = true;
    error = null;
    students = [];
    notifyListeners();
    try {
      final res = await _api.get('/student/missing_document_report/create', query: {
        'user_type': 'student',
        'grade': cascade.sectionId,
        'standard': cascade.standardId,
        if (cascade.divisionId != null) 'division': cascade.divisionId,
      });
      if (statusOf(res) != '1') throw ApiException(LegacyApi.messageOf(res, "Couldn't load the report. Try again."));
      final types = <String, String>{};
      for (final t in rows(res['docment_type_data'])) {
        final id = s(t['id']);
        if (id.isNotEmpty) types[id] = s(t['document_type']).isEmpty ? 'Document $id' : s(t['document_type']);
      }
      documentTypes = types.length;
      students = [
        for (final r in rows(res['result_report']))
          () {
            final got = s(r['document_list']).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
            return DocStudent(
              name: s(r['student_name']),
              enrollmentNo: s(r['enrollment_no']),
              cls: [s(r['standard_name']), s(r['division_name'])].where((e) => e.isNotEmpty).join(' · '),
              have: [for (final e in types.entries) if (got.contains(e.key)) e.value],
              missing: [for (final e in types.entries) if (!got.contains(e.key)) e.value],
            );
          }(),
      ];
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

enum _Show { all, missing, complete }

/// Missing Document Report: per class, which students have not handed in which documents.
class MissingDocumentsReportScreen extends StatefulWidget {
  const MissingDocumentsReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<MissingDocumentsReportScreen> createState() => _MissingDocumentsReportScreenState();
}

class _MissingDocumentsReportScreenState extends State<MissingDocumentsReportScreen> {
  late final MissingDocumentsController _con = MissingDocumentsController(args: widget.args)..addListener(_onChange);
  _Show _show = _Show.missing;
  String _q = '';
  bool _changing = false;
  final Set<int> _open = {};

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final problem = _con.validate();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    _open.clear();
    _q = '';
    await _con.search();
    if (mounted && _con.students.isNotEmpty) setState(() => _changing = false);
  }

  List<(int, DocStudent)> get _visible {
    final q = _q.trim().toLowerCase();
    return [
      for (var i = 0; i < _con.students.length; i++)
        if ((_show == _Show.all || (_show == _Show.missing ? !_con.students[i].complete : _con.students[i].complete)) &&
            (q.isEmpty || '${_con.students[i].name} ${_con.students[i].enrollmentNo}'.toLowerCase().contains(q)))
          (i, _con.students[i]),
    ];
  }

  String _classLabel() {
    final c = _con.cascade;
    return [c.sectionName, c.standardName, c.divisionName].where((e) => (e ?? '').isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = _con;
    final loaded = c.students.isNotEmpty;
    final list = loaded ? _visible : const <(int, DocStudent)>[];
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Missing Document Report' : widget.args.item.label,
      child: withStudentInputs(
        context,
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: 1 + list.length,
          itemBuilder: (_, i) => i == 0 ? _top(c, list) : _studentCard(list[i - 1].$1, list[i - 1].$2),
        ),
      ),
    );
  }

  Widget _top(MissingDocumentsController c, List<(int, DocStudent)> list) {
    final loaded = c.students.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      NavyStats(
        stats: [('Students', loaded ? '${c.students.length}' : '–'), ('Missing docs', loaded ? '${c.missingCount}' : '–'), ('Complete', loaded ? '${c.completeCount}' : '–')],
        caption: loaded ? '${c.documentTypes} document types are expected for this class.' : 'Pick a class to see who is missing documents.',
      ),
      gap(14),
      if (loaded && !_changing)
        SoftCard(
          radius: 16,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            const IconTile(Icons.school_outlined, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text(_classLabel(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
            TextButton(onPressed: () => setState(() => _changing = true), child: const Text('Change')),
          ]),
        )
      else
        SoftCard(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('The documents needed depend on the standard.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
            const SizedBox(height: 12),
            CascadeFilter(api: widget.args.api, onChanged: c.setCascade),
            gap(12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: c.busy ? null : _search,
                icon: c.busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search_rounded),
                label: Text(c.busy ? 'Loading…' : 'Show report'),
              ),
            ),
          ]),
        ),
      if (c.error != null) ...[gap(12), Notice(c.error!, kind: NoticeKind.error)],
      if (c.searched && !c.busy && c.students.isEmpty && c.error == null) ...[gap(8), const KitMessage(icon: Icons.people_outline, text: 'No students found.')],
      if (loaded) ...[
        gap(12),
        reportSearchField(onChanged: (v) => setState(() => _q = v), hint: 'Find by name or GR'),
        gap(10),
        Row(children: [
          PillChip(label: 'Missing (${c.missingCount})', selected: _show == _Show.missing, onTap: () => setState(() => _show = _Show.missing)),
          PillChip(label: 'Complete (${c.completeCount})', selected: _show == _Show.complete, onTap: () => setState(() => _show = _Show.complete)),
          PillChip(label: 'All', selected: _show == _Show.all, onTap: () => setState(() => _show = _Show.all)),
        ]),
        gap(12),
        if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 24), child: KitMessage(icon: Icons.verified_outlined, text: 'No student matches this filter.')),
      ],
    ]);
  }

  Widget _studentCard(int index, DocStudent st) {
    final open = _open.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
        child: Column(children: [
          InkWell(
            onTap: () => setState(() => open ? _open.remove(index) : _open.add(index)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                PersonAvatar(url: '', name: st.name, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    Text('GR ${st.enrollmentNo}${st.cls.isEmpty ? '' : '  ·  ${st.cls}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  ]),
                ),
                st.complete ? const Tag.ok('Complete') : Tag.warn('${st.missing.length} missing'),
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.ink3),
              ]),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: const BoxDecoration(color: Brand.surface, border: Border(top: BorderSide(color: Brand.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (st.missing.isNotEmpty) ...[
                  const Text('Missing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Brand.warn)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final d in st.missing) Tag.warn(d)]),
                ],
                if (st.have.isNotEmpty) ...[
                  if (st.missing.isNotEmpty) const SizedBox(height: 12),
                  const Text('Received', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Brand.ok)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final d in st.have) Tag.ok(d)]),
                ],
                if (st.missing.isEmpty && st.have.isEmpty) const Text('No documents are expected for this class.', style: TextStyle(color: Brand.muted, fontSize: 13)),
              ]),
            ),
        ]),
      ),
    );
  }
}
