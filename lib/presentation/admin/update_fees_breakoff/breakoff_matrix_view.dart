import 'package:flutter/material.dart';

import '../../../ui/theme.dart';
import 'update_fees_breakoff_controller.dart';

/// The fee-structure editor shared by Update Fees BreckOff and Add Fees BreakOff.
///
/// Built to need little scrolling: one collapsible card per student quota (header = name, total, how many heads are
/// filled), the amount fields in two compact columns, a box to find a fee head, "expand / collapse all", and a
/// "copy these amounts to all quotas" action. Locked quotas (fees already collected) stay read-only.
class BreakoffMatrixView extends StatefulWidget {
  const BreakoffMatrixView({
    super.key,
    required this.titles,
    required this.quotas,
    required this.matrix,
    required this.onChanged,
    this.locked = const {},
  });

  final List<(String, String)> titles;
  final List<(String, String)> quotas;
  final BreakoffMatrix matrix;
  final Set<String> locked;
  final VoidCallback onChanged;

  @override
  State<BreakoffMatrixView> createState() => _BreakoffMatrixViewState();
}

class _BreakoffMatrixViewState extends State<BreakoffMatrixView> {
  late Set<String> _open = {if (widget.quotas.isNotEmpty) widget.quotas.first.$1};
  String _filter = '';

  num _total(String quota) => widget.matrix.cells[quota]?.values.fold<num>(0, (a, c) => a + (num.tryParse(c.text.trim()) ?? 0)) ?? 0;

  int _filled(String quota) => widget.matrix.cells[quota]?.values.where((c) => c.text.trim().isNotEmpty).length ?? 0;

  List<(String, String)> get _heads {
    final q = _filter.trim().toLowerCase();
    return q.isEmpty ? widget.titles : widget.titles.where((t) => t.$2.toLowerCase().contains(q)).toList();
  }

  void _copyToAll(String from) {
    final src = widget.matrix.cells[from];
    if (src == null) return;
    for (final q in widget.quotas) {
      if (q.$1 == from || widget.locked.contains(q.$1)) continue;
      for (final t in widget.titles) {
        widget.matrix.cells[q.$1]?[t.$1]?.text = src[t.$1]?.text ?? '';
      }
    }
    setState(() {});
    widget.onChanged();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Copied to all other quotas (locked ones were skipped).'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final allOpen = widget.quotas.every((q) => _open.contains(q.$1));
    return Column(children: [
      if (widget.quotas.isEmpty)
        Padding(padding: EdgeInsets.only(top: 20), child: Center(child: Text('No student quotas for this class.', style: TextStyle(color: Brand.muted)))),
      if (widget.quotas.isNotEmpty) ...[
        Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              decoration: InputDecoration(
                hintText: 'Find a fee head',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Brand.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() => _open = allOpen ? {} : {for (final q in widget.quotas) q.$1}),
            icon: Icon(allOpen ? Icons.unfold_less_rounded : Icons.unfold_more_rounded, size: 18),
            label: Text(allOpen ? 'Collapse' : 'Expand'),
          ),
        ]),
        const SizedBox(height: 12),
      ],
      for (final q in widget.quotas) _quotaCard(q),
    ]);
  }

  Widget _quotaCard((String, String) q) {
    final isLocked = widget.locked.contains(q.$1);
    final open = _open.contains(q.$1);
    final total = _total(q.$1);
    final filled = _filled(q.$1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Brand.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isLocked ? const Color(0xFFFECDD3) : Brand.line),
          boxShadow: Brand.softShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => open ? _open.remove(q.$1) : _open.add(q.$1)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isLocked ? const [Color(0xFFFFE4E6), Color(0xFFFFF1F2)] : [Brand.tint1, Brand.tint]),
              ),
              child: Row(children: [
                Icon(isLocked ? Icons.lock_rounded : Icons.groups_2_rounded, size: 19, color: isLocked ? Brand.err : Brand.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(q.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Brand.ink)),
                    Text(
                      isLocked ? 'Fees collected, locked' : '$filled of ${widget.titles.length} heads filled',
                      style: TextStyle(fontSize: 11.5, color: isLocked ? Brand.err : Brand.muted),
                    ),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Brand.card, borderRadius: BorderRadius.circular(999)),
                  child: Text('Rs $total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isLocked ? Brand.err : Brand.primaryDark)),
                ),
                if (!isLocked)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: Brand.ink3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (v) {
                      if (v == 'copy') _copyToAll(q.$1);
                      if (v == 'clear') {
                        for (final c in widget.matrix.cells[q.$1]!.values) {
                          c.clear();
                        }
                        setState(() {});
                        widget.onChanged();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_all_rounded, size: 18), SizedBox(width: 10), Text('Copy to all quotas')])),
                      PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.layers_clear_outlined, size: 18), SizedBox(width: 10), Text('Clear amounts')])),
                    ],
                  )
                else
                  const SizedBox(width: 8),
                Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.ink3),
                const SizedBox(width: 6),
              ]),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: _heads.isEmpty
                  ? Text('No fee head matches.', style: TextStyle(color: Brand.muted))
                  : LayoutBuilder(builder: (context, c) {
                      final w = (c.maxWidth - 10) / 2;
                      return Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final t in _heads)
                          SizedBox(
                            width: w,
                            child: TextField(
                              controller: widget.matrix.cells[q.$1]![t.$1],
                              enabled: !isLocked,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) {
                                setState(() {});
                                widget.onChanged();
                              },
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: t.$2,
                                prefixText: 'Rs ',
                                isDense: true,
                                filled: true,
                                fillColor: Brand.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                labelStyle: const TextStyle(fontSize: 12.5),
                              ),
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

/// Header of the two breakoff screens: icon, title, one-line help and a 2-step progress (choose -> amounts).
class BreakoffHero extends StatelessWidget {
  const BreakoffHero({super.key, required this.title, required this.subtitle, required this.icon, required this.step});
  final String title;
  final String subtitle;
  final IconData icon;

  /// 1 = choosing the class and months, 2 = editing the amounts.
  final int step;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Brand.champagne, fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _dot(1, 'Choose'),
            Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.white.withValues(alpha: step >= 2 ? 0.7 : 0.2))),
            _dot(2, 'Amounts'),
          ]),
        ]),
      );

  Widget _dot(int n, String label) {
    final on = step >= n;
    return Row(children: [
      Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on ? Colors.white : Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: on && step > n
            ? const Icon(Icons.check_rounded, size: 14, color: Brand.navy)
            : Text('$n', style: TextStyle(color: on ? Brand.navy : Colors.white70, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: on ? Colors.white : Colors.white70, fontWeight: FontWeight.w600, fontSize: 12.5)),
    ]);
  }
}
