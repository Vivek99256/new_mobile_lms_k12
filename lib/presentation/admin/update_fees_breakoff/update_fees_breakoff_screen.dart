import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'breakoff_matrix_view.dart';
import 'update_fees_breakoff_controller.dart';

/// Update Fees BreckOff: change the fee amounts of a class for one billing month, per student quota,
/// for new and old students. Quotas that already have collected fees are locked, as on the web.
class UpdateFeesBreakoffScreen extends StatefulWidget {
  const UpdateFeesBreakoffScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<UpdateFeesBreakoffScreen> createState() => _UpdateFeesBreakoffScreenState();
}

class _UpdateFeesBreakoffScreenState extends State<UpdateFeesBreakoffScreen> {
  late final UpdateFeesBreakoffController _con = UpdateFeesBreakoffController(args: widget.args)..addListener(_onChange);
  int _tab = 0; // 0 = new students, 1 = old students
  bool _changing = false; // show the filters again after a structure is loaded

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.loadMonths();
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final problem = _con.validateSearch();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    await _con.search();
    if (mounted) setState(() => _changing = false);
  }

  Future<void> _submit() async {
    final problem = _con.validateAmounts();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Update fee structure?'),
        content: const Text('The amounts for this class and month will be replaced for new and old students. Quotas with collected fees stay locked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Update')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final (done, message) = await _con.submit();
    if (!mounted) return;
    toast(context, message, error: !done);
    if (done) _con.resetAfterSave();
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Update Fees BreckOff' : widget.args.item.label,
        bottom: _con.loaded ? formBar(label: 'Update fee structure', busy: _con.busy, onPressed: _submit) : null,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          BreakoffHero(
            title: 'Update fee structure',
            subtitle: 'Change the amounts of a class for one billing month.',
            icon: Icons.edit_note_rounded,
            step: _con.loaded ? 2 : 1,
          ),
          if (_con.loaded && !_changing)
            SoftCard(
              radius: 16,
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(children: [
                const IconTile(Icons.school_outlined, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      [_con.cascade.sectionName, _con.cascade.standardName].where((e) => (e ?? '').isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      _con.months.where((o) => o.id == _con.month).map((o) => o.label).firstOrNull ?? '',
                      style: TextStyle(color: Brand.muted, fontSize: 12.5),
                    ),
                  ]),
                ),
                TextButton(onPressed: () => setState(() => _changing = true), child: const Text('Change')),
              ]),
            )
          else
          SoftCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Find fee structure', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Choose the class and billing month, then edit the amounts.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              const SizedBox(height: 12),
              CascadeFilter(api: widget.args.api, withDivision: false, onChanged: _con.setCascade),
              gap(6),
              DropdownField(label: 'Billing month', options: _con.months, value: _con.month, loading: _con.loadingMonths, onChanged: _con.setMonth),
              gap(14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(onPressed: _con.busy ? null : _search, icon: const Icon(Icons.search_rounded), label: Text(_con.busy && !_con.loaded ? 'Loading…' : 'Search structure')),
              ),
            ]),
          ),
          if (_con.error != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_con.error!, style: TextStyle(color: Brand.err, fontWeight: FontWeight.w600))),
          if (_con.loaded) ...[
            const SizedBox(height: 14),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 0, label: Text('New students')), ButtonSegment(value: 1, label: Text('Old students'))],
              selected: {_tab},
              onSelectionChanged: (v) => setState(() => _tab = v.first),
            ),
            const SizedBox(height: 12),
            ..._matrix(_tab == 0 ? _con.current! : _con.previous!, _tab == 0 ? _con.paidCurrent : _con.paidPrevious),
          ],
        ]),
      );

  List<Widget> _matrix(BreakoffMatrix mx, Set<String> locked) => [
        BreakoffMatrixView(titles: _con.titles, quotas: _con.quotas, matrix: mx, locked: locked, onChanged: _con.changed),
      ];
}
