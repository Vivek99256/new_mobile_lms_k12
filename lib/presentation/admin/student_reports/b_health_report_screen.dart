import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'b_common.dart';

/// Student Health Report: infirmary visits, vaccinations, height & weight or health records of students.
/// `POST /student/show_student_health_report` with health_type, grade, standard, division, from_date, to_date.
/// The server also sends `headers` (column -> label) for the chosen type, which this screen uses for the card lines.
class BHealthReportScreen extends StatefulWidget {
  const BHealthReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<BHealthReportScreen> createState() => _BHealthReportScreenState();
}

class _BHealthReportScreenState extends State<BHealthReportScreen> {
  static const _types = [
    Opt('student_infirmary', 'Infirmary'),
    Opt('student_vaccination', 'Vaccination'),
    Opt('student_height_weight', 'Height & weight'),
    Opt('student_health', 'Health records'),
  ];
  static const _icons = {
    'student_infirmary': Icons.local_hospital_outlined,
    'student_vaccination': Icons.vaccines_outlined,
    'student_height_weight': Icons.monitor_weight_outlined,
    'student_health': Icons.folder_shared_outlined,
  };

  CascadeSelection _cascade = CascadeSelection();
  String _type = 'student_infirmary';
  DateTime? _from;
  DateTime? _to;
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  String _q = '';
  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _headers = {};
  String _shownType = 'student_infirmary';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await bGuard(() async {
      final res = await widget.args.api.post('/student/show_student_health_report', body: {
        'health_type': _type,
        if (_cascade.sectionId != null) 'grade': _cascade.sectionId,
        if (_cascade.standardId != null) 'standard': _cascade.standardId,
        if (_cascade.divisionId != null) 'division': _cascade.divisionId,
        if (_from != null) 'from_date': ymd(_from!),
        if (_to != null) 'to_date': ymd(_to!),
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res, 'No records found.'));
      _rows = rows(res['health_data']);
      _headers = {for (final e in m(res['headers']).entries) e.key: s(e.value)};
      _shownType = _type;
    });
    if (!mounted) return;
    setState(() {
      _error = err;
      _loaded = err == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = _rows.where((r) => q.isEmpty || r.values.any((v) => v is! Map && v is! List && s(v).toLowerCase().contains(q))).toList();
    final students = _rows.map((r) => s(r['student_id'])).where((e) => e.isNotEmpty).toSet().length;
    final typeLabel = _types.firstWhere((t) => t.id == _shownType).label;
    return bPage(context, widget.args.item.label.isEmpty ? 'Student Health Report' : widget.args.item.label, [
      BHero(
        icon: _icons[_shownType] ?? Icons.health_and_safety_outlined,
        title: 'Student health',
        subtitle: _loaded ? typeLabel : 'Loading the records…',
        stats: _loaded ? [('Records', '${_rows.length}'), ('Students', '$students')] : const [],
      ),
      gap(14),
      BFilterCard(
        busy: _loading,
        label: 'Show records',
        onShow: _load,
        children: [
          DropdownField(label: 'Report type', options: _types, value: _type, onChanged: (v) => setState(() => _type = v ?? _type)),
          CascadeFilter(api: widget.args.api, onChanged: (c) => _cascade = c),
          Row(children: [
            Expanded(child: BOptionalDate(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
            const SizedBox(width: 10),
            Expanded(child: BOptionalDate(label: 'To', value: _to, onChanged: (d) => setState(() => _to = d))),
          ]),
        ],
      ),
      if (_error != null) ...[gap(12), Notice(_error!, kind: NoticeKind.error)],
      if (_loaded && _rows.isEmpty) ...[gap(8), const KitMessage(icon: Icons.health_and_safety_outlined, text: 'No records found for these filters.')],
      if (_rows.isNotEmpty) ...[
        gap(12),
        BSearchBox(hint: 'Find a student or doctor', onChanged: (v) => setState(() => _q = v)),
        gap(12),
        for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(r)),
      ],
    ]);
  }

  /// A column's value for display: dates as "17 Nov 2026", a stored file as "Attached".
  String _value(String key, dynamic v) {
    if (key == 'file') return s(v).isEmpty ? '' : 'Attached';
    if (key.contains('date')) return bDate(v);
    return s(v);
  }

  Widget _card(Map<String, dynamic> r) {
    final name = bStudentName(r);
    final lines = [
      for (final e in _headers.entries)
        if (e.key != 'student_name' && _value(e.key, r[e.key]).isNotEmpty) (e.value, _value(e.key, r[e.key])),
    ];
    final date = bDate(r['date']);
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonAvatar(url: '', name: name, radius: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
          if (date.isNotEmpty) Tag.neutral(date),
        ]),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final l in lines)
                if (!(l.$1.toLowerCase() == 'date' && date.isNotEmpty)) BKeyValue(l.$1, l.$2),
            ]),
          ),
        ],
      ]),
    );
  }
}
