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

class _Stu {
  _Stu(Map<String, dynamic> r, this.days)
      : id = s(r['id']),
        name = bStudentName(r),
        gr = s(r['enrollment_no']);
  final String id;
  final String name;
  final String gr;
  final Map<int, String> days; // day of month -> attendance code

  int count(String code) => days.values.where((c) => c.toUpperCase() == code).length;
  int get present => count('P');
  int get absent => count('A');
  int get other => days.length - present - absent;
}

/// Monthwise Attendance Report: for one class and month, each student's attendance code for every day.
/// `POST /student/show_monthwise_student_attendance` with month, year, grade, standard, division.
class BMonthwiseAttendanceScreen extends StatefulWidget {
  const BMonthwiseAttendanceScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<BMonthwiseAttendanceScreen> createState() => _BMonthwiseAttendanceScreenState();
}

class _BMonthwiseAttendanceScreenState extends State<BMonthwiseAttendanceScreen> {
  CascadeSelection _cascade = CascadeSelection();
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;
  final _gr = TextEditingController();
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String _q = '';
  final Set<String> _open = {};

  List<_Stu> _students = [];
  int _daysInMonth = 30;
  Set<int> _sundays = {}, _holidays = {}, _vacations = {}, _events = {};

  @override
  void dispose() {
    _gr.dispose();
    super.dispose();
  }

  Set<int> _ints(dynamic v) => {
        if (v is List) for (final e in v) bInt(e),
        if (v is Map) for (final e in v.values) bInt(e),
      };

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
      final res = await widget.args.api.post('/student/show_monthwise_student_attendance', body: {
        'month': _month.toString().padLeft(2, '0'),
        'year': '$_year',
        if (_cascade.sectionId != null) 'grade': _cascade.sectionId,
        'standard': _cascade.standardId,
        if (_cascade.divisionId != null) 'division': _cascade.divisionId,
        if (_gr.text.trim().isNotEmpty) 'enrollment_no': _gr.text.trim(),
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res, 'No attendance taken in this month.'));
      final att = bMap(res['attendance_data']);
      _students = [
        for (final r in rows(res['student_data']))
          _Stu(r, {for (final e in bMap(att[s(r['id'])]).entries) bInt(e.key): s(e.value)}),
      ];
      _daysInMonth = bInt(res['to_date']) == 0 ? 30 : bInt(res['to_date']);
      _sundays = _ints(res['sundays']);
      _holidays = _ints(res['holidays']);
      _vacations = _ints(res['vacations']);
      _events = _ints(res['events']);
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
    final totalMarks = _students.fold<int>(0, (a, e) => a + e.days.length);
    final totalPresent = _students.fold<int>(0, (a, e) => a + e.present);
    final avg = totalMarks == 0 ? 0 : (totalPresent * 100 / totalMarks).round();
    final now = DateTime.now();
    return bPage(context, widget.args.item.label.isEmpty ? 'Monthwise Attendance' : widget.args.item.label, [
      BHero(
        icon: Icons.calendar_month_rounded,
        title: 'Monthwise attendance',
        subtitle: _loaded ? '${bMonths[_month]} $_year · $_daysInMonth days' : 'Choose a class and a month.',
        stats: _loaded ? [('Students', '${_students.length}'), ('Avg present', '$avg%'), ('Days', '$_daysInMonth')] : const [],
      ),
      gap(14),
      BFilterCard(
        busy: _loading,
        onShow: _load,
        children: [
          CascadeFilter(api: widget.args.api, onChanged: (c) => _cascade = c),
          Row(children: [
            Expanded(
              flex: 3,
              child: DropdownField(
                label: 'Month',
                options: [for (var i = 1; i <= 12; i++) Opt('$i', bMonths[i])],
                value: '$_month',
                onChanged: (v) => setState(() => _month = int.tryParse(v ?? '') ?? _month),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownField(
                label: 'Year',
                options: [for (var y = now.year; y >= now.year - 3; y--) Opt('$y', '$y')],
                value: '$_year',
                onChanged: (v) => setState(() => _year = int.tryParse(v ?? '') ?? _year),
              ),
            ),
          ]),
          TextField(controller: _gr, decoration: const InputDecoration(labelText: 'GR / admission no (optional)')),
        ],
      ),
      if (_error != null) ...[gap(12), Notice(_error!, kind: NoticeKind.warn)],
      if (_loaded && _students.isEmpty) ...[gap(8), const KitMessage(icon: Icons.people_outline, text: 'No students found.')],
      if (_students.isNotEmpty) ...[
        gap(12),
        _legend(),
        gap(12),
        BSearchBox(hint: 'Find a student', onChanged: (v) => setState(() => _q = v)),
        gap(12),
        for (final st in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _studentCard(st)),
      ],
    ]);
  }

  Widget _legend() => Wrap(spacing: 8, runSpacing: 6, children: [
        Tag.ok('P present'),
        Tag.err('A absent'),
        Tag.warn('Other'),
        Tag.neutral('S Sunday'),
        Tag.info('H holiday'),
        Tag('V vacation'),
      ]);

  Widget _studentCard(_Stu st) {
    final open = _open.contains(st.id);
    final marked = st.days.length;
    final pct = marked == 0 ? 0.0 : st.present / marked;
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
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.ink3),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Tag.ok('P ${st.present}'),
                const SizedBox(width: 6),
                Tag.err('A ${st.absent}'),
                if (st.other > 0) ...[const SizedBox(width: 6), Tag.warn('Other ${st.other}')],
                const Spacer(),
                Text('${(pct * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              BBar(pct),
            ]),
          ),
        ),
        if (open)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Brand.surface, border: Border(top: BorderSide(color: Brand.line))),
            child: Wrap(spacing: 5, runSpacing: 5, children: [for (var d = 1; d <= _daysInMonth; d++) _day(d, st.days[d])]),
          ),
      ]),
    );
  }

  /// One day: the attendance code if taken, else S / H / V / E for the day's kind, else a dash.
  Widget _day(int d, String? code) {
    String label;
    Color fg, bg;
    final c = (code ?? '').toUpperCase();
    if (c.isNotEmpty) {
      label = c;
      (fg, bg) = c == 'P' ? (Brand.ok, Brand.ok0) : (c == 'A' ? (Brand.err, Brand.err0) : (Brand.warn, Brand.warn0));
    } else if (_holidays.contains(d)) {
      (label, fg, bg) = ('H', Brand.info, Brand.info0);
    } else if (_vacations.contains(d)) {
      (label, fg, bg) = ('V', Brand.primaryDark, Brand.tint);
    } else if (_sundays.contains(d)) {
      (label, fg, bg) = ('S', Brand.ink2, Brand.field);
    } else if (_events.contains(d)) {
      (label, fg, bg) = ('E', Brand.warn, Brand.warn0);
    } else {
      (label, fg, bg) = ('–', Brand.muted, Colors.white);
    }
    return Container(
      width: 38,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Brand.line)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$d', style: TextStyle(fontSize: 10, color: Brand.muted, height: 1.1)),
        Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg, height: 1.2)),
      ]),
    );
  }
}
