import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../fees_collect/fees_details/online_receipt_view.dart';
import 'fees_circular_controller.dart';
import '../../../ui/app_loader.dart';

/// Fees Circular: choose a class, months and receipt book, find students and generate their fee circulars.
class FeesCircularScreen extends StatefulWidget {
  const FeesCircularScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<FeesCircularScreen> createState() => _FeesCircularScreenState();
}

class _FeesCircularScreenState extends State<FeesCircularScreen> {
  late final FeesCircularController _con = FeesCircularController(args: widget.args)..addListener(_onChange);

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.loadFilters();
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
    await _con.searchStudents();
  }

  Future<void> _generate() async {
    final ok = await _con.generate();
    if (!mounted) return;
    if (!ok) {
      if (_con.error != null) toast(context, _con.error!, error: true);
      return;
    }
    await push(context, _CircularResultScreen(con: _con));
  }

  @override
  Widget build(BuildContext context) {
    final n = _con.selectedStudents.length;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Fees Circular' : widget.args.item.label,
      bottom: n == 0 ? null : formBar(label: 'Generate circular for $n', busy: _con.busy, onPressed: _generate),
      child: _con.loadingFilters
          ? const AppLoader()
          : _con.error != null && _con.months.isEmpty
              ? KitMessage(icon: Icons.error_outline, text: _con.error!, action: 'Retry', onAction: _con.loadFilters)
              : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                  SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 10),
                      CascadeFilter(api: widget.args.api, onChanged: _con.setCascade),
                      gap(6),
                      const Text('Months', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final mo in _con.months)
                          FilterChip(
                            label: Text(mo.label),
                            selected: _con.selectedMonths.contains(mo.id),
                            onSelected: (_) => _con.toggleMonth(mo.id),
                            selectedColor: Brand.tint1,
                            checkmarkColor: Brand.primaryDark,
                          ),
                      ]),
                      gap(14),
                      DropdownField(label: 'Receipt book', options: _con.receiptBooks, value: _con.receiptId, onChanged: _con.setReceipt),
                      gap(14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _con.busy ? null : _search,
                          icon: const Icon(Icons.search_rounded),
                          label: Text(_con.busy ? 'Searching…' : 'Find students'),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  if (_con.busy) const LinearProgressIndicator(minHeight: 3),
                  if (_con.error != null && _con.searched)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_con.error!, style: TextStyle(color: Brand.err, fontWeight: FontWeight.w600))),
                  if (_con.searched && !_con.busy && _con.students.isEmpty && _con.error == null)
                    Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('No students found.', style: TextStyle(color: Brand.muted)))),
                  if (_con.students.isNotEmpty) ...[
                    Row(children: [
                      Text('${_con.students.length} students', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const Spacer(),
                      TextButton(onPressed: _con.toggleAll, child: Text(_con.selectedStudents.length == _con.students.length ? 'Clear all' : 'Select all')),
                    ]),
                    const SizedBox(height: 4),
                    for (final st in _con.students)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _studentTile(st),
                      ),
                  ],
                ]),
    );
  }

  Widget _studentTile(CircularStudent st) {
    final on = _con.selectedStudents.contains(st.id);
    return Container(
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: on ? Brand.primary : Brand.line, width: on ? 1.5 : 1),
        boxShadow: Brand.softShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _con.toggleStudent(st.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: on ? Brand.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: on ? null : Border.all(color: Brand.border, width: 2),
              ),
              child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text('GR ${st.enrollmentNo}${st.stdDiv.isEmpty ? '' : '  ·  ${st.stdDiv}'}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              ]),
            ),
            if (st.pending > 0) Tag.err('Due Rs ${st.pending}') else Tag.ok('Clear'),
          ]),
        ),
      ),
    );
  }
}

/// The generated circulars: fee heads and total per student, plus the printable circular when the server sends one.
class _CircularResultScreen extends StatelessWidget {
  const _CircularResultScreen({required this.con});
  final FeesCircularController con;

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Fee circulars',
        bottom: con.html.isEmpty ? null : formBar(label: 'View printable circular', busy: false, onPressed: () => push(context, OnlineReceiptView(html: con.html))),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Brand.ok0, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: Brand.ok),
              const SizedBox(width: 10),
              Expanded(child: Text(con.resultMessage, style: TextStyle(color: Brand.ok, fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 12),
          for (final g in con.generated)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    Text('Rs ${g.total}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Brand.primaryDark)),
                  ]),
                  const SizedBox(height: 2),
                  Text('GR ${g.enrollmentNo}${g.cls.isEmpty ? '' : '  ·  ${g.cls}'}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                  if (g.total == 0)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Brand.warn0, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        g.otherMonths.isEmpty
                            ? 'No fee is set for the selected months.'
                            : 'No fee in the selected months. This student has fees in: ${g.otherMonths.join(', ')}. Go back and select those months.',
                        style: TextStyle(color: Brand.warn, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (g.heads.isNotEmpty) ...[
                    const Divider(height: 20),
                    for (final h in g.heads)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(child: Text(h.$1, style: TextStyle(fontSize: 13.5, color: Brand.ink2))),
                          Text('Rs ${h.$2}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ]),
                      ),
                  ],
                ]),
              ),
            ),
          if (con.generated.isEmpty) Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('Circulars were generated.', style: TextStyle(color: Brand.muted)))),
        ]),
      );
}
