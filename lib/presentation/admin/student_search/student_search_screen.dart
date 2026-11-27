import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'student_detail_screen.dart';
import 'student_search_controller.dart';

/// Search / Edit Student: find students by class, name or GR number, open one to see everything and edit it.
class StudentSearchScreen extends StatefulWidget {
  const StudentSearchScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  late final StudentSearchController _con = StudentSearchController(args: widget.args)..addListener(_onChange);
  String _filter = '';

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
    await _con.search();
  }

  List<StudentRecord> get _shown {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _con.students;
    return _con.students.where((s) => '${s.name} ${s.enrollmentNo} ${s.mobile} ${s.rollNo}'.toLowerCase().contains(q)).toList();
  }

  Future<void> _open(StudentRecord st) async {
    final changed = await push<bool>(context, StudentDetailScreen(args: widget.args, student: st, controller: _con));
    if (changed == true) await _con.search();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final inactive = _con.students.where((s) => s.inactive).length;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Search / Edit Student' : widget.args.item.label,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        SoftCard(
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Find students', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            CascadeFilter(api: widget.args.api, onChanged: _con.setCascade),
            gap(6),
            Row(children: [
              Expanded(child: TextInput(label: 'First name', controller: _con.firstName)),
              const SizedBox(width: 10),
              Expanded(child: TextInput(label: 'GR no', controller: _con.grNo)),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Include inactive students', style: TextStyle(fontSize: 13.5)),
              value: _con.includeInactive,
              onChanged: _con.setInactive,
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(onPressed: _con.busy ? null : _search, icon: const Icon(Icons.search_rounded), label: Text(_con.busy ? 'Searching…' : 'Search students')),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_con.busy) const LinearProgressIndicator(minHeight: 3),
        if (_con.error != null) Text(_con.error!, style: TextStyle(color: Brand.err, fontWeight: FontWeight.w600)),
        if (_con.searched && !_con.busy && _con.error == null && _con.students.isEmpty)
          Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('No students found.', style: TextStyle(color: Brand.muted)))),
        if (_con.students.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              CountUp(value: _con.students.length, builder: (v) => Text('$v', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1))),
              const SizedBox(width: 10),
              const Text('students', style: TextStyle(color: Brand.champagne, fontSize: 13)),
              const Spacer(),
              if (inactive > 0) Tag('$inactive inactive', fg: Colors.white, bg: Colors.white24),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _filter = v),
            decoration: InputDecoration(
              hintText: 'Filter by name, GR, roll or mobile',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Brand.card,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < shown.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(shown[i])),
        ],
      ]),
    );
  }

  Widget _card(StudentRecord st) => Container(
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(st),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              PersonAvatar(url: '', name: st.name, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Brand.ink)),
                  const SizedBox(height: 2),
                  Text('GR ${st.enrollmentNo}${st.rollNo.isEmpty ? '' : '  ·  Roll ${st.rollNo}'}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (st.cls.isNotEmpty) Tag(st.cls),
                    if (st.genderLabel.isNotEmpty) Tag.neutral(st.genderLabel),
                    if (st.inactive) Tag.warn('Inactive'),
                  ]),
                ]),
              ),
              if (st.mobile.isNotEmpty)
                IconButton.filledTonal(
                  tooltip: 'Call',
                  onPressed: () => openUrl(context, 'tel:${st.mobile}'),
                  icon: const Icon(Icons.call_rounded, size: 18),
                ),
              Icon(Icons.chevron_right_rounded, color: Brand.ink3),
            ]),
          ),
        ),
      );
}
