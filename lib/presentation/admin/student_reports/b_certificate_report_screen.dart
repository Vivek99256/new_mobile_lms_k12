import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'b_common.dart';

/// Student Certificate Report: certificates already issued, found by class, name, GR no, type or date.
/// `GET /student/student_certificate_report` lists the certificate types; `GET .../create` searches
/// (grade, standard, division, stu_name, grno, certificate_type, from_date, to_date).
class BCertificateReportScreen extends StatefulWidget {
  const BCertificateReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<BCertificateReportScreen> createState() => _BCertificateReportScreenState();
}

class _BCertificateReportScreenState extends State<BCertificateReportScreen> {
  CascadeSelection _cascade = CascadeSelection();
  final _name = TextEditingController();
  final _gr = TextEditingController();
  String? _type;
  List<Opt> _types = [];
  bool _loadingTypes = true;
  DateTime? _from;
  DateTime? _to;
  bool _loading = false;
  bool _searched = false;
  String? _error;
  String _q = '';
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _name.dispose();
    _gr.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final err = await bGuard(() async {
      final res = await widget.args.api.get('/student/student_certificate_report');
      _types = [
        for (final r in rows(res['report_types']))
          if (s(r['module_name']).isNotEmpty) Opt(s(r['module_name']), s(r['module_name'])),
      ];
    });
    if (!mounted) return;
    setState(() {
      _loadingTypes = false;
      if (err != null) _error = err;
    });
  }

  Future<void> _search() async {
    final hasWho = _cascade.standardId != null || _name.text.trim().isNotEmpty || _gr.text.trim().isNotEmpty;
    if (!hasWho) {
      toast(context, 'Choose a standard, or enter a name or GR number.', error: true);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await bGuard(() async {
      final res = await widget.args.api.get('/student/student_certificate_report/create', query: {
        if (_cascade.sectionId != null) 'grade': _cascade.sectionId,
        if (_cascade.standardId != null) 'standard': _cascade.standardId,
        if (_cascade.divisionId != null) 'division': _cascade.divisionId,
        if (_name.text.trim().isNotEmpty) 'stu_name': _name.text.trim(),
        if (_gr.text.trim().isNotEmpty) 'grno': _gr.text.trim(),
        if (_type != null) 'certificate_type': _type,
        // Both dates are needed for a range (the server only filters when it gets them).
        if (_from != null && _to != null) 'from_date': '${ymd(_from!)} 00:00:00',
        if (_from != null && _to != null) 'to_date': '${ymd(_to!)} 23:59:59',
      });
      // status 0 here only means "no student / no certificate found": show it as an empty result.
      _rows = statusOf(res) == '0' ? [] : rows(res['result_report']);
    });
    if (!mounted) return;
    setState(() {
      _error = err;
      _searched = err == null;
      _loading = false;
    });
  }

  void _view(Map<String, dynamic> r) {
    final html = s(r['certificate_html']);
    if (html.isEmpty) {
      toast(context, 'This certificate has no saved copy.', error: true);
      return;
    }
    final type = s(r['certificate_type']);
    push(context, BHtmlPage(title: type.isEmpty ? 'Certificate' : type, html: html));
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final shown = _rows.where((r) => q.isEmpty || '${bStudentName(r)} ${s(r['enrollment_no'])} ${s(r['certificate_type'])} ${s(r['certificate_number'])}'.toLowerCase().contains(q)).toList();
    return bPage(context, widget.args.item.label.isEmpty ? 'Certificate Report' : widget.args.item.label, [
      BHero(
        icon: Icons.workspace_premium_outlined,
        title: 'Issued certificates',
        subtitle: _searched ? '${_rows.length} certificate${_rows.length == 1 ? '' : 's'} found' : 'Search by class, name or GR number.',
        stats: _searched ? [('Certificates', '${_rows.length}'), ('Students', '${_rows.map((r) => s(r['student_id'])).toSet().length}')] : const [],
      ),
      gap(14),
      BFilterCard(
        busy: _loading,
        label: 'Search certificates',
        onShow: _search,
        children: [
          CascadeFilter(api: widget.args.api, onChanged: (c) => _cascade = c),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Student name (optional)')),
          TextField(controller: _gr, decoration: const InputDecoration(labelText: 'GR / admission no (optional)')),
          DropdownField(
            label: 'Certificate type',
            options: [const Opt('', 'All types'), ..._types],
            value: _type ?? '',
            loading: _loadingTypes,
            onChanged: (v) => setState(() => _type = (v == null || v.isEmpty) ? null : v),
          ),
          Row(children: [
            Expanded(child: BOptionalDate(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
            const SizedBox(width: 10),
            Expanded(child: BOptionalDate(label: 'To', value: _to, onChanged: (d) => setState(() => _to = d))),
          ]),
        ],
      ),
      if (_error != null) ...[gap(12), Notice(_error!, kind: NoticeKind.error)],
      if (_searched && _rows.isEmpty) ...[gap(8), const KitMessage(icon: Icons.workspace_premium_outlined, text: 'No certificate found.')],
      if (_rows.isNotEmpty) ...[
        gap(12),
        BSearchBox(hint: 'Find in these results', onChanged: (v) => setState(() => _q = v)),
        gap(12),
        for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(r)),
      ],
    ]);
  }

  Widget _card(Map<String, dynamic> r) {
    final name = bStudentName(r);
    final std = s(r['standard_name']).isNotEmpty ? s(r['standard_name']) : s(r['standard']);
    final div = s(r['division_name']).isNotEmpty ? s(r['division_name']) : s(r['division']);
    final cls = [std, div].where((e) => e.isNotEmpty).join(' · ');
    final no = s(r['certificate_number']);
    return SoftCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: () => _view(r),
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
          Icon(Icons.chevron_right_rounded, color: Brand.ink3),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (s(r['certificate_type']).isNotEmpty) Tag(s(r['certificate_type'])),
          if (no.isNotEmpty) Tag.neutral('No. $no'),
          if (s(r['created_at']).isNotEmpty) Tag.neutral(bDate(r['created_at'])),
        ]),
      ]),
    );
  }
}
