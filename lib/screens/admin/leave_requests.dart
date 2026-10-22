import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import '../teacher/api_migration.dart';
import 'admin_common.dart';

/// t_leave_authorisation: staff leave requests in a date range.
class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();
  final ctl = AsyncListController();

  /// New: GET api/leave/requests (token + user_id come from LegacyApi.identity). The decision
  /// below stays on the legacy route, so row `id` must be the hrms_emp_leaves id - it is.
  Future<List<Map<String, dynamic>>> _load() => readNewThenLegacy(
        't_leave_authorisation',
        () => fetchLeaveRequests(widget.args.api, {'status': 'pending', 'from_date': ymd(from), 'to_date': ymd(to)}),
        () async {
          final res = await widget.args.api.post('/show-leave-authorisation', body: {
            'from_date': ymd(from),
            'to_date': ymd(to),
            'leave_status': 'pending',
          });
          if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
          return rows(res['get_employee_leave_lists']);
        },
      );

  Future<void> _open(Map<String, dynamic> r) async {
    final changed = await push<bool>(context, LeaveRequestDetailScreen(args: widget.args, row: r));
    if (changed == true) await ctl.reload();
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Leave requests' : widget.args.item.label,
        child: AsyncList(
          key: ValueKey('${ymd(from)}_${ymd(to)}'),
          controller: ctl,
          load: _load,
          emptyText: 'No pending leave requests in this date range.',
          emptyIcon: Icons.event_available_outlined,
          header: Row(children: [
            Expanded(
              child: DateField(
                label: 'From date',
                value: from,
                onChanged: (d) => setState(() {
                  from = d;
                  if (to.isBefore(d)) to = d;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DateField(label: 'To date', value: to, first: from, onChanged: (d) => setState(() => to = d)),
            ),
          ]),
          itemBuilder: (c, r, i) => KitCard(
            onTap: () => _open(r),
            child: Row(children: [
              Container(width: 4, height: 54, decoration: BoxDecoration(color: Brand.primary, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s(r['employee_name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (s(r['leave_type']).isNotEmpty) Text(s(r['leave_type']), style: const TextStyle(color: Brand.primary, fontSize: 12.5)),
                  if (s(r['comment']).isNotEmpty) Text(s(r['comment']), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${fmtDate(r['from_date'], out: 'dd MMM')} - ${fmtDate(r['to_date'], out: 'dd MMM yyyy')}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Brand.muted),
            ]),
          ),
        ),
      );
}

class LeaveRequestDetailScreen extends StatefulWidget {
  const LeaveRequestDetailScreen({super.key, required this.args, required this.row});
  final ScreenArgs args;
  final Map<String, dynamic> row;

  @override
  State<LeaveRequestDetailScreen> createState() => _LeaveRequestDetailScreenState();
}

class _LeaveRequestDetailScreenState extends State<LeaveRequestDetailScreen> with SubmitGuard {
  late final hr = TextEditingController(text: s(widget.row['hr_remarks']));
  late final hod = TextEditingController(text: s(widget.row['hod_comment']));
  String? action;

  static const actions = ['Approved_lwp', 'Cancelled', 'Rejected', 'Pending', 'Approved'];

  @override
  void dispose() {
    hr.dispose();
    hod.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    await guarded(() async {
      final res = await widget.args.api.post('/leave-authorisation-store', body: {
        'id': s(widget.row['id']),
        'hod_comment': hod.text.trim(),
        'hr_remarks': hr.text.trim(),
        'single_leave_status': action!.toLowerCase(),
      });
      if (!mounted) return;
      if (report(res, ok: 'Leave updated.')) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final half = s(r['day_type']) == '0.5';
    final slot = s(r['slot']);
    return KitPage(
      title: 'Leave request',
      bottom: formBar(label: 'Apply', busy: busy, onPressed: action == null ? null : _apply),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s(r['employee_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            gap(6),
            KV('Leave type', s(r['leave_type'])),
            KV('Day type', half ? 'Half day' : 'Full day'),
            KV('From', fmtDate(r['from_date'], out: 'yyyy-MM-dd')),
            KV('To', fmtDate(r['to_date'], out: 'yyyy-MM-dd')),
            if (slot.isNotEmpty) KV('Slot', slot == 'first_half' ? 'First half' : (slot == 'second_half' ? 'Second half' : slot)),
            KV('Reason', s(r['comment'])),
          ]),
        ),
        gap(16),
        TextInput(label: 'HR remark', controller: hr, lines: 2),
        gap(),
        TextInput(label: 'HOD remark', controller: hod, lines: 2),
        gap(),
        DropdownField(label: 'Take action', options: [for (final a in actions) Opt(a, a.replaceAll('_', ' '))], value: action, onChanged: (v) => setState(() => action = v)),
      ]),
    );
  }
}
