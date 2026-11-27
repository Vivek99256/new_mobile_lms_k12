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

/// Student Request Report: change requests (name, address, documents…) raised for students, with their status.
/// `GET /student/student_request_report/create` with optional from_date, to_date, grade, standard, division.
class BRequestReportScreen extends StatefulWidget {
  const BRequestReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<BRequestReportScreen> createState() => _BRequestReportScreenState();
}

class _BRequestReportScreenState extends State<BRequestReportScreen> {
  CascadeSelection _cascade = CascadeSelection();
  DateTime? _from;
  DateTime? _to;
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  String _q = '';
  String _status = 'all';
  List<Map<String, dynamic>> _rows = [];

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
      final res = await widget.args.api.get('/student/student_request_report/create', query: {
        if (_from != null) 'from_date': ymd(_from!),
        // The server compares with the stored time, so include the whole "to" day.
        if (_to != null) 'to_date': '${ymd(_to!)} 23:59:59',
        if (_cascade.sectionId != null) 'grade': _cascade.sectionId,
        if (_cascade.standardId != null) 'standard': _cascade.standardId,
        if (_cascade.divisionId != null) 'division': _cascade.divisionId,
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res, 'No requests found.'));
      _rows = rows(res['result_report']);
    });
    if (!mounted) return;
    setState(() {
      _error = err;
      _loaded = err == null;
      _loading = false;
    });
  }

  String _statusOf(Map<String, dynamic> r) {
    final t = s(r['STATUS']).toLowerCase();
    if (t.contains('approv')) return 'approved';
    if (t.contains('reject') || t.contains('declin')) return 'rejected';
    return 'pending';
  }

  int _count(String k) => _rows.where((r) => _statusOf(r) == k).length;

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = _rows.where((r) {
      if (_status != 'all' && _statusOf(r) != _status) return false;
      if (q.isEmpty) return true;
      return '${bStudentName(r)} ${s(r['enrollment_no'])} ${s(r['REQUEST'])} ${s(r['REASON'])}'.toLowerCase().contains(q);
    }).toList();
    return bPage(context, widget.args.item.label.isEmpty ? 'Student Request Report' : widget.args.item.label, [
      BHero(
        icon: Icons.assignment_late_outlined,
        title: 'Student requests',
        subtitle: _loaded ? 'Change requests raised for students' : 'Loading the requests…',
        stats: _loaded ? [('Total', '${_rows.length}'), ('Pending', '${_count('pending')}'), ('Approved', '${_count('approved')}')] : const [],
      ),
      gap(14),
      BFilterCard(
        busy: _loading,
        label: 'Show requests',
        onShow: _load,
        children: [
          CascadeFilter(api: widget.args.api, onChanged: (c) => _cascade = c),
          Row(children: [
            Expanded(child: BOptionalDate(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
            const SizedBox(width: 10),
            Expanded(child: BOptionalDate(label: 'To', value: _to, onChanged: (d) => setState(() => _to = d))),
          ]),
        ],
      ),
      if (_error != null) ...[gap(12), Notice(_error!, kind: NoticeKind.error)],
      if (_loaded && _rows.isEmpty) ...[gap(8), const KitMessage(icon: Icons.assignment_outlined, text: 'No requests found for these filters.')],
      if (_rows.isNotEmpty) ...[
        gap(12),
        BSearchBox(hint: 'Find by student, GR or request', onChanged: (v) => setState(() => _q = v)),
        gap(10),
        Wrap(spacing: 8, children: [
          for (final (k, label) in const [('all', 'All'), ('pending', 'Pending'), ('approved', 'Approved'), ('rejected', 'Rejected')])
            PillChip(label: label, selected: _status == k, onTap: () => setState(() => _status = k)),
        ]),
        gap(12),
        if (shown.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: KitMessage(icon: Icons.filter_alt_off_outlined, text: 'No request matches this filter.')),
        for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(r)),
      ],
    ]);
  }

  Widget _card(Map<String, dynamic> r) {
    final st = _statusOf(r);
    final name = bStudentName(r);
    final cls = [s(r['standard']), s(r['division'])].where((e) => e.isNotEmpty).join(' · ');
    final tag = switch (st) {
      'approved' => Tag.ok('Approved'),
      'rejected' => Tag.err('Rejected'),
      _ => Tag.warn('Pending'),
    };
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PersonAvatar(url: '', name: name, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              Text([if (s(r['enrollment_no']).isNotEmpty) 'GR ${s(r['enrollment_no'])}', if (cls.isNotEmpty) cls].join('  ·  '), style: TextStyle(color: Brand.muted, fontSize: 12)),
            ]),
          ),
          tag,
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (s(r['REQUEST']).isNotEmpty) BKeyValue('Request', s(r['REQUEST'])),
            if (s(r['REASON']).isNotEmpty) BKeyValue('Reason', s(r['REASON'])),
            if (s(r['DESCRIPTION']).isNotEmpty) BKeyValue('Description', s(r['DESCRIPTION'])),
            if (s(r['DOCUMENT_TYPE']).isNotEmpty) BKeyValue('Document', s(r['DOCUMENT_TYPE'])),
            if (s(r['CREATED_ON']).isNotEmpty) BKeyValue('Raised on', bDate(r['CREATED_ON'])),
            if (s(r['DECIDED_ON']).isNotEmpty) BKeyValue('Decided on', bDate(r['DECIDED_ON'])),
          ]),
        ),
      ]),
    );
  }
}
