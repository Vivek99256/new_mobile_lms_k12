import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../update_fees_breakoff/breakoff_matrix_view.dart';
import 'fees_breakoff_controller.dart';
import '../../../ui/app_loader.dart';

/// Add a Fees BreakOff structure: choose sections, standards and months, then fill the amounts per student
/// quota and fee head for new and old students. Pops with true after a save.
class FeesBreakoffAddScreen extends StatefulWidget {
  const FeesBreakoffAddScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<FeesBreakoffAddScreen> createState() => _FeesBreakoffAddScreenState();
}

class _FeesBreakoffAddScreenState extends State<FeesBreakoffAddScreen> {
  late final FeesBreakoffController _con = FeesBreakoffController(args: widget.args)..addListener(_onChange);
  int _tab = 0;
  bool _changing = false;

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.init();
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final problem = _con.validateSelection();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    await _con.generate();
    if (mounted) setState(() => _changing = false);
  }

  Future<void> _save() async {
    final problem = _con.validateAmounts();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save fee structure?'),
        content: Text('This sets the fee amounts for ${_con.selectedStandards.length} standard(s) and ${_con.selectedMonths.length} month(s).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final (done, message) = await _con.save();
    if (!mounted) return;
    toast(context, message, error: !done);
    if (done) Navigator.pop(context, true);
  }

  Widget _chips(String title, List<Opt> opts, Set<String> selected, void Function(String) onTap, {String? empty}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          if (opts.isEmpty && empty != null) Text(empty, style: TextStyle(color: Brand.muted, fontSize: 12.5)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in opts)
              ChoiceChip(
                label: Text(o.label),
                selected: selected.contains(o.id),
                onSelected: (_) => onTap(o.id),
                showCheckmark: false,
                avatar: selected.contains(o.id) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                selectedColor: Brand.primary,
                backgroundColor: Brand.surface,
                labelStyle: TextStyle(color: selected.contains(o.id) ? Colors.white : Brand.ink2, fontWeight: FontWeight.w600, fontSize: 13),
                side: BorderSide(color: selected.contains(o.id) ? Brand.primary : Brand.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
          ]),
          const SizedBox(height: 14),
        ],
      );

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Add fee structure',
        bottom: _con.generated ? formBar(label: 'Save fee structure', busy: _con.busy, onPressed: _save) : null,
        child: _con.loading
            ? const AppLoader()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                BreakoffHero(
                  title: 'Add fee structure',
                  subtitle: 'Pick the classes and months, then set the amounts.',
                  icon: Icons.account_tree_rounded,
                  step: _con.generated ? 2 : 1,
                ),
                if (_con.generated && !_changing)
                  SoftCard(
                    radius: 16,
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(children: [
                      const IconTile(Icons.account_tree_rounded, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_con.selectedSections.length} grade(s) · ${_con.selectedStandards.length} standard(s) · ${_con.selectedMonths.length} month(s)',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                      TextButton(onPressed: () => setState(() => _changing = true), child: const Text('Change')),
                    ]),
                  )
                else
                SoftCard(
                  radius: 20,
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _chips('Grade', _con.sections, _con.selectedSections, _con.toggleSection),
                    _chips('Standard', _con.standards, _con.selectedStandards, _con.toggleStandard, empty: 'Select a grade first.'),
                    _chips('Months', _con.months, _con.selectedMonths, _con.toggleMonth, empty: 'No fee months. Map the fees year first.'),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _con.busy ? null : _generate,
                        icon: const Icon(Icons.grid_view_rounded),
                        label: Text(_con.busy && !_con.generated ? 'Preparing…' : 'Generate structure'),
                      ),
                    ),
                  ]),
                ),
                if (_con.error != null)
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text(_con.error!, style: TextStyle(color: Brand.err, fontWeight: FontWeight.w600))),
                if (_con.generated) ...[
                  const SizedBox(height: 14),
                  SegmentedButton<int>(
                    segments: const [ButtonSegment(value: 0, label: Text('New students')), ButtonSegment(value: 1, label: Text('Old students'))],
                    selected: {_tab},
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                  ),
                  const SizedBox(height: 12),
                  BreakoffMatrixView(titles: _con.titles, quotas: _con.quotas, matrix: _tab == 0 ? _con.newValues! : _con.oldValues!, onChanged: _con.changed),
                ],
              ]),
      );
}
