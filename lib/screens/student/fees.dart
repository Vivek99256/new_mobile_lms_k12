import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'student_common.dart';

/// Pending and paid fees with a receipt viewer.
class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  bool _paid = false;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pending = [], _paidRows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Sx.call(widget.args, '/studentFeesDetailAPI');
      if (!mounted) return;
      if (!LegacyApi.ok(res)) {
        _error = LegacyApi.messageOf(res);
      } else {
        final d = m(res['data']);
        _pending = rows(d['PENDING']);
        _paidRows = rows(d['PAID']);
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = _paid
        ? _paidRows.fold<num>(0, (a, r) => a + numOf(r['paid_amount']))
        : _pending.fold<num>(0, (a, r) => a + numOf(r['remain']));
    final list = _paid ? _paidRows : _pending;
    return KitPage(
      title: titleOf(widget.args, 'Fees'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [ButtonSegment(value: false, label: Text('Pending fees')), ButtonSegment(value: true, label: Text('Paid fees'))],
                      selected: {_paid},
                      onSelectionChanged: (v) => setState(() => _paid = v.first),
                    ),
                    const SizedBox(height: 14),
                    KitCard(
                      child: Column(children: [
                        Text(_paid ? 'Total paid fees' : 'Total pending fees', style: const TextStyle(color: Brand.muted)),
                        const SizedBox(height: 4),
                        Text(indian(total), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _paid ? const Color(0xFF16A34A) : const Color(0xFFE11D48))),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    const Text('Fees summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    if (list.isEmpty)
                      KitMessage(icon: Icons.receipt_long_outlined, text: _paid ? 'No payments have been recorded yet.' : 'You have no pending fees.'),
                    for (final r in list)
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: _paid ? _paidCard(r) : _pendingCard(r)),
                  ]),
                ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> r) {
    final pay = s(r['PayNow']);
    return KitCard(
      child: Row(children: [
        Expanded(child: Text(s(r['month']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        Text(indian(numOf(r['remain'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        if (pay.isNotEmpty) ...[
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44), backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => openUrl(context, pay),
            child: const Text('Pay now'),
          ),
        ],
      ]),
    );
  }

  Widget _paidCard(Map<String, dynamic> r) {
    String blank(String v) => v.isEmpty ? '--' : v;
    return KitCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment: Alignment.centerRight, child: Text(indian(numOf(r['paid_amount'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF16A34A)))),
        KV('Receipt no', s(r['receipt_no'])),
        KV('Payment date', fmtDate(r['receiptdate'], out: 'dd/MM/yyyy')),
        KV('Payment mode', s(r['payment_mode'])),
        KV('Bank name', s(r['bank_name'])),
        KV('Bank branch', s(r['bank_branch'])),
        KV('Cheque / DD no', blank(s(r['cheque_no']))),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), foregroundColor: const Color(0xFF16A34A)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(args: widget.args, receipt: r))),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View receipt'),
        ),
      ]),
    );
  }
}

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.args, required this.receipt});
  final ScreenArgs args;
  final Map<String, dynamic> receipt;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _busy = false;

  /// The server answers with a bare PDF URL (not JSON), so this bypasses [LegacyApi].
  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final a = widget.args;
      final uri = Uri.parse('${AppConfig.apiBase}/ajax_PDF_FeesReceipt').replace(queryParameters: {
        ...a.api.identity,
        'action': 'fees_collect_receipt',
        'receipt_id_html': s(widget.receipt['receipt_no']),
      });
      final res = await http.get(uri, headers: {'Authorization': 'Bearer ${a.session.token}'}).timeout(const Duration(seconds: 45));
      final body = res.body.trim().replaceAll('"', '').replaceAll(r'\/', '/');
      if (!mounted) return;
      if (res.statusCode == 200 && body.startsWith('http')) {
        await openUrl(context, body);
      } else {
        toast(context, 'The receipt PDF is not available right now.', error: true);
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not download the receipt. Check your connection.', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final html = s(widget.receipt['fees_html']);
    return KitPage(
      title: 'Receipt',
      actions: [
        _busy
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            : IconButton(tooltip: 'Download PDF', icon: const Icon(Icons.download_rounded, color: Colors.white), onPressed: _download),
      ],
      child: html.isEmpty
          ? const KitMessage(icon: Icons.receipt_long_outlined, text: 'No receipt details were found.')
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: KitCard(child: HtmlBlock(html))),
    );
  }
}
