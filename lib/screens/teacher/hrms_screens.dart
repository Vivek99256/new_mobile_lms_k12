import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'api_migration.dart';
import 'tk.dart';
import '../../ui/app_loader.dart';

const _green = Color(0xFF047857);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);

/// Rows of a generic `lms_data` table query (the server answers `{message}` for an empty/invalid table).
Future<List<Map<String, dynamic>>> lmsRows(ScreenArgs a, String table, {Map<String, dynamic> filters = const {}, String orderBy = 'id'}) async {
  final res = await a.api.get('/lms_data', query: {
    'table': table,
    'filters[user_id]': a.session.userId,
    'filters[sub_institute_id]': a.session.subInstituteId,
    for (final e in filters.entries) 'filters[${e.key}]': e.value,
    'order_by[column]': orderBy,
    'order_by[direction]': 'desc',
  });
  final list = dataRows(res);
  if (list.isNotEmpty && list.first['message'] != null) return const [];
  return list;
}

String _clock(dynamic v, [String out = 'hh:mm a']) {
  final raw = s(v);
  if (raw.isEmpty) return '-';
  final d = DateTime.tryParse(raw.contains('T') || raw.length > 8 ? raw.replaceFirst(' ', 'T') : '2000-01-01T$raw');
  return d == null ? raw : DateFormat(out).format(d);
}

// ---------------------------------------------------------------------------------------
// Punch in / out
// ---------------------------------------------------------------------------------------

class PunchScreen extends StatefulWidget {
  const PunchScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<PunchScreen> createState() => _PunchScreenState();
}

