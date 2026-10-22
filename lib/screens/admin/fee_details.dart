import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../../ui/design.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';

int _amount(dynamic v) => (num.tryParse(s(v)) ?? 0).round();

/// Pending installments (tick to pay), bank + transaction id, Pay Now; plus paid history.
class FeeDetailsScreen extends StatefulWidget {
  const FeeDetailsScreen({
    super.key,
    required this.args,
    required this.student,
  });
  final ScreenArgs args;
  final Map<String, dynamic> student;

  @override
  State<FeeDetailsScreen> createState() => _FeeDetailsScreenState();
}

class _FeeDetailsScreenState extends State<FeeDetailsScreen> with SubmitGuard {
  Map<String, dynamic> stuData = {};
  List<Map<String, dynamic>> pending = [], paid = [];
  final ticked = <int>{};
  final bank = TextEditingController();
  final txn = TextEditingController();
  bool loading = true;
  String? error;

  LegacyApi get api => widget.args.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    bank.dispose();
    txn.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final q = Uri(
        queryParameters: {
          'syear': syearOf(widget.args.session),
          'sub_institute_id': '${widget.args.session.subInstituteId}',
          'student_id': s(widget.student['id']),
        },
      ).query;
      final res = await api.post(
        '/studentFeesDetailAPI?$q',
        withIdentity: false,
      );
      if (!mounted) return;
      if (!submitOk(res)) {
        setState(
          () => error = LegacyApi.messageOf(res, 'Could not load fee details.'),
        );
        return;
      }
      final data = m(res['data']);
      setState(() {
        stuData = m(data['STU_DATA']);
        pending = rows(data['PENDING']);
        paid = rows(data['PAID']);
        ticked.clear();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int get total => ticked.fold(0, (a, i) => a + _amount(pending[i]['remain']));

  Future<void> _pay() async {
    if (missing(context, bank.text, 'Please enter the bank name.')) return;
    if (missing(context, txn.text, 'Please enter the transaction ID.')) return;
    if (total <= 0) {
      toast(context, 'Select at least one installment.', error: true);
      return;
    }
    await guarded(() async {
      final q = Uri(
        queryParameters: {
          'syear': syearOf(widget.args.session),
          'sub_institute_id': '${widget.args.session.subInstituteId}',
          'student_id': s(widget.student['id']),
          'amount': '$total',
          'bank_name': bank.text.trim(),
          'transactionid': txn.text.trim(),
          'fine': '0',
          'token': s(stuData['token']).isEmpty
              ? widget.args.session.token
              : s(stuData['token']),
        },
      ).query;
      final res = await api.post(
        '/fees/get_online_receipt?$q',
        withIdentity: false,
      );
      if (!mounted) return;
      if (!submitOk(res)) {
        toast(context, LegacyApi.messageOf(res), error: true);
        return;
      }
      final html = s(res['receipt_html']).isNotEmpty
          ? s(res['receipt_html'])
          : s(m(res['data'])['receipt_html']);
      toast(context, LegacyApi.messageOf(res, 'Payment recorded.'));
      if (html.isEmpty) {
        await _load();
        return;
      }
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(html: html)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.student;
    final cls = [
      s(st['standard_name']),
      s(st['division_name']),
    ].where((e) => e.isNotEmpty).join(' - ');
    return KitPage(
      title: 'Fees collect',
      bottom: loading || error != null || pending.isEmpty
          ? null
          : Row(children: [
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Grand total', style: TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w500, color: Brand.ink3)),
                Text('Rs $total', key: const Key('fee-total'), style: const TextStyle(fontSize: 18, height: 1.44, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: formBar(
                  label: ticked.isEmpty ? 'Pay now' : 'Pay now - Rs $total',
                  busy: busy,
                  onPressed: ticked.isEmpty ? null : _pay,
                ),
              ),
            ]),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? KitMessage(
              icon: Icons.cloud_off_outlined,
              text: error!,
              action: 'Try again',
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
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
                              style: const TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w500, color: Brand.ink3)),
                          if (s(st['mobile']).isNotEmpty)
                            Text(s(st['mobile']), style: const TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w500, color: Brand.ink3)),
                        ]),
                      ),
                      if (pending.isNotEmpty) Tag.err('Due Rs ${pending.fold<int>(0, (a, p) => a + _amount(p['remain']))}'),
                    ]),
                  ),
                  gap(16),
                  const SectionLabel('Pending installments'),
                  if (pending.isEmpty)
                    const KitCard(
                      child: Text(
                        'No pending fees. Everything is paid.',
                        style: TextStyle(color: Brand.muted),
                      ),
                    ),
                  if (pending.isNotEmpty)
                    SoftCard(
                      clip: true,
                      child: Column(children: [
                        for (var i = 0; i < pending.length; i++)
                          InkWell(
                            onTap: () => setState(() => ticked.contains(i) ? ticked.remove(i) : ticked.add(i)),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 60),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(border: i == pending.length - 1 ? null : const Border(bottom: BorderSide(color: Brand.line))),
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
                                Text('Rs ${_amount(pending[i]['remain'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  if (pending.isNotEmpty) ...[
                    gap(),
                    TextInput(label: 'Bank name', controller: bank),
                    gap(),
                    TextInput(label: 'Transaction ID', controller: txn),
                  ],
                  gap(20),
                  const SectionLabel('Payment history'),
                  if (paid.isEmpty)
                    const KitCard(
                      child: Text(
                        'No payments recorded yet.',
                        style: TextStyle(color: Brand.muted),
                      ),
                    ),
                  for (final p in paid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: KitCard(
                        onTap: s(p['fees_html']).isEmpty
                            ? null
                            : () => push(
                                context,
                                ReceiptScreen(html: s(p['fees_html'])),
                              ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Receipt #${s(p['receipt_no'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    [
                                      fmtDate(p['receiptdate']),
                                      s(p['payment_mode']),
                                      s(p['bank_name']),
                                    ].where((e) => e.isNotEmpty).join('  |  '),
                                    style: const TextStyle(
                                      color: Brand.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Rs ${_amount(p['paid_amount'])}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (s(p['fees_html']).isNotEmpty)
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Brand.muted,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Renders a fee receipt's HTML.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.html});
  final String html;

  @override
  Widget build(BuildContext context) => KitPage(
    title: 'Fees receipt',
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: ColoredBox(color: Colors.white, child: HtmlWidget(html)),
    ),
  );
}
