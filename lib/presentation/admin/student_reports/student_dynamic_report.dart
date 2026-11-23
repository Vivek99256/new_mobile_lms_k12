import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'report_common.dart';

class ReportField {
  const ReportField(this.key, this.label);

  /// `field_name/id`, the way the web form posts it.
  final String key;
  final String label;
}

/// State and API calls for the pick-your-columns student reports.
///  - Student Report: `GET /student/student_report` (the columns to choose from) and
///    `GET /student/show_student_report` (the students; the route also accepts POST, as the web form does).
///  - In-active Student Report: `GET /student/inactive_student_report` and
///    `GET /student/inactive_student_report/create`.
/// Both answer with `headers` (column key -> title) and `student_data` (rows).
class StudentDynamicReportController extends ChangeNotifier {
  StudentDynamicReportController({required this.args, required this.inactive});
  final ScreenArgs args;
  final bool inactive;
  LegacyApi get _api => args.api;

  String get _base =>
      inactive ? '/student/inactive_student_report' : '/student/student_report';

  static const orderOptions = [
    Opt('', 'Default (name)'),
    Opt('standard_id', 'Standard'),
    Opt('enrollment_no', 'GR no'),
    Opt('roll_no', 'Roll no'),
    Opt('last_name', 'Surname'),
  ];

  /// Columns that every row already carries; the rest are the user's chosen ones.
  static const _base4 = {
    'enrollment_no',
    'student_name',
    'standard',
    'division',
    'grade',
    'batch',
    'id',
    'roll_no',
  };

  bool loading = true;
  bool searching = false;
  bool searched = false;
  String? error;

  /// Column group (General Info, Contact…) -> its fields, in the server's order.
  final Map<String, List<ReportField>> groups = {};
  final Set<String> selected = {};

  CascadeSelection cascade = CascadeSelection();
  String orderBy = '';

  Map<String, String> headers = {};
  List<Map<String, String>> students = [];

  int get fieldCount => groups.values.fold(0, (a, l) => a + l.length);

  /// Chosen columns present in the result, in the server's order: key + title.
  List<(String, String)> get extraColumns => [
    for (final e in headers.entries)
      if (!_base4.contains(e.key) &&
          !_isIdentity(e) &&
          students.any((r) => (r[e.key] ?? '').trim().isNotEmpty))
        (e.key, e.value),
  ];

  /// A column that only repeats what the card header already shows (name, GR).
  static bool _isIdentity(MapEntry<String, String> e) {
    final l = e.value.trim().toLowerCase();
    return const {
      'gr no',
      'gr number',
      'gr',
      'enrollment no',
      'student name',
      'name',
      'student',
      'sr no',
    }.contains(l);
  }