class _PunchScreenState extends State<PunchScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic> status = {};
  bool loading = true, punching = false;
  Map<String, dynamic> month = {};
  String? error;
  DateTime now = DateTime.now();
  Timer? timer;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
    _load();
  }

  @override
  void dispose() {
    timer?.cancel();
    pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = status.isEmpty;
      error = null;
    });
    try {
      final res = await widget.args.api.get('/hrms-inout-time');
      if (mounted) setState(() => status = res);
      _loadMonth();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// The last 30 days, for the summary card. Optional: the screen works without it.
  Future<void> _loadMonth() async {
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 29));
      String d(DateTime x) => DateFormat('yyyy-MM-dd').format(x);
      final res = await widget.args.api.get('/api/attendance/my-attendance', query: {'from_date': d(start), 'to_date': d(end)});
      if (LegacyApi.ok(res) && mounted) setState(() => month = res);
    } on ApiException {
      // keep the screen without the summary
    }
  }

  Future<Position?> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) toast(context, 'Turn on location services to punch.', error: true);
      return null;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied) {
      if (mounted) toast(context, 'Location permission is needed to punch in or out.', error: true);
      return null;
    }
    if (p == LocationPermission.deniedForever) {
      if (mounted) toast(context, 'Location permission is blocked. Enable it in app settings.', error: true);
      await Geolocator.openAppSettings();
      return null;
    }
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  Future<void> _punch() async {
    if (punching) return;
    setState(() => punching = true);
    try {
      final pos = await _position();
      if (pos == null || !mounted) return;
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        if (mounted) toast(context, 'Camera permission is needed to take the punch photo.', error: true);
        return;
      }
      final photo = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, imageQuality: 80, maxWidth: 1024);
      if (photo == null || !mounted) {
        if (mounted) toast(context, 'No photo was taken.', error: true);
        return;
      }
      final out = s(status['button']) == 'out';
      final stamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final addr = '${pos.latitude}, ${pos.longitude}';
      final res = await widget.args.api.post(
        out ? '/hrms-out-time/store' : '/hrms-in-time/store',
        body: out ? {'punchout_time': stamp, 'address_out': addr} : {'punchin_time': stamp, 'address_in': addr},
        files: [UploadFile(out ? 'photo_out' : 'photo_in', photo.path)],
      );
      if (!mounted) return;
      if (LegacyApi.ok(res)) {
        toast(context, LegacyApi.messageOf(res, out ? 'Checked out.' : 'Checked in.'));
        await _load();
      } else {
        toast(context, LegacyApi.messageOf(res), error: true);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'Could not complete the punch. Try again.', error: true);
    } finally {
      if (mounted) setState(() => punching = false);
    }
  }

  DateTime? _stamp(dynamic v) => DateTime.tryParse(s(v).replaceFirst(' ', 'T'));

  String _dur(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final att = m(status['hrms_attendance']);
    final done = status['button_disable'] == true || '${status['button_disable']}' == '1';
    final working = !done && s(status['button']) == 'out';
    final total = s(att['timestamp_diff']);
    final inAt = _stamp(att['punchin_time']);
    final outAt = _stamp(att['punchout_time']);

    Duration worked = Duration.zero;
    if (working && inAt != null) worked = now.difference(inAt);
    if (done && inAt != null && outAt != null) worked = outAt.difference(inAt);
    const target = Duration(hours: 8);
    final progress = done ? 1.0 : (worked.inSeconds / target.inSeconds).clamp(0.0, 1.0).toDouble();

    final accent = done ? _green : (working ? _red : Brand.primary);
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final first = widget.args.session.name.trim().split(RegExp(r'\s+')).first;
    final pill = done ? 'Day complete' : (working ? 'Working${inAt == null ? '' : ' since ${DateFormat('hh:mm a').format(inAt)}'}' : 'Not checked in');
    final pillColor = done ? const Color(0xFF34D399) : (working ? const Color(0xFFFBBF24) : const Color(0xFFB6BEE0));

    return KitPage(
      title: widget.args.title.isEmpty ? 'Punch in / out' : widget.args.title,
      child: loading
          ? const AppLoader()
          : error != null && status.isEmpty
              ? KitMessage(icon: Icons.cloud_off_outlined, text: error!, action: 'Try again', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
                    // Hero: greeting, live clock and today's state.
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Brand.navy, Brand.navy2]),
                        boxShadow: const [BoxShadow(color: Color(0x330B1437), blurRadius: 24, offset: Offset(0, 12))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('$greeting, $first', style: const TextStyle(color: Brand.champagne, fontSize: 14, fontWeight: FontWeight.w600))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 7, height: 7, decoration: BoxDecoration(color: pillColor, shape: BoxShape.circle)),
                              const SizedBox(width: 7),
                              Text(pill, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text(DateFormat('hh:mm:ss').format(now),
                              style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1, fontFeatures: [FontFeature.tabularFigures()])),
                          const SizedBox(width: 6),
                          Text(DateFormat('a').format(now), style: const TextStyle(color: Brand.champagne, fontSize: 18, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 2),
                        Text(DateFormat('EEEE, dd MMMM yyyy').format(now), style: const TextStyle(color: Brand.champagne, fontSize: 13)),
                      ]),
                    ),
                    gap(22),
                    // The action: a progress ring (hours worked against an 8 hour day) around the button.
                    Center(
                      child: SizedBox(
                        width: 236,
                        height: 236,
                        child: AnimatedBuilder(
                          animation: pulse,
                          builder: (_, child) => Stack(alignment: Alignment.center, children: [
                            if (!done)
                              Container(
                                width: 190 + 46 * pulse.value,
                                height: 190 + 46 * pulse.value,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.16 * (1 - pulse.value))),
                              ),
                            SizedBox(width: 214, height: 214, child: CustomPaint(painter: _RingPainter(progress, accent, Brand.line))),
                            child!,
                          ]),
                          child: Material(
                            color: accent,
                            shape: const CircleBorder(),
                            elevation: done ? 0 : 6,
                            shadowColor: accent.withValues(alpha: 0.5),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: done || punching ? null : _punch,
                              child: SizedBox(
                                width: 172,
                                height: 172,
                                child: Center(
                                  child: punching
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Column(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(done ? Icons.check_circle_outline_rounded : (working ? Icons.logout_rounded : Icons.fingerprint_rounded), color: Colors.white, size: 38),
                                          const SizedBox(height: 8),
                                          Text(done ? 'Day complete' : (working ? 'Check out' : 'Check in'),
                                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 2),
                                          Text(done ? (total.isEmpty ? _dur(worked) : total) : (working ? _dur(worked) : 'Tap to start'),
                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                                        ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    gap(4),
                    if (!done)
                      Center(
                        child: Wrap(spacing: 8, children: const [
                          _Need(icon: Icons.location_on_outlined, label: 'Location'),
                          _Need(icon: Icons.photo_camera_outlined, label: 'Selfie'),
                        ]),
                      ),
                    gap(20),
                    // Today as a timeline.
                    KitCard(
                      child: Column(children: [
                        _TimeRow(icon: Icons.login_rounded, color: _green, label: 'Check in', value: _clock(att['punchin_time']), last: false),
                        _TimeRow(icon: Icons.logout_rounded, color: _red, label: 'Check out', value: _clock(att['punchout_time']), last: false),
                        _TimeRow(
                          icon: Icons.timer_outlined,
                          color: Brand.primary,
                          label: working ? 'Working now' : 'Total hours',
                          value: working ? _dur(worked) : (total.isEmpty ? '-' : total),
                          last: true,
                        ),
                      ]),
                    ),
                    gap(14),
                    if (month.isNotEmpty) _MonthCard(month: month),
                  ]),
                ),
    );
  }
}

