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
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
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

  @override
  Widget build(BuildContext context) {
    final att = m(status['hrms_attendance']);
    final disabled = status['button_disable'] == true || '${status['button_disable']}' == '1';
    final out = s(status['button']) == 'out';
    final total = s(att['timestamp_diff']);
    return KitPage(
      title: widget.args.title.isEmpty ? 'Punch in / out' : widget.args.title,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null && status.isEmpty
              ? KitMessage(icon: Icons.cloud_off_outlined, text: error!, action: 'Try again', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    gap(12),
                    Center(child: Text(DateFormat('hh:mm:ss a').format(now), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Brand.text))),
                    Center(child: Text(DateFormat('EEEE, dd MMM yyyy').format(now), style: const TextStyle(color: Brand.muted))),
                    gap(30),
                    Center(
                      child: AnimatedBuilder(
                        animation: pulse,
                        builder: (_, child) => Stack(alignment: Alignment.center, children: [
                          if (!disabled)
                            Container(
                              width: 170 + 50 * pulse.value,
                              height: 170 + 50 * pulse.value,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: (out ? _red : Brand.primary).withValues(alpha: 0.18 * (1 - pulse.value))),
                            ),
                          child!,
                        ]),
                        child: Material(
                          color: disabled ? Brand.muted : (out ? _red : Brand.primary),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: disabled || punching ? null : _punch,
                            child: SizedBox(
                              width: 170,
                              height: 170,
                              child: Center(
                                child: punching
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(disabled ? '$total\nTotal hours' : (out ? 'Check out' : 'Check in'),
                                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    gap(34),
                    Row(children: [
                      _Stat(icon: Icons.login_rounded, label: 'Check in', value: _clock(att['punchin_time'])),
                      const SizedBox(width: 10),
                      _Stat(icon: Icons.logout_rounded, label: 'Check out', value: _clock(att['punchout_time'])),
                      const SizedBox(width: 10),
                      _Stat(icon: Icons.timer_outlined, label: 'Total hours', value: total.isEmpty ? '-' : total),
                    ]),
                  ]),
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: KitCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Icon(icon, color: Brand.primary),
            const SizedBox(height: 6),
            FittedBox(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12)),
          ]),
        ),
      );
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
                child: Text(month == null ? 'All months' : DateFormat('MMMM yyyy').format(month!)),
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
        load: () => lmsRows(widget.args, 'hrms_attendances', orderBy: 'day', filters: {if (month != null) 'day': DateFormat('MMM-yyyy').format(month!)}),
        itemBuilder: (c, r, i) => KitCard(
          child: Row(children: [
            Expanded(child: Text(fmtDate(r['day'], out: 'dd MMM yyyy'), style: const TextStyle(fontWeight: FontWeight.w800))),
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
          ? const Center(child: CircularProgressIndicator())
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
                            SizedBox.expand(child: CircularProgressIndicator(value: total <= 0 ? 0 : (used / total).clamp(0, 1).toDouble(), strokeWidth: 9, backgroundColor: const Color(0xFFE2E8F0), color: Brand.primary)),
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(s(sum['remaining_leaves']).isEmpty ? '0' : s(sum['remaining_leaves']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                              const Text('remaining', style: TextStyle(color: Brand.muted, fontSize: 12)),
                            ]),
                          ]),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${s(sum['used_leaves']).isEmpty ? '0' : s(sum['used_leaves'])} used', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('${s(sum['total_leaves']).isEmpty ? '0' : s(sum['total_leaves'])} total', style: const TextStyle(color: Brand.muted, fontSize: 16)),
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
                              Text(s(types[i]['leave_type']), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
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
              Text(_label(r), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
              if (s(r['comment']).isNotEmpty) ...[gap(6), Text(s(r['comment']))],
              KV('HOD comment', s(r['hod_comment'])),
              KV('HR remarks', s(r['hr_remarks'])),
            ]),
          );
        },
      );
}
