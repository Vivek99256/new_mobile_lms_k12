import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/design.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import '../../presentation/admin/fees_collect/fees_details/fees_collect_details_screen.dart';
import 'admin_common.dart';

/// Fees Defaulter Report: who owes money, largest balance first, with a total, a search box
/// and a one-tap call. Data: POST /api/fees-dashboard/defaulters (already reshaped for this).
class FeesDefaultersScreen extends StatefulWidget {
  const FeesDefaultersScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<FeesDefaultersScreen> createState() => _FeesDefaultersScreenState();
}

class _FeesDefaultersScreenState extends State<FeesDefaultersScreen> {
  List<Map<String, dynamic>> _all = [];
  String _query = '';
  bool _loading = false;
  bool _searched = false;
  String? _error;
  CascadeSelection _cascade = CascadeSelection();

  /// The server works out every student's fees one by one, so a whole school (thousands of students) takes minutes.
  /// A class (about 40 students) is quick, so the report asks for one.
  Future<void> _load() async {
    if (_cascade.sectionId == null || _cascade.standardId == null) {
      toast(context, 'Please select a section and a standard.', error: true);
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _all = [];
    });
    try {
      final res = await widget.args.api.post('/api/fees-dashboard/defaulters', body: {
        'grade': _cascade.sectionId,
        'standard': _cascade.standardId,
        if (_cascade.divisionId != null) 'division': _cascade.divisionId,
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      _all = rows(res['rows']);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the defaulter list. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _shown {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where((r) => '${s(r['student_name'])} ${s(r['standard_division'])} ${s(r['mobile'])}'.toLowerCase().contains(q))
        .toList();
  }

  String _money(num v) {
    final n = v.round().toString();
    // Indian grouping: 12,34,567
    if (n.length <= 3) return '₹$n';
    final head = n.substring(0, n.length - 3);
    final tail = n.substring(n.length - 3);
    final g = head.replaceAllMapped(RegExp(r'(\d)(?=(\d\d)+$)'), (m) => '${m[1]},');
    return '₹$g,$tail';
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final total = _all.fold<num>(0, (a, r) => a + (num.tryParse(s(r['outstanding_amount'])) ?? 0));

    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Fees Defaulter Report' : widget.args.item.label,
      child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      SoftCard(
                        radius: 20,
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Choose class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 4),
                          const Text('Pick a class to see who owes fees. (A whole school takes too long to calculate.)', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                          const SizedBox(height: 12),
                          CascadeFilter(api: widget.args.api, onChanged: (c) => _cascade = c),
                          gap(10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.search_rounded), label: Text(_loading ? 'Calculating…' : 'Show defaulters')),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      if (_loading) const LinearProgressIndicator(minHeight: 3),
                      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: const TextStyle(color: Brand.err, fontWeight: FontWeight.w600))),
                      if (_searched && !_loading && _error == null) ...[
                      _Summary(total: _money(total), count: _all.length),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search name, class or mobile',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (shown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(child: Text('No defaulters found.', style: TextStyle(color: Brand.muted))),
                        ),
                      for (var i = 0; i < shown.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DefaulterCard(
                            // Tap a defaulter to collect their fees (needs the student id from the server).
                            onTap: s(shown[i]['student_id']).isEmpty
                                ? null
                                : () => push(
                                      context,
                                      FeesCollectDetailsScreen(args: widget.args, student: {
                                        'id': shown[i]['student_id'],
                                        'student_name': shown[i]['student_name'],
                                        'standard_name': shown[i]['standard_division'],
                                        'mobile': shown[i]['mobile'],
                                      }),
                                    ),
                            rank: _all.indexOf(shown[i]) + 1,
                            name: s(shown[i]['student_name']),
                            klass: s(shown[i]['standard_division']),
                            mobile: s(shown[i]['mobile']),
                            amount: s(shown[i]['outstanding_display']).isNotEmpty
                                ? s(shown[i]['outstanding_display'])
                                : _money(num.tryParse(s(shown[i]['outstanding_amount'])) ?? 0),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.count});
  final String total;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: Brand.softShadow,
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total outstanding', style: TextStyle(color: Brand.champagne, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(total, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('$count', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const Text('students', style: TextStyle(color: Brand.champagne, fontSize: 11.5)),
            ]),
          ),
        ]),
      );
}

class _DefaulterCard extends StatelessWidget {
  const _DefaulterCard({required this.rank, required this.name, required this.klass, required this.mobile, required this.amount, this.onTap});
  final int rank;
  final String name, klass, mobile, amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => KitCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          PersonAvatar(url: '', name: name, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (klass.isNotEmpty) Pill(klass),
                if (mobile.isNotEmpty) Pill(mobile, color: Brand.info),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Brand.err0, borderRadius: BorderRadius.circular(10)),
            child: Text(amount, style: const TextStyle(color: Brand.err, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ]),
      );
}
