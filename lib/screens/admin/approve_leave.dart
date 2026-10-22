import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';

/// t_approve_leave: student leave applications with inline approve / reject.
class ApproveLeaveScreen extends StatefulWidget {
  const ApproveLeaveScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<ApproveLeaveScreen> createState() => _ApproveLeaveScreenState();
}

class _ApproveLeaveScreenState extends State<ApproveLeaveScreen> {
  final ctl = AsyncListController();

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await widget.args.api.post('/get_adminLeaveApplicationListAPI');
    if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
    return rows(res['data']);
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Student leaves' : widget.args.item.label,
        child: AsyncList(
          controller: ctl,
          load: _load,
          emptyText: 'No student leave applications.',
          emptyIcon: Icons.event_busy_outlined,
          itemBuilder: (c, r, i) => LeaveCard(key: ValueKey(s(r['leave_app_id'])), api: widget.args.api, row: r, onDone: ctl.reload),
        ),
      );
}

class LeaveCard extends StatefulWidget {
  const LeaveCard({super.key, required this.api, required this.row, required this.onDone});
  final LegacyApi api;
  final Map<String, dynamic> row;
  final Future<void> Function() onDone;

  @override
  State<LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<LeaveCard> with SubmitGuard {
  final reply = TextEditingController();

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Map<String, dynamic> get r => widget.row;

  bool get replied => s(r['reply']).isNotEmpty && s(r['reply_on']).isNotEmpty && s(r['reply_by']).isNotEmpty;

  Future<void> _act(String status) async {
    await guarded(() async {
      final res = await widget.api.post('/add_adminLeaveApplicationSaveAPI', body: {
        'leave_app_id': s(r['leave_app_id']),
        'reply': reply.text.trim(),
        'status': status,
      });
      if (!mounted) return;
      if (report(res, ok: 'Leave $status.')) await widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = s(r['file_name']);
    return KitCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonAvatar(url: s(r['student_image']), name: s(r['student_name'])),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(r['student_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Standard ${s(r['std_name'])}  |  ${fmtDate(r['apply_date'], out: 'dd-MM-yyyy')}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ]),
          ),
          if (replied) Pill(s(r['status']), color: s(r['status']).toLowerCase().startsWith('approv') ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
        ]),
        gap(10),
        Text('Reason: ${s(r['title'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (s(r['message']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(s(r['message']))),
        if (file.isNotEmpty)
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
            onPressed: () => openUrl(context, file),
            icon: const Icon(Icons.attach_file_rounded, size: 18),
            label: const Text('Attachment'),
          ),
        const Divider(height: 24),
        if (replied) ...[
          KV('Reply', s(r['reply'])),
          KV('Status', s(r['status'])),
          KV('Replied on', fmtDate(r['reply_on'], out: 'dd-MM-yyyy hh:mm a')),
          KV('Replied by', s(r['reply_by'])),
        ] else ...[
          TextInput(label: 'Reply (optional)', controller: reply, lines: 2),
          gap(),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), minimumSize: const Size.fromHeight(48)),
                onPressed: busy ? null : () => _act('Approved'),
                child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Approve'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), minimumSize: const Size.fromHeight(48)),
                onPressed: busy ? null : () => _act('Reject'),
                child: const Text('Reject'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
