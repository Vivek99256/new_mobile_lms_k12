import 'package:flutter/material.dart';

import '../../../../screens/admin/admin_common.dart';
import '../../../../screens/kit/kit.dart';
import '../../../../screens/screen_registry.dart';
import '../../../../ui/design.dart';
import '../../../../ui/theme.dart';
import 'fees_collect_details_controller.dart';
import 'online_receipt_view.dart';
import '../../../../ui/app_loader.dart';

/// Pending installments (tick to pay), bank + transaction id, Pay Now; plus paid history.
class FeesCollectDetailsScreen extends StatefulWidget {
  const FeesCollectDetailsScreen({super.key, required this.args, required this.student});
  final ScreenArgs args;
  final Map<String, dynamic> student;

  @override
  State<FeesCollectDetailsScreen> createState() => _FeesCollectDetailsScreenState();
}

class _FeesCollectDetailsScreenState extends State<FeesCollectDetailsScreen> with SubmitGuard {
  late final FeesCollectDetailsController _con =
      FeesCollectDetailsController(args: widget.args, studentInfo: widget.student)..addListener(_onChange);

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.callService();
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final problem = _con.validate();
    if (problem != null) {
      toast(context, problem, error: true);
      return;
    }
    await guarded(() async {
      final r = await _con.callServicePayNow();
      if (!mounted) return;
      toast(context, r.message, error: !r.ok);
      if (!r.ok) return;
      if (r.receiptHtml.isEmpty) {
        await _con.callService();
        return;
      }
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnlineReceiptView(html: r.receiptHtml)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.student;
    final cls = [s(st['standard_name']), s(st['division_name'])].where((e) => e.isNotEmpty).join(' - ');
    final pending = _con.pending;
    final ticked = _con.ticked;
    return KitPage(
      title: 'Fees collect',
      bottom: _con.isLoading || _con.error != null || pending.isEmpty
          ? null
          : Row(children: [
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Grand total', style: TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w500, color: Brand.ink3)),
                Text('Rs ${_con.totalRemain}',
                    key: const Key('fee-total'),
                    style: const TextStyle(fontSize: 18, height: 1.44, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: formBar(
                  label: ticked.isEmpty ? 'Pay now' : 'Pay now - Rs ${_con.totalRemain}',
                  busy: busy,
                  onPressed: ticked.isEmpty ? null : _pay,
                ),
              ),
            ]),
      child: _con.isLoading
          ? const AppLoader()
          : _con.error != null
              ? KitMessage(icon: Icons.cloud_off_outlined, text: _con.error!, action: 'Try again', onAction: _con.callService)
              : RefreshIndicator(
                  onRefresh: _con.callService,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SoftCard(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(children: [
                          PersonAvatar(url: s(st['student_image']), name: s(st['student_name']), radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s(st['student_name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('GR no. ${s(st['enrollment_no'])} · $cls · Roll ${s(st['roll_no'])}',
                                  style: TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w500, color: Brand.ink3)),
                              if (s(st['mobile']).isNotEmpty)
                                Text(s(st['mobile']), style: TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w500, color: Brand.ink3)),
                            ]),
                          ),
                          if (pending.isNotEmpty) Tag.err('Due Rs ${_con.totalDue}'),
                        ]),
                      ),
                      gap(16),
                      const SectionLabel('Pending installments'),
                      if (pending.isEmpty)
                        KitCard(child: Text('No pending fees. Everything is paid.', style: TextStyle(color: Brand.muted))),
                      if (pending.isNotEmpty)
                        SoftCard(
                          clip: true,
                          child: Column(children: [
                            for (var i = 0; i < pending.length; i++)
                              InkWell(
                                onTap: () => _con.toggle(i),
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 60),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(border: i == pending.length - 1 ? null : Border(bottom: BorderSide(color: Brand.line))),
                                  child: Row(children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: ticked.contains(i) ? Brand.primary : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: ticked.contains(i) ? null : Border.all(color: Brand.border, width: 2),
                                      ),
                                      child: ticked.contains(i) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        s(pending[i]['month']).isEmpty ? s(pending[i]['month_this']) : s(pending[i]['month']),
                                        style: TextStyle(fontWeight: FontWeight.w600, color: ticked.contains(i) ? Brand.ink : Brand.ink2),
                                      ),
                                    ),
                                    Text('Rs ${_con.amountOf(pending[i]['remain'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ),
                          ]),
                        ),
                      if (pending.isNotEmpty) ...[
                        gap(),
                        TextInput(label: 'Bank name', controller: _con.bankName),
                        gap(),
                        TextInput(label: 'Transaction ID', controller: _con.transactionID),
                      ],
                      gap(20),
                      const SectionLabel('Payment history'),
                      if (_con.paid.isEmpty) KitCard(child: Text('No payments recorded yet.', style: TextStyle(color: Brand.muted))),
                      for (final p in _con.paid)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: KitCard(
                            onTap: s(p['fees_html']).isEmpty ? null : () => push(context, OnlineReceiptView(html: s(p['fees_html']))),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Receipt #${s(p['receipt_no'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    [fmtDate(p['receiptdate']), s(p['payment_mode']), s(p['bank_name'])].where((e) => e.isNotEmpty).join('  |  '),
                                    style: TextStyle(color: Brand.muted, fontSize: 12.5),
                                  ),
                                ]),
                              ),
                              Text('Rs ${_con.amountOf(p['paid_amount'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              if (s(p['fees_html']).isNotEmpty) Icon(Icons.chevron_right_rounded, color: Brand.muted),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