  /// First phone-like value on a row, for the Call / Message buttons.
  String phoneOf(Map<String, String> row) {
    for (final e in headers.entries) {
      final k = '${e.key} ${e.value}'.toLowerCase();
      if (k.contains('mobile') ||
          k.contains('phone') ||
          k.contains('contact')) {
        final v = (row[e.key] ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
        if (v.length >= 8) return v;
      }
    }
    return '';
  }

  /// Number of students whose Gender column starts with [first] ("m" / "f"), or -1 when Gender was not chosen.
  int countGender(String first) {
    final key = headers.entries
        .where(
          (e) => e.value.trim().toLowerCase() == 'gender' || e.key == 'gender',
        )
        .map((e) => e.key)
        .firstOrNull;
    if (key == null) return -1;
    return students
        .where((r) => (r[key] ?? '').trim().toLowerCase().startsWith(first))
        .length;
  }

  /// The loaded list as CSV (name, GR, class and the chosen columns), for sharing to a spreadsheet.
  String toCsv() {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final extras = extraColumns;
    final out = StringBuffer()
      ..writeln(
        ['Name', 'GR', 'Class', for (final e in extras) e.$2].map(q).join(','),
      );
    for (final r in students) {
      final cls = [
        r['grade'],
        r['standard'],
        r['division'],
      ].where((e) => (e ?? '').isNotEmpty).join(' ');
      out.writeln(
        [
          r['student_name'] ?? '',
          r['enrollment_no'] ?? '',
          cls,
          for (final e in extras) r[e.$1] ?? '',
        ].map(q).join(','),
      );
    }
    return out.toString();
  }

  static String _pretty(String v) {
    final t = v.replaceAll('_', ' ').trim();
    return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
  }

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get(_base);
      if (statusOf(res) != '1')
        throw ApiException(
          LegacyApi.messageOf(
            res,
            "Couldn't load the report options. Try again.",
          ),
        );
      groups.clear();
      for (final g in m(res['data']).entries) {
        final list = <ReportField>[];
        final seen = <String>{};
        for (final f in rows(g.value)) {
          final name = s(f['field_name']);
          final id = s(f['id']);
          // The name is always shown; a field with no id cannot be requested.
          if (name.isEmpty || id.isEmpty || name == 'student_name') continue;
          final key = '$name/$id';
          if (seen.add(key))
            list.add(
              ReportField(
                key,
                _pretty(
                  s(f['field_label']).isEmpty ? name : s(f['field_label']),
                ),
              ),
            );
        }
        if (list.isNotEmpty) groups[g.key] = list;
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  void setOrder(String? v) {
    orderBy = v ?? '';
    notifyListeners();
  }

  void toggle(String key) {
    selected.contains(key) ? selected.remove(key) : selected.add(key);
    notifyListeners();
  }

  void setGroup(String group, bool on) {
    for (final f in groups[group] ?? const <ReportField>[]) {
      on ? selected.add(f.key) : selected.remove(f.key);
    }
    notifyListeners();
  }

  void clearFields() {
    selected.clear();
    notifyListeners();
  }

  Future<void> search() async {
    searching = true;
    searched = true;
    error = null;
    students = [];
    notifyListeners();
    try {
      final params = <String, dynamic>{
        if (cascade.sectionId != null) 'grade': cascade.sectionId,
        if (cascade.standardId != null) 'standard': cascade.standardId,
        if (cascade.divisionId != null) 'division': cascade.divisionId,
        if (orderBy.isNotEmpty) 'order_by': orderBy,
        'submit': 'Search',
        for (final (i, k) in selected.indexed) 'dynamicFields[$i]': k,
      };
      final Map<String, dynamic> res;
      if (inactive) {
        res = await _api.get(
          '/student/inactive_student_report/create',
          query: params,
        );
      } else {
        // The web form POSTs here, and the live server accepts that. A newer server also accepts GET, which is the
        // fallback if the POST is refused (for example by a host that enforces CSRF on this route).
        Map<String, dynamic>? posted;
        try {
          posted = await _api.post(
            '/student/show_student_report',
            body: params,
          );
        } on ApiException {
          posted = null;
        }
        res = (posted != null && statusOf(posted) == '1')
            ? posted
            : await _api.get('/student/show_student_report', query: params);
      }
      if (statusOf(res) != '1')
        throw ApiException(
          LegacyApi.messageOf(res, "Couldn't load the students. Try again."),
        );
      headers = {for (final e in m(res['headers']).entries) e.key: s(e.value)};
      final raw = res['student_data'];
      final list = raw is List
          ? raw
          : (raw is Map ? raw.values.toList() : const []);
      students = [
        for (final r in list)
          if (r is Map) {for (final e in r.entries) '${e.key}': s(e.value)},
      ];
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      searching = false;
      notifyListeners();
    }
  }
}

/// Student Report / In-active Student Report: choose a class and the columns, get a card per student.
class StudentDynamicReportScreen extends StatefulWidget {
  const StudentDynamicReportScreen({
    super.key,
    required this.args,
    required this.inactive,
  });
  final ScreenArgs args;
  final bool inactive;

  @override
  State<StudentDynamicReportScreen> createState() =>
      _StudentDynamicReportScreenState();
}

class _StudentDynamicReportScreenState
    extends State<StudentDynamicReportScreen> {
  late final StudentDynamicReportController _con =
      StudentDynamicReportController(
        args: widget.args,
        inactive: widget.inactive,
      )..addListener(_onChange);

  bool _changing = false; // show the filter card again after a search
  bool _showFields = false;
  String _q = '';
  final Set<String> _open = {};
  final Set<String> _openGroups = {};

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

  Future<void> _search() async {
    _open.clear();
    _q = '';
    await _con.search();
    if (mounted && _con.students.isNotEmpty) setState(() => _changing = false);
  }

  String get _title => widget.args.item.label.isEmpty
      ? (widget.inactive ? 'In-active Student Report' : 'Student Report')
      : widget.args.item.label;

  List<Map<String, String>> get _visible {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _con.students;
    return [
      for (final r in _con.students)
        if ('${r['student_name']} ${r['enrollment_no']} ${r['roll_no']}'
            .toLowerCase()
            .contains(q))
          r,
    ];
  }

  String _classLabel() {
    final c = _con.cascade;
    final parts = [
      c.sectionName,
      c.standardName,
      c.divisionName,
    ].where((e) => (e ?? '').isNotEmpty).toList();
    return parts.isEmpty ? 'All students' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = _con;
    if (c.loading)
      return KitPage(
        title: _title,
        child: const Center(child: CircularProgressIndicator()),
      );
    if (c.groups.isEmpty) {
      return KitPage(
        title: _title,
        child: KitMessage(
          icon: Icons.cloud_off_outlined,
          text: c.error ?? 'No report columns are set up.',
          action: 'Try again',
          onAction: c.init,
        ),
      );
    }
    final visible = c.students.isEmpty
        ? const <Map<String, String>>[]
        : _visible;
    return KitPage(
      title: _title,
      actions: [
        if (c.students.isNotEmpty)
          IconButton(
            tooltip: 'Share as CSV',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: c.toCsv(),
                subject: '$_title - ${_classLabel()}',
              ),
            ),
          ),
      ],
      child: withStudentInputs(
        context,
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: 1 + visible.length,
          itemBuilder: (_, i) =>
              i == 0 ? _top(c, visible) : _studentCard(c, visible[i - 1]),
        ),
      ),
    );
  }

  Widget _top(
    StudentDynamicReportController c,
    List<Map<String, String>> visible,
  ) {
    final loaded = c.students.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NavyStats(
          stats: [
            (
              widget.inactive ? 'Left students' : 'Students',
              loaded ? '${c.students.length}' : '–',
            ),
            if (loaded && c.countGender('m') >= 0)
              ('Boys', '${c.countGender('m')}'),
            if (loaded && c.countGender('f') >= 0)
              ('Girls', '${c.countGender('f')}'),
            (
              'Columns',
              loaded ? '${c.extraColumns.length}' : '${c.selected.length}',
            ),
          ],
          caption: loaded
              ? '${_classLabel()}  ·  showing ${visible.length} of ${c.students.length}'
              : (widget.inactive
                    ? 'Students whose enrolment has ended this year.'
                    : 'Pick a class and the columns you want, then load the list.'),
        ),
        gap(14),
        if (loaded && !_changing) _summaryStrip(c) else _filterCard(c),
        if (c.error != null) ...[
          gap(12),
          Notice(c.error!, kind: NoticeKind.error),
        ],
        if (c.searched &&
            !c.searching &&
            c.students.isEmpty &&
            c.error == null) ...[
          gap(8),
          const KitMessage(
            icon: Icons.people_outline,
            text: 'No students found.',
          ),
        ],
        if (loaded) ...[
          gap(12),
          reportSearchField(
            onChanged: (v) => setState(() => _q = v),
            hint: 'Find by name, GR or roll',
          ),
          if (c.extraColumns.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  final ids = [
                    for (final r in visible)
                      r['id'] ?? r['enrollment_no'] ?? '',
                  ];
                  _open.length >= ids.length
                      ? _open.clear()
                      : _open.addAll(ids);
                }),
                icon: Icon(
                  _open.length >= visible.length && visible.isNotEmpty
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 18,
                ),
                label: Text(
                  _open.length >= visible.length && visible.isNotEmpty
                      ? 'Collapse all'
                      : 'Expand all',
                ),
              ),
            ),
          gap(4),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: KitMessage(
                icon: Icons.filter_alt_off_outlined,
                text: 'No student matches this search.',
              ),
            ),
        ],
      ],
    );
  }

  Widget _filterCard(StudentDynamicReportController c) => SoftCard(
    radius: 20,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose students',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Leave the class empty to include everyone.',
          style: TextStyle(color: Brand.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        CascadeFilter(api: widget.args.api, onChanged: c.setCascade),
        gap(12),
        DropdownField(
          label: 'Order by',
          options: StudentDynamicReportController.orderOptions,
          value: c.orderBy,
          onChanged: c.setOrder,
        ),
        gap(12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _showFields = !_showFields),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Brand.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Brand.line),
            ),
            child: Row(
              children: [
                const IconTile(Icons.view_column_outlined, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${c.selected.length} of ${c.fieldCount} columns chosen',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  _showFields
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: Brand.muted,
                ),
              ],
            ),
          ),
        ),
        if (_showFields) ...[
          if (c.selected.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: c.clearFields,
                child: const Text('Clear all'),
              ),
            ),
          for (final g in c.groups.entries) _group(c, g.key, g.value),
        ] else if (c.selected.isNotEmpty) ...[
          gap(10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in c.groups.values)
                for (final f in g)
                  if (c.selected.contains(f.key)) Tag.neutral(f.label),
            ],
          ),
        ],
        gap(16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: c.searching ? null : _search,
            icon: c.searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(c.searching ? 'Loading…' : 'Load students'),
          ),
        ),
      ],
    ),
  );

  /// One column group (General Info, Contact…) that opens to show its choices as chips.
  Widget _group(
    StudentDynamicReportController c,
    String name,
    List<ReportField> fields,
  ) {
    final open = _openGroups.contains(name);
    final picked = fields.where((f) => c.selected.contains(f.key)).length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(
              () => open ? _openGroups.remove(name) : _openGroups.add(name),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name.isEmpty ? 'Other' : name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  if (picked > 0) Tag('$picked chosen'),
                  const SizedBox(width: 4),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Brand.muted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => c.setGroup(name, picked != fields.length),
                child: Text(
                  picked == fields.length ? 'Clear group' : 'Select group',
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in fields)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: c.selected.contains(f.key),
                    onSelected: (_) => c.toggle(f.key),
                    showCheckmark: false,
                    selectedColor: Brand.primary,
                    backgroundColor: Brand.surface,
                    labelStyle: TextStyle(
                      color: c.selected.contains(f.key)
                          ? Colors.white
                          : Brand.ink2,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: c.selected.contains(f.key)
                          ? Brand.primary
                          : Brand.line,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryStrip(StudentDynamicReportController c) => SoftCard(
    radius: 16,
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    child: Row(
      children: [
        const IconTile(Icons.school_outlined, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _classLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                c.extraColumns.isEmpty
                    ? 'Name, GR, class only'
                    : c.extraColumns.map((e) => e.$2).take(4).join(', ') +
                          (c.extraColumns.length > 4
                              ? ' +${c.extraColumns.length - 4}'
                              : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Brand.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _changing = true),
          child: const Text('Change'),
        ),
      ],
    ),
  );

  Widget _studentCard(
    StudentDynamicReportController c,
    Map<String, String> row,
  ) {
    final id = row['id'] ?? row['enrollment_no'] ?? '';
    final extras = c.extraColumns;
    final open = _open.contains(id);
    final cls = [
      row['grade'],
      row['standard'],
      row['division'],
    ].where((e) => (e ?? '').isNotEmpty).join(' · ');
    // A few "Label: value" lines so a closed card is still informative.
    final pills = [
      for (final e in extras)
        if ((row[e.$1] ?? '').trim().isNotEmpty) (e.$2, row[e.$1]!.trim()),
    ].take(3).toList();
    final phone = c.phoneOf(row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: open ? Brand.primary.withValues(alpha: 0.5) : Brand.line,
          ),
          boxShadow: Brand.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: extras.isEmpty
                  ? null
                  : () =>
                        setState(() => open ? _open.remove(id) : _open.add(id)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PersonAvatar(
                      url: '',
                      name: row['student_name'] ?? '',
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['student_name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Tag('GR ${row['enrollment_no'] ?? ''}'),
                              if (cls.isNotEmpty) Tag.neutral(cls),
                              if ((row['roll_no'] ?? '').isNotEmpty)
                                Tag.neutral('Roll ${row['roll_no']}'),
                            ],
                          ),
                          if (!open && pills.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final p in pills)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${p.$1}: ',
                                        style: const TextStyle(
                                          color: Brand.muted,
                                        ),
                                      ),
                                      TextSpan(
                                        text: p.$2,
                                        style: const TextStyle(
                                          color: Brand.ink2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    if (extras.isNotEmpty)
                      Icon(
                        open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: Brand.ink3,
                      ),
                  ],
                ),
              ),
            ),
            if (open)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                decoration: const BoxDecoration(
                  color: Brand.surface,
                  border: Border(top: BorderSide(color: Brand.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelValueGrid([
                      for (final e in extras) (e.$2, row[e.$1] ?? ''),
                    ]),
                    if (phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => openUrl(context, 'tel:$phone'),
                                icon: const Icon(Icons.call_rounded, size: 18),
                                label: const Text('Call'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => openUrl(context, 'sms:$phone'),
                                icon: const Icon(Icons.sms_outlined, size: 18),
                                label: const Text('Message'),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
