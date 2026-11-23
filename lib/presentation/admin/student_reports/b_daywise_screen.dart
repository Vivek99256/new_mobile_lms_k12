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

class _ClassRow {
  _ClassRow(Map<String, dynamic> r)
      : name = s(r['standard_name']),
        boys = bInt(r['BOY']),
        girls = bInt(r['GIRL']),
        boysPresent = bInt(r['TBP']),
        girlsPresent = bInt(r['TGP']),
        boysAbsent = bInt(r['TBA']),
        girlsAbsent = bInt(r['TGA']);
  final String name;
  final int boys, girls, boysPresent, girlsPresent, boysAbsent, girlsAbsent;
  int get total => boys + girls;
  int get present => boysPresent + girlsPresent;
  int get absent => boysAbsent + girlsAbsent;
  bool get taken => present + absent > 0;
}

/// Boys Girls Daywise Attendance Report: one date, every class: how many boys and girls were present / absent.
/// `POST /student/show_daywise_student_attendance` with `date` and `taken` (`yes` / `no` / empty).
class BDaywiseAttendanceScreen extends StatefulWidget {
  const BDaywiseAttendanceScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<BDaywiseAttendanceScreen> createState() => _BDaywiseAttendanceScreenState();
}

class _BDaywiseAttendanceScreenState extends State<BDaywiseAttendanceScreen> {
  DateTime _date = DateTime.now();
  String _taken = '';
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String _q = '';
  List<_ClassRow> _rows = [];

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
      final res = await widget.args.api.post('/student/show_daywise_student_attendance', body: {'date': ymd(_date), 'taken': _taken});
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res, 'No data found.'));
      _rows = [for (final r in rows(res['attendance_data'])) _ClassRow(r)];
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
    final shown = _rows.where((r) => _q.trim().isEmpty || r.name.toLowerCase().contains(_q.trim().toLowerCase())).toList();
    final total = _rows.fold<int>(0, (a, r) => a + r.total);
    final present = _rows.fold<int>(0, (a, r) => a + r.present);
    final absent = _rows.fold<int>(0, (a, r) => a + r.absent);
    final takenCount = _rows.where((r) => r.taken).length;
    return bPage(context, widget.args.item.label.isEmpty ? 'Daywise Attendance' : widget.args.item.label, [
      BHero(
        icon: Icons.wc_rounded,
        title: 'Boys & girls attendance',
        subtitle: _loaded ? '${_rows.length} classes · attendance taken in $takenCount' : 'Pick a date to see every class.',
        stats: _loaded ? [('Students', '$total'), ('Present', '$present'), ('Absent', '$absent')] : const [],
      ),
      gap(14),
      BFilterCard(
        busy: _loading,
        onShow: _load,
        children: [
          DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          DropdownField(
            label: 'Attendance',
            options: const [Opt('', 'All classes'), Opt('yes', 'Taken'), Opt('no', 'Not taken')],
            value: _taken,
            onChanged: (v) => setState(() => _taken = v ?? ''),
          ),
        ],
      ),
      if (_error != null) ...[gap(12), Notice(_error!, kind: NoticeKind.error)],
      if (_loaded && _rows.isEmpty) ...[gap(8), const KitMessage(icon: Icons.groups_outlined, text: 'No classes found for these filters.')],
      if (_rows.isNotEmpty) ...[
        gap(12),
        BSearchBox(hint: 'Find a class', onChanged: (v) => setState(() => _q = v)),
        gap(12),
        for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _classCard(r)),
      ],
    ]);
  }

  Widget _classCard(_ClassRow r) {
    final pct = r.total == 0 ? 0.0 : r.present / r.total;
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          r.taken ? const Tag.ok('Taken') : const Tag.warn('Not taken'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _gender('Boys', Icons.boy_rounded, r.boys, r.boysPresent, r.boysAbsent, Brand.info, Brand.info0)),
          const SizedBox(width: 10),
          Expanded(child: _gender('Girls', Icons.girl_rounded, r.girls, r.girlsPresent, r.girlsAbsent, const Color(0xFFBE185D), const Color(0xFFFCE7F3))),
        ]),
        if (r.taken) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: BBar(pct)),
            const SizedBox(width: 10),
            Text('${(pct * 100).round()}% present', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Brand.ink2)),
          ]),
        ],
      ]),
    );
  }

  Widget _gender(String label, IconData icon, int total, int present, int absent, Color fg, Color bg) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 4),
            Text('$label · $total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: fg)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _num('$present', 'Present', Brand.ok),
            const SizedBox(width: 14),
            _num('$absent', 'Absent', Brand.err),
          ]),
        ]),
      );

  Widget _num(String v, String label, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: c, height: 1.1)),
        Text(label, style: const TextStyle(fontSize: 11, color: Brand.ink2)),
      ]);
}
