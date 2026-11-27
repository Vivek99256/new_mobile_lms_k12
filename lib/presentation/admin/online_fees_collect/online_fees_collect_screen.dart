import 'package:flutter/material.dart';

import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'online_fees_collect_controller.dart';

/// Online Fees Collect: explains the 3 steps and opens the web payment flow with "Pay Now".
class OnlineFeesCollectScreen extends StatefulWidget {
  const OnlineFeesCollectScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<OnlineFeesCollectScreen> createState() => _OnlineFeesCollectScreenState();
}

class _OnlineFeesCollectScreenState extends State<OnlineFeesCollectScreen> {
  late final OnlineFeesCollectController _con = OnlineFeesCollectController(args: widget.args)..addListener(_onChange);

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  static const _steps = <(IconData, String, String)>[
    (Icons.phone_iphone_rounded, 'Enter mobile number', "The parent's registered mobile number. No login needed."),
    (Icons.people_alt_rounded, 'Select the student', 'Pick the child whose fees are being paid.'),
    (Icons.lock_rounded, 'Pay securely', 'Continue to the school\'s payment gateway.'),
  ];

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? 'Online Fees Collect' : widget.args.item.label,
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_con.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_con.error!, textAlign: TextAlign.center, style: TextStyle(color: Brand.err, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _con.busy ? null : _con.payNow,
              icon: _con.busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payments_rounded),
              label: Text(_con.busy ? 'Opening…' : 'Pay Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Rise(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Collect fees online', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Opens the school payment page. No login needed.', style: TextStyle(color: Brand.champagne, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          const Text('How it works', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          for (var i = 0; i < _steps.length; i++)
            Rise(
              delay: Duration(milliseconds: 80 * (i + 1)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    IconTile(_steps[i].$1, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${i + 1}. ${_steps[i].$2}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text(_steps[i].$3, style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Send this link to parents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 4),
              Text('Parents open it, enter their mobile number and pay. No account or login is needed.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Brand.line)),
                child: Text(_con.payLink, style: TextStyle(color: Brand.primaryDark, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await _con.copyLink();
                  if (context.mounted) toast(context, 'Link copied.');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy link'),
              ),
            ]),
          ),
        ]),
      );
}
