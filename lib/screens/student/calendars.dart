import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'student_common.dart';

const _green = Color(0xFF16A34A);
const _red = Color(0xFFE11D48);
const _blue = Color(0xFF2563EB);
const _purple = Color(0xFF9333EA);

String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Month header + calendar with circular, colour-coded day cells.
class ColoredCalendar extends StatelessWidget {
  const ColoredCalendar({super.key, required this.focused, required this.onMonth, required this.colorFor, this.selected, this.onDay});
  final DateTime focused;
  final ValueChanged<DateTime> onMonth;
  final Color? Function(DateTime) colorFor;
  final DateTime? selected;
  final ValueChanged<DateTime>? onDay;

  Widget _cell(DateTime d, {bool ring = false}) {
    final c = colorFor(d);
    return Center(
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          border: ring ? Border.all(color: Brand.primary, width: 2) : null,
        ),
        child: Text('${d.day}', style: TextStyle(color: c == null ? Brand.text : Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => KitCard(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(children: [
          Row(children: [
            IconButton(tooltip: 'Previous month', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => onMonth(DateTime(focused.year, focused.month - 1))),
            Expanded(child: Text(DateFormat('MMMM yyyy').format(focused), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            IconButton(tooltip: 'Next month', icon: const Icon(Icons.chevron_right_rounded), onPressed: () => onMonth(DateTime(focused.year, focused.month + 1))),
          ]),
          TableCalendar<void>(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: focused,
            headerVisible: false,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (d) => selected != null && isSameDay(d, selected),
            onDaySelected: (sel, foc) {
              onMonth(foc);
              onDay?.call(sel);
            },
            onPageChanged: onMonth,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (c, d, _) => _cell(d),
              todayBuilder: (c, d, _) => _cell(d, ring: true),
              selectedBuilder: (c, d, _) => _cell(d, ring: true),
              outsideBuilder: (c, d, _) => const SizedBox.shrink(),
            ),
          ),
        ]),
      );
}

/// Attendance calendar: present / absent / holiday for the month.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  final Map<String, String> _att = {};
  final Set<String> _holidays = {};
  bool _loading = true;
  String? _error;

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
    try {
      final a = widget.args;
      final mobile = Sx.raw(a, 'mobile').isNotEmpty ? Sx.raw(a, 'mobile') : Sx.raw(a, 'mobile_no');
      final res = await Sx.call(a, Sx.url(a, '/studentAttendanceAPI'), body: {'mobile_no': mobile});
      if (!mounted) return;
      if (!LegacyApi.ok(res)) {
        _error = LegacyApi.messageOf(res, 'Attendance data is not available right now.');
      } else {
        final data = m(res['data']);
        _att.clear();
        _holidays.clear();
        for (final r in rows(data['attendance_data'])) {
          _att[s(r['attendance_date']).split(' ').first] = s(r['attendance_code']).toUpperCase();
        }
        for (final r in rows(m(data['calendar_data'])['holiday'])) {
          _holidays.add(s(r['school_date']).split(' ').first);
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Color? _color(DateTime d) {
    final k = _key(d);
    if (_holidays.contains(k)) return _blue;
    final code = _att[k];
    if (code == null) return null;
    return code == 'P' ? _green : _red;
  }

  bool _inMonth(String k) => k.startsWith(DateFormat('yyyy-MM').format(_month));

  @override
  Widget build(BuildContext context) {
    final present = _att.entries.where((e) => _inMonth(e.key) && e.value == 'P').length;
    final absent = _att.entries.where((e) => _inMonth(e.key) && e.value != 'P').length;
    final holiday = _holidays.where(_inMonth).length;
    return KitPage(
      title: titleOf(widget.args, 'Attendance'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? KitMessage(icon: Icons.event_busy_outlined, text: _error!, action: 'Retry', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Row(children: [StatTile('Present', '$present', _green), StatTile('Absent', '$absent', _red), StatTile('Holiday', '$holiday', _blue)]),
                    const SizedBox(height: 14),
                    ColoredCalendar(focused: _month, onMonth: (d) => setState(() => _month = DateTime(d.year, d.month)), colorFor: _color),
                  ]),
                ),
    );
  }
}

/// Academic calendar: holidays, events and vacations, with the tapped day's entries below.
class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;
  final Map<String, List<Map<String, dynamic>>> _byDate = {};
  bool _loading = true;
  String? _error;

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
    try {
      final a = widget.args;
      final mobile = Sx.raw(a, 'mobile').isNotEmpty ? Sx.raw(a, 'mobile') : Sx.raw(a, 'mobile_no');
      final res = await Sx.call(a, '/studentCalenderAPI', body: {'mobile_no': mobile});
      if (!mounted) return;
      if (!LegacyApi.ok(res)) {
        _error = LegacyApi.messageOf(res);
      } else {
        _byDate.clear();
        for (final r in rows(res['data'])) {
          _byDate.putIfAbsent(s(r['school_date']).split(' ').first, () => []).add(r);
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  static Color? _typeColor(String t) {
    switch (t.toLowerCase()) {
      case 'vacation':
        return _purple;
      case 'holiday':
        return _blue;
      case 'event':
        return _green;
      case 'notice':
        return _red;
    }
    return null;
  }

  Color? _color(DateTime d) {
    final list = _byDate[_key(d)];
    return list == null || list.isEmpty ? null : _typeColor(s(list.first['event_type']));
  }

  int _count(String type) {
    final prefix = DateFormat('yyyy-MM').format(_month);
    var n = 0;
    _byDate.forEach((k, v) {
      if (k.startsWith(prefix)) n += v.where((e) => s(e['event_type']).toLowerCase() == type).length;
    });
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _day == null ? const <Map<String, dynamic>>[] : (_byDate[_key(_day!)] ?? const []);
    return KitPage(
      title: titleOf(widget.args, 'Academic calendar'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? KitMessage(icon: Icons.event_busy_outlined, text: _error!, action: 'Retry', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Row(children: [StatTile('Holiday', '${_count('holiday')}', _blue), StatTile('Event', '${_count('event')}', _green), StatTile('Vacation', '${_count('vacation')}', _purple)]),
                    const SizedBox(height: 14),
                    ColoredCalendar(
                      focused: _month,
                      selected: _day,
                      onMonth: (d) => setState(() => _month = DateTime(d.year, d.month)),
                      onDay: (d) => setState(() => _day = d),
                      colorFor: _color,
                    ),
                    const SizedBox(height: 14),
                    if (_day != null && entries.isEmpty)
                      Padding(padding: const EdgeInsets.all(8), child: Text('Nothing is scheduled on ${DateFormat('dd MMM yyyy').format(_day!)}.', textAlign: TextAlign.center, style: const TextStyle(color: Brand.muted))),
                    for (final e in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KitCard(
                          child: Row(children: [
                            Container(width: 6, height: 38, decoration: BoxDecoration(color: _typeColor(s(e['event_type'])) ?? Brand.muted, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s(e['title']), style: const TextStyle(fontWeight: FontWeight.w800)),
                                if (s(e['description']).isNotEmpty) Text(s(e['description']), style: const TextStyle(color: Brand.muted)),
                              ]),
                            ),
                            Pill(s(e['event_type']), color: _typeColor(s(e['event_type'])) ?? Brand.muted),
                          ]),
                        ),
                      ),
                  ]),
                ),
    );
  }
}