/// A small "what you need" chip under the button.
class _Need extends StatelessWidget {
  const _Need({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Brand.tint, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Brand.primaryDark),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: Brand.primaryDark, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// One row of today's timeline, with a connector to the next row.
class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.icon, required this.color, required this.label, required this.value, required this.last});
  final IconData icon;
  final Color color;
  final String label, value;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 40,
            child: Column(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
              ),
              if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: Brand.line)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 8, bottom: last ? 4 : 16),
              child: Row(children: [
                Expanded(child: Text(label, style: TextStyle(color: Brand.ink3, fontSize: 14, fontWeight: FontWeight.w600))),
                Text(value, style: TextStyle(color: Brand.ink, fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
          ),
        ]),
      );
}

/// The last 30 days at a glance: counts, a percentage and the last 7 days as coloured dots.
class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month});
  final Map<String, dynamic> month;

  static Color _dot(String st) => switch (st) {
        'present' => const Color(0xFF10B981),
        'late' => const Color(0xFFF59E0B),
        'absent' => const Color(0xFFEF4444),
        'leave' => const Color(0xFF3B82F6),
        _ => Brand.border,
      };

  @override
  Widget build(BuildContext context) {
    final cal = rows(month['calendar']);
    final last7 = cal.length > 7 ? cal.sublist(cal.length - 7) : cal;
    final pct = num.tryParse('${month['percentege'] ?? 0}') ?? 0;
    final pctFg = pct >= 90 ? Brand.ok : (pct >= 75 ? Brand.warn : Brand.err);
    final pctBg = pct >= 90 ? Brand.ok0 : (pct >= 75 ? Brand.warn0 : Brand.err0);
    Widget stat(String label, dynamic v, Color c) => Expanded(
          child: Column(children: [
            Text('${v ?? 0}', style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Brand.ink3, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        );
    return KitCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Last 30 days', style: TextStyle(color: Brand.ink, fontSize: 15, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: pctBg, borderRadius: BorderRadius.circular(99)),
            child: Text('${month['percentege'] ?? 0}% attendance', style: TextStyle(color: pctFg, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          stat('Present', month['presentDays'], const Color(0xFF10B981)),
          stat('Late', month['lateDays'], const Color(0xFFF59E0B)),
          stat('Absent', month['absentDays'], const Color(0xFFEF4444)),
          stat('Leave', month['leaveDays'], const Color(0xFF3B82F6)),
        ]),
        const SizedBox(height: 16),
        Divider(height: 1, color: Brand.line),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final r in last7)
            Column(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: _dot('${r['status'] ?? ''}'), shape: BoxShape.circle)),
              const SizedBox(height: 6),
              Text(fmtDate(r['date'], out: 'EEE'), style: TextStyle(color: Brand.ink3, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
        ]),
      ]),
    );
  }
}

