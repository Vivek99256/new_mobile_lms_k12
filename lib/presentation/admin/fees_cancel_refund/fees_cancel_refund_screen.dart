import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'fees_cancel_refund_controller.dart';

/// Fees Cancel/Refund: cancel paid receipts, or refund paid fee heads. Same two workflows as the web.
class FeesCancelRefundScreen extends StatefulWidget {
  const FeesCancelRefundScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<FeesCancelRefundScreen> createState() => _FeesCancelRefundScreenState();
}

class _FeesCancelRefundScreenState extends State<FeesCancelRefundScreen> {
  late final FeesCancelRefundController _con = FeesCancelRefundController(args: widget.args)..addListener(_onChange);
  int _tab = 0;

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Back')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: Brand.err), onPressed: () => Navigator.pop(c, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _cancel() async {
    final problem = _con.validateCancel();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    final n = _con.chosen.length;
    final ok = await _confirm('Cancel $n receipt${n == 1 ? '' : 's'}?', 'Total Rs ${_con.chosenTotal}. The receipts will be cancelled and the fees become payable again.', 'Cancel receipts');
    if (!ok) return;
    final done = await _con.submitCancel();
    if (mounted && _con.message != null) toast(context, _con.message!, error: !done);
  }

  Future<void> _refund() async {
    final problem = _con.validateRefund();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    final ok = await _confirm('Save refund?', 'Refund Rs ${_con.refundTotal} to ${_con.refundStudent!['name']} by ${_con.paymentMode}.', 'Save refund');
    if (!ok) return;
    final done = await _con.submitRefund();
    if (mounted && _con.message != null) toast(context, _con.message!, error: !done);
  }

  @override
  Widget build(BuildContext context) {
    final cancelBar = _tab == 0 && _con.chosen.isNotEmpty;
    final refundBar = _tab == 1 && _con.refundStudent != null && _con.heads.isNotEmpty;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Fees Cancel/Refund' : widget.args.item.label,
      bottom: cancelBar
          ? formBar(label: 'Cancel ${_con.chosen.length} · Rs ${_con.chosenTotal}', busy: _con.busy, color: Brand.err, onPressed: _cancel)
          : refundBar
              ? formBar(label: 'Save refund · Rs ${_con.refundTotal}', busy: _con.busy, onPressed: _refund)
              : null,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Cancel receipts'), icon: Icon(Icons.cancel_presentation_outlined)),
            ButtonSegment(value: 1, label: Text('Refund'), icon: Icon(Icons.currency_rupee_rounded)),
          ],
          selected: {_tab},
          onSelectionChanged: (v) => setState(() => _tab = v.first),
        ),
        const SizedBox(height: 14),
        if (_con.message != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _con.messageIsError ? Brand.err0 : Brand.ok0, borderRadius: BorderRadius.circular(12)),
            child: Text(_con.message!, style: TextStyle(color: _con.messageIsError ? Brand.err : Brand.ok, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        if (_tab == 0) ..._cancelTab() else ..._refundTab(),
      ]),
    );
  }

  List<Widget> _cancelTab() => [
        SoftCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextInput(label: 'Enrollment (GR) no', controller: _con.enrollment),
            gap(),
            TextInput(label: 'Receipt no', controller: _con.receiptNo),
            gap(),
            Row(children: [
              Expanded(child: DateField(label: 'From date', value: _con.from, onChanged: _con.setFrom, last: DateTime.now())),
              const SizedBox(width: 10),
              Expanded(child: DateField(label: 'To date', value: _con.to, onChanged: _con.setTo, last: DateTime.now())),
            ]),
            gap(14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(onPressed: _con.busy ? null : _con.searchReceipts, icon: const Icon(Icons.search_rounded), label: Text(_con.busy ? 'Searching…' : 'Search receipts')),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (_con.busy) const LinearProgressIndicator(minHeight: 3),
        if (_con.searched && !_con.busy && _con.receipts.isEmpty && _con.message == null)
          Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('No receipts found.', style: TextStyle(color: Brand.muted)))),
        for (final r in _con.receipts) Padding(padding: const EdgeInsets.only(bottom: 10), child: _receiptCard(r)),
      ];

  Widget _receiptCard(CancelReceipt r) {
    final on = _con.selected.contains(r.key);
    final cls = [r.standard, r.division].where((e) => e.isNotEmpty).join(' - ');
    return Container(
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: on ? Brand.err : Brand.line, width: on ? 1.5 : 1),
        boxShadow: Brand.softShadow,
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: r.cancellable ? () => _con.toggle(r) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: on ? Brand.err : (r.cancellable ? Colors.white : Brand.field),
                  borderRadius: BorderRadius.circular(8),
                  border: on ? null : Border.all(color: Brand.border, width: 2),
                ),
                child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Tag.neutral('Receipt ${r.receiptNo}'),
                    if (cls.isNotEmpty) Tag(cls),
                    if (r.paymentMode.isNotEmpty) Tag.info(r.paymentMode),
                    if (r.feesType == 'OTHER') Tag.warn('Other fees'),
                  ]),
                  const SizedBox(height: 6),
                  Text('GR ${r.enrollmentNo}  ·  ${fmtDate(r.receiptDate)}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                  if (!r.cancellable)
                    Padding(padding: EdgeInsets.only(top: 6), child: Text('Paid via the online portal, so it cannot be cancelled here.', style: TextStyle(color: Brand.warn, fontSize: 12))),
                ]),
              ),
              Text('Rs ${r.totalAmount}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
        ),
        if (on && r.feesType == 'REGULAR')
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(children: [
              DropdownField(
                label: 'Cancel type',
                options: [for (final t in _con.cancelTypes) Opt(t, t)],
                value: _con.cancelType[r.key],
                onChanged: (v) => _con.pickType(r, v),
              ),
              gap(),
              TextInput(label: 'Cancel remark', controller: _con.remarkOf(r), lines: 2),
            ]),
          ),
      ]),
    );
  }

  List<Widget> _refundTab() => [
        SoftCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextInput(label: 'Enrollment (GR) no', controller: _con.refundEnrollment),
            gap(14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(onPressed: _con.busy ? null : _con.searchRefundStudent, icon: const Icon(Icons.search_rounded), label: const Text('Search student')),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        if (_con.busy) const LinearProgressIndicator(minHeight: 3),
        for (final st in _con.refundStudents)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KitCard(
              onTap: _con.busy ? null : () => _con.loadRefundDetail(st['student_id']!),
              child: Row(children: [
                PersonAvatar(url: '', name: st['name'] ?? '', radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('GR ${st['enrollment']}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: Brand.muted),
              ]),
            ),
          ),
        if (_con.refundStudent != null) ...[
          const SizedBox(height: 6),
          SectionLabel('Refund for ${_con.refundStudent!['name']}'),
          if (_con.heads.isEmpty) KitCard(child: Text('No paid fee heads to refund.', style: TextStyle(color: Brand.muted))),
          for (final h in _con.heads)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: h.amount,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: '${h.label}  (paid Rs ${h.paid})'),
              ),
            ),
          if (_con.heads.isNotEmpty) ...[
            gap(),
            DropdownField(
              label: 'Payment mode',
              options: [for (final p in FeesCancelRefundController.paymentModes) Opt(p, p)],
              value: _con.paymentMode,
              onChanged: _con.setPaymentMode,
            ),
            gap(),
            TextInput(label: 'Refund remark', controller: _con.refundRemark, lines: 2),
          ],
        ],
      ];
}
