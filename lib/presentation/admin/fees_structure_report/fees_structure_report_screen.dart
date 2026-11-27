import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'fees_structure_report_controller.dart';

/// Fees Structure Report: what every student quota pays, month by month, for each standard.
class FeesStructureReportScreen extends StatefulWidget {
  const FeesStructureReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<FeesStructureReportScreen> createState() => _FeesStructureReportScreenState();
}

class _FeesStructureReportScreenState extends State<FeesStructureReportScreen> {
  late final FeesStructureReportController _con = FeesStructureReportController(args: widget.args)..addListener(_onChange);
  bool _old = false; // false = new students, true = old students

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
    if (_con.cascade.sectionId == null) {
      toast(context, 'Please select a section.', error: true);
      return;
    }
    await _con.search();
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Fees Structure Report' : widget.args.item.label,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          SoftCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Choose class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              CascadeFilter(api: widget.args.api, withDivision: false, onChanged: _con.setCascade),
              gap(10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(onPressed: _con.busy ? null : _search, icon: const Icon(Icons.search_rounded), label: Text(_con.busy ? 'Loading…' : 'Show structure')),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (_con.busy) const LinearProgressIndicator(minHeight: 3),
          if (_con.error != null) Text(_con.error!, style: TextStyle(color: Brand.err, fontWeight: FontWeight.w600)),
          if (_con.searched && !_con.busy && _con.error == null && _con.standards.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Center(child: Text(_con.message?.isNotEmpty == true ? _con.message! : 'No fee structure found.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted))),
            ),
          if (_con.standards.isNotEmpty) ...[
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('New students')), ButtonSegment(value: true, label: Text('Old students'))],
              selected: {_old},
              onSelectionChanged: (v) => setState(() => _old = v.first),
            ),
            const SizedBox(height: 12),
            for (final std in _con.standards) _standard(std),
          ],
        ]),
      );

  Widget _standard(StandardStructure std) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(children: [
              const IconTile(Icons.school_outlined, size: 30),
              const SizedBox(width: 10),
              Text('Standard ${std.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
          for (final q in std.quotas) _quota(q),
        ]),
      );

  Widget _quota(QuotaStructure q) {
    final byMonth = _old ? q.oldByMonth : q.newByMonth;
    final total = _old ? q.oldTotal : q.newTotal;
    final order = _con.months.keys.where(byMonth.containsKey).toList() + byMonth.keys.where((k) => !_con.months.containsKey(k)).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Brand.tint1, Brand.tint])),
            child: Row(children: [
              Icon(Icons.groups_2_rounded, size: 19, color: Brand.primaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text(q.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(999)),
                child: Text('Rs $total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Brand.primaryDark)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: order.isEmpty
                ? Text('No amounts set.', style: TextStyle(color: Brand.muted))
                : LayoutBuilder(builder: (context, c) {
                    final w = (c.maxWidth - 8) / 2;
                    return Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final id in order)
                        SizedBox(
                          width: w,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_con.monthLabel(id), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Brand.muted)),
                              const SizedBox(height: 2),
                              Text('Rs ${byMonth[id]}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                    ]);
                  }),
          ),
        ]),
      ),
    );
  }
}
