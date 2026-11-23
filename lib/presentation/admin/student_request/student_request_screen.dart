import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_common/student_common.dart';
import 'student_request_controller.dart';
import 'student_request_form_screen.dart';

/// Student Request: change requests raised for students, with approve / reject and a form to raise new ones.
class StudentRequestScreen extends StatefulWidget {
  const StudentRequestScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentRequestScreen> createState() => _StudentRequestScreenState();
}

class _StudentRequestScreenState extends State<StudentRequestScreen> {
  late final StudentRequestController _con = StudentRequestController(args: widget.args)..addListener(_onChange);

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.load();
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _raise() => push<void>(context, StudentRequestFormScreen(con: _con, args: widget.args));

  (Color, Color) _tone(String status) => switch (status) {
        'Approved' => (Brand.ok, Brand.ok0),
        'Rejected' => (Brand.err, Brand.err0),
        _ => (Brand.warn, Brand.warn0),
      };

  Future<void> _decide(ChangeRequest r, bool approve) async {
    final yes = await confirm(
      context,
      approve ? 'Approve request?' : 'Reject request?',
      '${r.type.isEmpty ? 'This request' : r.type} for ${r.student} will be marked ${approve ? 'approved' : 'rejected'}.',
      yes: approve ? 'Approve' : 'Reject',
    );
    if (!yes || !mounted) return;
    final (ok, message) = await _con.decide(r, approve);
    if (!mounted) return;
    toast(context, message, error: !ok);
    if (ok) Navigator.pop(context);
  }

  void _open(ChangeRequest r) {
    final (fg, bg) = _tone(r.status);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PersonAvatar(url: r.image, name: r.student, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.student, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text([r.cls, if (r.gr.isNotEmpty) 'GR ${r.gr}'].where((e) => e.isNotEmpty).join('  ·  '), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
              Tag(r.status, fg: fg, bg: bg),
            ]),
            const SizedBox(height: 14),
            SoftCard(
              radius: 14,
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                KV('Request', r.type),
                KV('Parent', r.father),
                KV('Grade', r.grade),
                KV('Reason', r.reason),
                KV('Description', r.description),
                KV('Document', r.proof),
                KV('Raised on', fmtDate(r.createdOn)),
                if (r.status != 'Pending') KV('Decided on', fmtDate(r.decidedOn)),
              ]),
            ),
            if (r.proof.startsWith('http'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(onPressed: () => openUrl(context, r.proof), icon: const Icon(Icons.open_in_new_rounded, size: 18), label: const Text('Open document')),
              ),
            if (r.status == 'Pending') ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: Brand.err, side: const BorderSide(color: Brand.err)),
                    onPressed: () => _decide(r, false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: Brand.ok),
                    onPressed: () => _decide(r, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _card(ChangeRequest r) {
    final (fg, bg) = _tone(r.status);
    return SoftCard(
      radius: 16,
      onTap: () => _open(r),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PersonAvatar(url: r.image, name: r.student, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.student, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            Text([r.cls, if (r.gr.isNotEmpty) 'GR ${r.gr}'].where((e) => e.isNotEmpty).join('  ·  '), style: const TextStyle(color: Brand.muted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(r.type.isEmpty ? 'Request' : r.type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Brand.primaryDark)),
            if (r.reason.isNotEmpty) Text(r.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.ink2, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Tag(r.status, fg: fg, bg: bg),
          const SizedBox(height: 6),
          Text(fmtDate(r.createdOn, out: 'dd MMM'), style: const TextStyle(color: Brand.muted, fontSize: 11.5)),
        ]),
      ]),
    );
  }

  Widget _filters() => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent, inputDecorationTheme: studentInputTheme()),
        child: SoftCard(
          radius: 16,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: const IconTile(Icons.filter_list_rounded, size: 32),
            title: const Text('Filter by class', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            children: [
              CascadeFilter(api: widget.args.api, onChanged: _con.setFilter),
              gap(12),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: _con.load, child: const Text('Apply filter'))),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_con.loading && _con.requests.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_con.error != null && _con.requests.isEmpty) {
      body = KitMessage(icon: Icons.cloud_off_outlined, text: _con.error!, action: 'Try again', onAction: _con.load);
    } else {
      final list = _con.visible;
      body = RefreshIndicator(
        onRefresh: _con.load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          StudentHero(
            title: 'Student requests',
            subtitle: 'Review change requests and raise new ones.',
            icon: Icons.assignment_ind_outlined,
            stats: [('Pending', '${_con.count('Pending')}'), ('Approved', '${_con.count('Approved')}'), ('Rejected', '${_con.count('Rejected')}')],
          ),
          _filters(),
          gap(12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in const ['All', 'Pending', 'Approved', 'Rejected']) PillChip(label: f, selected: _con.statusFilter == f, onTap: () => _con.setStatusFilter(f)),
            ]),
          ),
          gap(12),
          if (_con.loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(minHeight: 3)),
          if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 30), child: KitMessage(icon: Icons.assignment_outlined, text: 'No requests to show.')),
          for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(r)),
        ]),
      );
    }
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Student Request' : widget.args.item.label,
      bottom: formBar(label: 'Raise a request', busy: false, onPressed: _raise),
      child: body,
    );
  }
}