/// The ring around the punch button: a track and an arc for the share of the day worked.
class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);
  final double progress;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    canvas.drawArc(rect, 0, 6.2831853, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = track);
    if (progress > 0) {
      canvas.drawArc(rect, -1.5707963, 6.2831853 * progress, false,
          Paint()..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------------------
// My attendance
// ---------------------------------------------------------------------------------------

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  DateTime? month;
  final ctrl = AsyncListController();

  Future<void> _pick() async {
    final d = await showDatePicker(context: context, initialDate: month ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2101), helpText: 'Select any day in the month');
    if (d != null) {
      setState(() => month = DateTime(d.year, d.month));
      ctrl.reload();
    }
  }

  @override
  Widget build(BuildContext context) => ListPage(
        title: widget.args.title.isEmpty ? 'My attendance' : widget.args.title,
        controller: ctrl,
        emptyText: 'No attendance history found.',
        emptyIcon: Icons.fact_check_outlined,
        header: Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pick,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Month', suffixIcon: Icon(Icons.calendar_month_outlined)),
                child: Text(DateFormat('MMMM yyyy').format(month ?? DateTime.now())),
              ),
            ),
          ),
          if (month != null)
            IconButton(
              tooltip: 'Show all months',
              onPressed: () {
                setState(() => month = null);
                ctrl.reload();
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ]),
        // The generic table query (`hrms_attendances`) is closed to everything outside a lookup allow-list, so
        // read the month from the purpose-built self-service endpoint instead.
        load: () async {
          final now = DateTime.now();
          final m = month ?? DateTime(now.year, now.month);
          String d(DateTime x) => DateFormat('yyyy-MM-dd').format(x);
          final res = await widget.args.api.get('/api/attendance/my-attendance', query: {
            'from_date': d(DateTime(m.year, m.month, 1)),
            'to_date': d(DateTime(m.year, m.month + 1, 0)),
          });
          if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
          // Days with a punch, leave or absence; unscheduled and future days carry no status.
          return rows(res['calendar']).where((r) => '${r['status'] ?? ''}'.isNotEmpty).toList();
        },
        itemBuilder: (c, r, i) => KitCard(
          child: Row(children: [
            Expanded(child: Text('${fmtDate(r['date'], out: 'dd MMM yyyy')}  ·  ${'${r['status']}'.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w800))),
            const Icon(Icons.login_rounded, size: 18, color: _green),
            const SizedBox(width: 4),
            Text(_clock(r['punchin_time'])),
            const SizedBox(width: 14),
            const Icon(Icons.logout_rounded, size: 18, color: _red),
            const SizedBox(width: 4),
            Text(_clock(r['punchout_time'])),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------------------
// Leaves
// ---------------------------------------------------------------------------------------

class MyLeaveScreen extends StatefulWidget {
  const MyLeaveScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<MyLeaveScreen> createState() => _MyLeaveScreenState();
}

class _MyLeaveScreenState extends State<MyLeaveScreen> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = data.isEmpty;
      error = null;
    });
    try {
      // api/hrms/leaves returns the real allocation; /hrms/myleave only ever returned sample numbers.
      final api = widget.args.api;
      final d = await readNewThenLegacy<Map<String, dynamic>>(
        't_my_leave',
        () async => adaptLeaveBalance(m((await getNew(api, '/api/hrms/leaves'))['data'])),
        () async => m((await getOk(api, '/hrms/myleave/${widget.args.session.userId}'))['data']),
      );
      if (mounted) setState(() => data = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  num _n(dynamic v) => num.tryParse(s(v)) ?? 0;

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final sum = m(data['leave_summary']);
    final types = rows(data['leave_types']);
    final total = _n(sum['total_leaves']);
    final used = _n(sum['used_leaves']);
    return KitPage(
      title: a.title.isEmpty ? 'My leaves' : a.title,
      child: loading
          ? const AppLoader()
          : error != null && data.isEmpty
              ? KitMessage(icon: Icons.cloud_off_outlined, text: error!, action: 'Try again', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Row(children: [
                      Expanded(child: titleRow('Leave balance')),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _green, minimumSize: const Size(44, 44)),
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ApplyLeaveScreen(args: a)));
                          if (mounted) _load();
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Apply'),
                      ),
                    ]),
                    gap(),
                    KitCard(
                      child: Row(children: [
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(alignment: Alignment.center, children: [
                            SizedBox.expand(child: CircularProgressIndicator(value: total <= 0 ? 0 : (used / total).clamp(0, 1).toDouble(), strokeWidth: 9, backgroundColor: Brand.line, color: Brand.primary)),
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(s(sum['remaining_leaves']).isEmpty ? '0' : s(sum['remaining_leaves']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                              Text('remaining', style: TextStyle(color: Brand.muted, fontSize: 12)),
                            ]),
                          ]),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${s(sum['used_leaves']).isEmpty ? '0' : s(sum['used_leaves'])} used', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('${s(sum['total_leaves']).isEmpty ? '0' : s(sum['total_leaves'])} total', style: TextStyle(color: Brand.muted, fontSize: 16)),
                          ]),
                        ),
                      ]),
                    ),
                    gap(20),
                    Row(children: [
                      Expanded(child: titleRow('Leave types')),
                      OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveHistoryScreen(args: a))), child: const Text('Leave history')),
                    ]),
                    gap(),
                    if (types.isEmpty) const KitMessage(icon: Icons.beach_access_outlined, text: 'No leave types are set up for you.'),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      for (var i = 0; i < types.length; i++)
                        SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 42) / 2,
                          child: KitCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              IconBubble(icon: Icons.beach_access_outlined, accent: Brand.accent(i), size: 38),
                              gap(8),
                              Text('${s(types[i]['used'])}/${s(types[i]['total'])}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              Text(s(types[i]['leave_type']), style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                            ]),
                          ),
                        ),
                    ]),
                  ]),
                ),
    );
  }
}

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> with BusyMixin {
  List<Opt> types = [];
  bool loading = true;
  String? type, dayType, slot;
  DateTime from = today(), to = today();
  final comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    lmsRows(widget.args, 'hrms_leave_types').then((r) {
      if (mounted) setState(() => types = [for (final x in r) Opt(s(x['id']), s(x['leave_type']))]);
    }).catchError((Object e) {
      if (mounted) toast(context, '$e', error: true);
    }).whenComplete(() {
      if (mounted) setState(() => loading = false);
    });
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final half = dayType == 'half';
    return KitPage(
      title: 'Apply leave',
      bottom: PrimaryButton(
        label: 'Apply leave',
        busy: busy,
        onPressed: () {
          if (type == null) return toast(context, 'Please select a leave type.', error: true);
          if (dayType == null) return toast(context, 'Please select the day type.', error: true);
          if (half && slot == null) return toast(context, 'Please select the slot.', error: true);
          if (!half && to.isBefore(from)) return toast(context, 'To date cannot be before from date.', error: true);
          final api = widget.args.api;
          submit(() => writeNewThenLegacy(
                't_apply_leave',
                // api/leave/requests needs the body `token` and `user_id`; LegacyApi.identity sends both.
                () => api.post('/api/leave/requests', body: {
                  'leave_type_id': type,
                  'day_type': dayType,
                  'from_date': ymd(from),
                  if (!half) 'to_date': ymd(to),
                  if (half) 'slot': slot,
                  'comment': comment.text.trim(),
                }),
                () => postOk(api, '/leave-apply', body: {
                  'type_leave': 'Self',
                  'leave_type': type,
                  'day_type': dayType,
                  'from_date': ymd(from),
                  if (!half) 'to_date': ymd(to),
                  if (half) 'slot': slot,
                  'comment': comment.text.trim(),
                }),
              ), fallback: 'Leave applied.');
        },
      ),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          DropdownField(label: 'Leave type', options: types, value: type, loading: loading, onChanged: (v) => setState(() => type = v)),
          DropdownField(label: 'Day type', options: const [Opt('full', 'Full'), Opt('half', 'Half')], value: dayType, onChanged: (v) => setState(() => dayType = v)),
          DateField(
            label: 'From date',
            value: from,
            first: DateTime.now().subtract(const Duration(days: 1)),
            onChanged: (d) => setState(() {
              from = d;
              if (to.isBefore(d)) to = d;
            }),
          ),
          if (dayType == 'full') DateField(label: 'To date', value: to, first: from, onChanged: (d) => setState(() => to = d)),
          if (half) DropdownField(label: 'Slot', options: const [Opt('first_half', 'First half'), Opt('second_half', 'Second half')], value: slot, onChanged: (v) => setState(() => slot = v)),
          TextInput(label: 'Comment', controller: comment, lines: 4, hint: 'Write a comment...'),
        ]),
      ]),
    );
  }
}

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  List<Opt> types = [];
  String? type;
  final ctrl = AsyncListController();

  @override
  void initState() {
    super.initState();
    lmsRows(widget.args, 'hrms_leave_types').then((r) {
      if (mounted) setState(() => types = [for (final x in r) Opt(s(x['id']), s(x['leave_type']))]);
    }).catchError((Object _) {});
  }

  String _label(Map<String, dynamic> r) {
    final fmt = 'dd MMM yyyy';
    final range = '${fmtDate(r['from_date'], out: fmt)} - ${fmtDate(r['to_date'], out: fmt)}';
    String kind;
    if (s(r['day_type']) == '0.5') {
      final slot = s(r['slot']);
      kind = slot.isEmpty ? 'Half day' : (slot == 'first_half' ? 'First half' : 'Second half');
    } else {
      kind = 'Full day';
    }
    return '$range ($kind)';
  }

  @override
  Widget build(BuildContext context) => ListPage(
        title: 'Leave history',
        controller: ctrl,
        emptyText: 'No leave history found.',
        emptyIcon: Icons.history_rounded,
        header: DropdownField(
          label: 'Leave type',
          options: [const Opt('', 'All leave types'), ...types],
          value: type ?? '',
          onChanged: (v) {
            setState(() => type = (v == null || v.isEmpty) ? null : v);
            ctrl.reload();
          },
        ),
        load: () => readNewThenLegacy(
          't_leave_history',
          () => fetchLeaveRequests(widget.args.api, {'employee_id': widget.args.session.userId, if (type != null) 'leave_type_id': type}),
          () => lmsRows(widget.args, 'hrms_emp_leaves', filters: {if (type != null) 'leave_type_id': type}),
        ),
        itemBuilder: (c, r, i) {
          final st = s(r['status']).toLowerCase();
          final color = st == 'approved' ? _green : (st == 'rejected' ? _red : _amber);
          final name = types.where((t) => t.id == s(r['leave_type_id'])).firstOrNull?.label ?? 'Leave';
          return KitCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                Pill(st == 'approved' ? 'Approved' : (st == 'rejected' ? 'Rejected' : 'Pending'), color: color),
              ]),
              gap(4),
              Text(_label(r), style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              if (s(r['comment']).isNotEmpty) ...[gap(6), Text(s(r['comment']))],
              KV('HOD comment', s(r['hod_comment'])),
              KV('HR remarks', s(r['hr_remarks'])),
            ]),
          );
        },
      );
}
