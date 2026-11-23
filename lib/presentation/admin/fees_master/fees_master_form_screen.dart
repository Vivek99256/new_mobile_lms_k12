import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'fees_master_controller.dart';
import 'fees_master_spec.dart';

/// Add / Edit form of a Fees (Master), drawn from its [FeesMasterSpec]. Pops with true after a save.
class FeesMasterFormScreen extends StatefulWidget {
  const FeesMasterFormScreen({super.key, required this.args, required this.spec, this.row});
  final ScreenArgs args;
  final FeesMasterSpec spec;
  final Map<String, dynamic>? row;

  @override
  State<FeesMasterFormScreen> createState() => _FeesMasterFormScreenState();
}

class _FeesMasterFormScreenState extends State<FeesMasterFormScreen> {
  late final FeesMasterController _con = FeesMasterController(args: widget.args, spec: widget.spec, row: widget.row)..addListener(_onChange);

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

  Future<void> _save() async {
    final problem = _con.validate();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    final (ok, message) = await _con.save();
    if (!mounted) return;
    toast(context, message, error: !ok);
    if (ok) Navigator.pop(context, true);
  }

  // ---------------------------------------------------------------- fields

  InputDecorationTheme get _inputTheme => InputDecorationTheme(
        filled: true,
        fillColor: Brand.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.primary, width: 1.6)),
        labelStyle: const TextStyle(color: Brand.ink3, fontSize: 14),
      );

  Widget _field(MField f) {
    final label = f.required ? '${f.label} *' : f.label;
    Widget body;
    switch (f.kind) {
      case MKind.date:
        body = DateField(label: label, value: _con.dates[f.key], onChanged: (d) => _con.setDate(f.key, d));
      case MKind.dropdown:
        body = DropdownField(label: label, options: _con.options[f.options] ?? const [], value: _con.picks[f.key], onChanged: (v) => _con.setPick(f.key, v));
      case MKind.multi:
        body = _multi(f, label);
      case MKind.toggle:
        body = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.line)),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            subtitle: f.hint == null ? null : Text(f.hint!, style: const TextStyle(fontSize: 12, color: Brand.muted)),
            value: _con.toggles[f.key] ?? false,
            onChanged: (v) => _con.setToggle(f.key, v),
          ),
        );
      default:
        final input = TextInput(
          label: label,
          controller: _con.text[f.key]!,
          lines: f.lines,
          keyboard: f.kind == MKind.number ? const TextInputType.numberWithOptions(decimal: true) : null,
        );
        body = f.readOnly
            ? Opacity(
                opacity: 0.65,
                child: Stack(alignment: Alignment.centerRight, children: [
                  AbsorbPointer(child: input),
                  const Padding(padding: EdgeInsets.only(right: 14), child: Icon(Icons.lock_outline_rounded, size: 18, color: Brand.muted)),
                ]),
              )
            : input;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        body,
        if (f.hint != null && f.kind != MKind.toggle)
          Padding(padding: const EdgeInsets.only(top: 5, left: 4), child: Text(f.hint!, style: const TextStyle(fontSize: 12, color: Brand.muted))),
      ]),
    );
  }

  Widget _multi(MField f, String label) {
    final opts = _con.options[f.options] ?? const [];
    final chosen = _con.multis[f.key]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
        if (chosen.isNotEmpty) Tag('${chosen.length} selected'),
      ]),
      const SizedBox(height: 10),
      if (opts.isEmpty)
        Text(f.dependsOn != null ? 'Select the option above first.' : 'Nothing to choose from.', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in opts)
          ChoiceChip(
            label: Text(o.label),
            selected: chosen.contains(o.id),
            onSelected: (_) => _con.toggleMulti(f.key, o.id),
            showCheckmark: false,
            avatar: chosen.contains(o.id) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            selectedColor: Brand.primary,
            backgroundColor: Brand.surface,
            labelStyle: TextStyle(color: chosen.contains(o.id) ? Colors.white : Brand.ink2, fontWeight: FontWeight.w600, fontSize: 13),
            side: BorderSide(color: chosen.contains(o.id) ? Brand.primary : Brand.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
      ]),
    ]);
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconTile(icon, size: 30),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Brand.ink)),
            ]),
            const SizedBox(height: 14),
            ...children,
          ]),
        ),
      );

  /// Fields grouped by their `section`, in the order the sections first appear.
  List<Widget> _sections() {
    final order = <String>[];
    final groups = <String, List<MField>>{};
    for (final f in _con.fields) {
      final key = f.section ?? 'Details';
      if (!groups.containsKey(key)) order.add(key);
      groups.putIfAbsent(key, () => []).add(f);
    }
    return [
      if (widget.spec.needsClass)
        _section('Class', Icons.school_outlined, [
          if (_con.editing && !_con.changeClass)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const Expanded(child: Text('Class is already set.', style: TextStyle(color: Brand.muted))),
                TextButton(onPressed: () => _con.setChangeClass(true), child: const Text('Change class')),
              ]),
            )
          else
            CascadeFilter(api: widget.args.api, withDivision: false, onChanged: _con.setCascade),
        ]),
      for (final name in order) _section(name, _iconFor(name), [for (final f in groups[name]!) _field(f)]),
    ];
  }

  IconData _iconFor(String section) {
    final s = section.toLowerCase();
    if (s.contains('bank') || s.contains('account')) return Icons.account_balance_outlined;
    if (s.contains('address')) return Icons.location_on_outlined;
    if (s.contains('template') || s.contains('receipt')) return Icons.receipt_long_outlined;
    if (s.contains('nach')) return Icons.autorenew_rounded;
    if (s.contains('cover') || s.contains('class') || s.contains('applies')) return Icons.groups_2_outlined;
    if (s.contains('number')) return Icons.pin_outlined;
    return widget.spec.icon;
  }

  Widget _header() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15)),
            child: Icon(widget.spec.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_con.editing ? 'Edit' : 'New'} ${widget.spec.title.toLowerCase()}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                widget.spec.subtitle.isEmpty ? (_con.editing ? 'Change what you need and save.' : 'Fill in the details and save.') : widget.spec.subtitle,
                style: const TextStyle(color: Brand.champagne, fontSize: 12.5),
              ),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.spec.title,
        bottom: _con.loading ? null : formBar(label: _con.editing ? 'Save changes' : 'Save', busy: _con.saving, onPressed: _save),
        child: _con.loading
            ? const Center(child: CircularProgressIndicator())
            : Theme(
                data: Theme.of(context).copyWith(inputDecorationTheme: _inputTheme),
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                  _header(),
                  if (_con.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Brand.err0, borderRadius: BorderRadius.circular(12)),
                      child: Text(_con.error!, style: const TextStyle(color: Brand.err, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ..._sections(),
                ]),
              ),
      );
}
