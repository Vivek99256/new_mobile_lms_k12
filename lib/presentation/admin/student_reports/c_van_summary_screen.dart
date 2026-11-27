import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'c_report_ui.dart';
import '../../../ui/app_loader.dart';

/// Van Summary Report: how many students ride each van and shift. Tap one to see who they are.
/// `GET transportation/van_wise_students_detail_report` lists the vans; the students of one van come from
/// `GET api/transportation/van-summary/students/{van}/{shift}`.
class CVanSummaryScreen extends StatefulWidget {
  const CVanSummaryScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<CVanSummaryScreen> createState() => _CVanSummaryScreenState();
}

class _CVanSummaryScreenState extends State<CVanSummaryScreen> {
  List<Map<String, dynamic>> _vans = [];
  bool _loading = true;
  String? _error;
  String _q = '';

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
      final res = await widget.args.api.get('/transportation/van_wise_students_detail_report');
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      _vans = rows(res['student_datas']);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the report. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  int _count(Map<String, dynamic> r) => int.tryParse(s(r['student_count'])) ?? 0;

  @override
  Widget build(BuildContext context) {
    final title = widget.args.item.label.isEmpty ? 'Van Summary Report' : widget.args.item.label;
    if (_loading) return KitPage(title: title, child: const AppLoader());
    if (_error != null) return KitPage(title: title, child: KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _load));
    final q = _q.trim().toLowerCase();
    final shown = [for (final r in _vans) if (q.isEmpty || '${r['bus_name']} ${r['shift_title']}'.toLowerCase().contains(q)) r];
    final total = _vans.fold<int>(0, (a, r) => a + _count(r));
    final maxCount = _vans.fold<int>(1, (a, r) => _count(r) > a ? _count(r) : a);
    return KitPage(
      title: title,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: 1 + (shown.isEmpty ? 1 : shown.length),
          itemBuilder: (_, i) {
            if (i == 0) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CHero(
                  icon: Icons.directions_bus_rounded,
                  title: 'Van summary',
                  subtitle: 'Students on each van and shift',
                  stats: [('Students', '$total'), ('Van runs', '${_vans.length}'), ('Vans', '${_vans.map((r) => s(r['transport_vehicle_id'])).toSet().length}')],
                ),
                gap(12),
                CSearchBox(hint: 'Find a van or shift', onChanged: (v) => setState(() => _q = v)),
                gap(12),
              ]);
            }
            if (shown.isEmpty) return const Padding(padding: EdgeInsets.only(top: 30), child: KitMessage(icon: Icons.directions_bus_outlined, text: 'No vans have students mapped yet.'));
            return _card(shown[i - 1], maxCount);
          },
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r, int maxCount) {
    final n = _count(r);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CVanStudentsScreen(
              args: widget.args,
              vehicleId: s(r['transport_vehicle_id']),
              shiftId: s(r['transport_school_shift_id']),
              title: [s(r['bus_name']), s(r['shift_title'])].where((e) => e.isNotEmpty).join(' · '),
            ),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconTile(Icons.directions_bus_rounded, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s(r['bus_name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(s(r['shift_title']), style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Brand.primaryDark, height: 1)),
              Text('students', style: TextStyle(color: Brand.muted, fontSize: 11.5)),
            ]),
            Icon(Icons.chevron_right_rounded, color: Brand.ink3),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: maxCount == 0 ? 0 : n / maxCount, minHeight: 6, backgroundColor: Brand.field, color: Brand.primary),
          ),
        ]),
      ),
    );
  }
}

/// The students riding one van on one shift.
class CVanStudentsScreen extends StatefulWidget {
  const CVanStudentsScreen({super.key, required this.args, required this.vehicleId, required this.shiftId, required this.title});
  final ScreenArgs args;
  final String vehicleId;
  final String shiftId;
  final String title;

  @override
  State<CVanStudentsScreen> createState() => _CVanStudentsScreenState();
}

class _CVanStudentsScreenState extends State<CVanStudentsScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;
  String _q = '';

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
      final res = await widget.args.api.get('/api/transportation/van-summary/students/${widget.vehicleId}/${widget.shiftId}');
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      _students = rows(res['data']);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the students. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return KitPage(title: widget.title, child: const AppLoader());
    if (_error != null) return KitPage(title: widget.title, child: KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _load));
    final q = _q.trim().toLowerCase();
    final shown = [for (final r in _students) if (q.isEmpty || '${r['student_name']} ${r['enrollment_no']} ${r['standard_name']}'.toLowerCase().contains(q)) r];
    return KitPage(
      title: widget.title,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: 1 + (shown.isEmpty ? 1 : shown.length),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CHero(icon: Icons.people_alt_outlined, title: widget.title, subtitle: 'Students on this van', stats: [('Students', '${_students.length}')]),
              gap(12),
              CSearchBox(hint: 'Find a student or GR', onChanged: (v) => setState(() => _q = v)),
              gap(12),
            ]);
          }
          if (shown.isEmpty) return const Padding(padding: EdgeInsets.only(top: 30), child: KitMessage(icon: Icons.people_outline, text: 'No students found.'));
          final r = shown[i - 1];
          final mobile = s(r['mobile']);
          final cls = [s(r['standard_name']), s(r['division_name'])].where((e) => e.isNotEmpty).join(' - ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              radius: 18,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  PersonAvatar(url: '', name: s(r['student_name']), radius: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s(r['student_name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                      Text([if (s(r['enrollment_no']).isNotEmpty) 'GR ${s(r['enrollment_no'])}', cls].where((e) => e.isNotEmpty).join('  ·  '),
                          style: TextStyle(color: Brand.muted, fontSize: 12)),
                    ]),
                  ),
                ]),
                CInfoLine(Icons.home_outlined, s(r['address'])),
                if (mobile.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(onPressed: () => openUrl(context, 'tel:$mobile'), icon: const Icon(Icons.call_rounded, size: 17), label: Text(mobile)),
                  ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
