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

class _YStu {
  _YStu(Map<String, dynamic> r, this.perMonth)
      : id = s(r['id']),
        name = bStudentName(r),
        gr = s(r['enrollment_no']);
  final String id;
  final String name;
  final String gr;
  final Map<int, int> perMonth; // month number -> days present
}

/// Yearly Attendance Report: for one class and a date range, each student's present days per month against the
/// school's working days. `POST /student/yearly_student_attendance` with from_date, to_date, grade, standard, division.
class BYearlyAttendanceScreen extends StatefulWidget {
  const BYearlyAttendanceScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<BYearlyAttendanceScreen> createState() => _BYearlyAttendanceScreenState();
}

class _BYearlyAttendanceScreenState extends State<BYearlyAttendanceScreen> {
  CascadeSelection _cascade = CascadeSelection();
  DateTime _from = bAcademicStart();
  DateTime _to = DateTime.now();
  final _gr = TextEditingController();
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String _q = '';
  final Set<String> _open = {};

  List<_YStu> _students = [];
  List<int> _months = [];
  Map<int, int> _working = {};

  @override
  void dispose() {
    _gr.dispose();
    super.dispose();
  }

  int get _workingTotal => _months.fold(0, (a, m) => a + (_working[m] ?? 0));

  int _presentOf(_YStu st) => _months.fold(0, (a, m) => a + (st.perMonth[m] ?? 0));

  Future<void> _load() async {
    if (_cascade.standardId == null) {
      toast(context, 'Choose a standard first.', error: true);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _open.clear();
    });
    final err = await bGuard(() async {
      final res = await widget.args.api.post('/student/yearly_student_attendance', body: {
        'from_date': ymd(_from),
        'to_date': ymd(_to),
        if (_cascade.sectionId != null) 'grade': _cascade.sectionId,
        'standard': _cascade.standardId,
        if (_cascade.divisionId != null) 'division': _cascade.divisionId,
        if (_gr.text.trim().isNotEmpty) 'enrollment_no': _gr.text.trim(),
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res, 'No attendance found.'));
      final att = bMap(res['attendance_data']);
      _students = [
        for (final r in rows(res['student_data']))
          _YStu(r, {for (final e in bMap(att[s(r['id'])]).entries) bInt(e.key): bInt(e.value)}),
      ];
      final ms = res['month'];
      _months = [if (ms is List) for (final e in ms) bInt(e)];
      _working = {for (final e in bMap(res['working_day']).entries) bInt(e.key): bInt(e.value)};
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
    final shown = _students.where((e) => q.isEmpty || '${e.name} ${e.gr}'.toLowerCase().contains(q)).toList();
    final wt = _workingTotal;
    final presentAll = _students.fold<int>(0, (a, e) => a + _presentOf(e));
    final avg = (wt == 0 || _students.isEmpty) ? 0 : (presentAll * 100 / (wt * _students.length)).round();
    return bPage(context, widget.args.item.label.isEmpty ? 'Yearly Attendance' : widget.args.item.label, [
      BHero(
        icon: Icons.event_available_rounded,
        title: 'Yearly attendance',
        subtitle: _loaded ? '${bDate(ymd(_from))} – ${bDate(ymd(_to))}' : 'Choose a class and the dates.',
        stats: _loaded ? [('Students', '${_students.length}'), ('Working days', '$wt'), ('Avg present', '$avg%')] : const [],
      ),
      gap(14),
      BFilterCard(
        busy: _loading,
        onShow: _load,
        children: [
          CascadeFilter(api: widget.args.api, onChanged: (c) => _cascade = c),
          Row(children: [
            Expanded(child: DateField(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
            const SizedBox(width: 10),
            Expanded(child: DateField(label: 'To', value: _to, onChanged: (d) => setState(() => _to = d))),
          ]),
          TextField(controller: _gr, decoration: const InputDecoration(labelText: 'GR / admission no (optional)')),
        ],
      ),
      if (_error != null) ...[gap(12), Notice(_error!, kind: NoticeKind.warn)],
      if (_loaded && _students.isEmpty) ...[gap(8), const KitMessage(icon: Icons.people_outline, text: 'No students found.')],
      if (_students.isNotEmpty) ...[
        gap(12),
        BSearchBox(hint: 'Find a student', onChanged: (v) => setState(() => _q = v)),
        gap(12),
        for (final st in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(st, wt)),
      ],
    ]);
  }

  Widget _card(_YStu st, int wt) {
    final open = _open.contains(st.id);
    final present = _presentOf(st);
    final pct = wt == 0 ? 0.0 : present / wt;
    final tone = pct >= 0.85 ? Brand.ok : (pct >= 0.7 ? const Color(0xFFD97706) : Brand.err);
    return SoftCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => open ? _open.remove(st.id) : _open.add(st.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PersonAvatar(url: '', name: st.name, radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    if (st.gr.isNotEmpty) Text('GR ${st.gr}', style: TextStyle(color: Brand.muted, fontSize: 12)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${(pct * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: tone)),
                  Text('$present / $wt days', style: TextStyle(color: Brand.muted, fontSize: 11.5)),
                ]),
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.ink3),
              ]),
              const SizedBox(height: 10),
              BBar(pct, color: tone),
            ]),
          ),
        ),
        if (open)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.surface, border: Border(top: BorderSide(color: Brand.line))),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in _months) _month(m, st.perMonth[m] ?? 0, _working[m] ?? 0),
            ]),
          ),
      ]),
    );
  }

  Widget _month(int m, int present, int working) {
    final f = working == 0 ? 0.0 : present / working;
    return Container(
      width: 92,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Brand.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m >= 1 && m <= 12 ? bMonthsShort[m] : '$m', style: TextStyle(color: Brand.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('$present / $working', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 6),
        BBar(f),
      ]),
    );
  }
}
