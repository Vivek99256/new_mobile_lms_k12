import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'student_breakoff_report_controller.dart';

/// Student Breakoff Report: for a class, every student's fee structure, what is paid and what is pending.
class StudentBreakoffReportScreen extends StatefulWidget {
  const StudentBreakoffReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentBreakoffReportScreen> createState() => _StudentBreakoffReportScreenState();
}

class _StudentBreakoffReportScreenState extends State<StudentBreakoffReportScreen> {
  late final StudentBreakoffReportController _con = StudentBreakoffReportController(args: widget.args)..addListener(_onChange);
  String _query = '';
  final _open = <int>{};

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final problem = _con.validate();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    _open.clear();
    await _con.search();
  }

  List<(int, StudentBreakoff)> get _shown {
    final q = _query.trim().toLowerCase();
    return [
      for (var i = 0; i < _con.students.length; i++)
        if (q.isEmpty || '${_con.students[i].name} ${_con.students[i].enrollmentNo} ${_con.students[i].father}'.toLowerCase().contains(q)) (i, _con.students[i]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final total = _con.students.fold<num>(0, (a, st) => a + st.amount);
    final pending = _con.students.fold<num>(0, (a, st) => a + st.pending);
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Student Breakoff Report' : widget.args.item.label,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        SoftCard(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Pick a class to see each student fee structure. (A whole school takes too long to calculate.)', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
            const SizedBox(height: 12),
            CascadeFilter(api: widget.args.api, onChanged: _con.setCascade),
            gap(10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(onPressed: _con.busy ? null : _search, icon: const Icon(Icons.search_rounded), label: Text(_con.busy ? 'Calculating…' : 'Show students')),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_con.busy) const LinearProgressIndicator(minHeight: 3),
        if (_con.error != null) Text(_con.error!, style: TextStyle(color: Brand.err, fontWeight: FontWeight.w600)),
        if (_con.searched && !_con.busy && _con.error == null && _con.students.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(child: Text(_con.message?.isNotEmpty == true ? _con.message! : 'No students found.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted))),
          ),
        if (_con.students.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              _stat('${_con.students.length}', 'Students', Colors.white),
              _divider(),
              _stat('Rs $total', 'Total fees', const Color(0xFF93C5FD)),
              _divider(),
              _stat('Rs $pending', 'Pending', pending > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC)),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search name, GR no or father',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Brand.card,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, st) in _shown) _studentCard(i, st),
        ],
      ]),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white.withValues(alpha: 0.16));

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: Brand.champagne, fontSize: 11.5)),
        ]),
      );

  Widget _studentCard(int index, StudentBreakoff st) {
    final open = _open.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => open ? _open.remove(index) : _open.add(index)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  PersonAvatar(url: '', name: st.name, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('GR ${st.enrollmentNo}${st.father.isEmpty ? '' : '  ·  ${st.father}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                    ]),
                  ),
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.ink3),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _chip('Fees', 'Rs ${st.amount}', Brand.primaryDark, Brand.tint),
                  const SizedBox(width: 8),
                  _chip('Paid', 'Rs ${st.paid}', Brand.ok, Brand.ok0),
                  const SizedBox(width: 8),
                  _chip('Pending', 'Rs ${st.pending}', st.pending > 0 ? Brand.err : Brand.ok, st.pending > 0 ? Brand.err0 : Brand.ok0),
                ]),
              ]),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Brand.line))),
              child: st.months.isEmpty
                  ? Padding(padding: EdgeInsets.only(top: 10), child: Text('No fee structure set for this student.', style: TextStyle(color: Brand.muted)))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final mo in st.months) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Row(children: [
                            Expanded(child: Text(_con.monthLabel(mo.id), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
                            Text('Rs ${mo.amount}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Brand.primaryDark)),
                          ]),
                        ),
                        for (final h in mo.heads.where((h) => h.amount != 0 || h.paid != 0))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(children: [
                              Expanded(child: Text(h.title, style: TextStyle(fontSize: 13, color: Brand.ink2))),
                              Text('Rs ${h.amount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              if (h.paid > 0) Padding(padding: const EdgeInsets.only(left: 8), child: Tag.ok('paid ${h.paid}')),
                            ]),
                          ),
                      ],
                    ]),
            ),
        ]),
      ),
    );
  }

  Widget _chip(String label, String value, Color fg, Color bg) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8))),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
          ]),
        ),
      );
}
