import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'report_common.dart';

class AgeClassCount {
  const AgeClassCount(this.className, this.boys, this.girls);
  final String className;
  final int boys;
  final int girls;
  int get total => boys + girls;
}

class AgeRow {
  AgeRow(this.label, this.classes);
  final String label;
  final List<AgeClassCount> classes;
  int get boys => classes.fold(0, (a, c) => a + c.boys);
  int get girls => classes.fold(0, (a, c) => a + c.girls);
  int get total => boys + girls;
}

/// State and API calls for the Age-wise Report: `GET /student/agewise` (optional grade / standard / division).
/// The answer is `report: {ageLabel: {className: {M, F}}}`.
class AgeWiseReportController extends ChangeNotifier {
  AgeWiseReportController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  bool loading = true;
  String? error;
  CascadeSelection cascade = CascadeSelection();
  List<AgeRow> ages = [];

  int get total => ages.fold(0, (a, r) => a + r.total);
  int get boys => ages.fold(0, (a, r) => a + r.boys);
  int get girls => ages.fold(0, (a, r) => a + r.girls);

  /// The same counts regrouped by class (ages added up).
  List<AgeClassCount> get byClass {
    final boys = <String, int>{};
    final girls = <String, int>{};
    final order = <String>[];
    for (final a in ages) {
      for (final c in a.classes) {
        if (!boys.containsKey(c.className)) order.add(c.className);
        boys[c.className] = (boys[c.className] ?? 0) + c.boys;
        girls[c.className] = (girls[c.className] ?? 0) + c.girls;
      }
    }
    return [for (final k in order) AgeClassCount(k, boys[k] ?? 0, girls[k] ?? 0)];
  }

  static String ageTitle(String key) {
    if (key.startsWith('≤')) return '${key.substring(1)} & under';
    if (key.endsWith('+')) return '${key.substring(0, key.length - 1)} & above';
    return 'Age $key';
  }

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get('/student/agewise', query: {
        if (cascade.sectionId != null) 'grade': cascade.sectionId,
        if (cascade.standardId != null) 'standard': cascade.standardId,
        if (cascade.divisionId != null) 'division': cascade.divisionId,
      });
      final report = res['report'];
      if (report is! Map && report is! List) throw ApiException(LegacyApi.messageOf(res, "Couldn't load the report. Try again."));
      final out = <AgeRow>[];
      if (report is Map) {
        for (final a in report.entries) {
          final classes = <AgeClassCount>[];
          for (final c in m(a.value).entries) {
            final mf = m(c.value);
            final b = toInt(mf['M']);
            final g = toInt(mf['F']);
            if (b + g > 0) classes.add(AgeClassCount(c.key, b, g));
          }
          if (classes.isNotEmpty) out.add(AgeRow('${a.key}', classes));
        }
      }
      ages = out;
    } on ApiException catch (e) {
      error = e.message;
      ages = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

/// Age-wise Report: how many boys and girls of each age, by age or by class.
class AgeWiseReportScreen extends StatefulWidget {
  const AgeWiseReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AgeWiseReportScreen> createState() => _AgeWiseReportScreenState();
}

class _AgeWiseReportScreenState extends State<AgeWiseReportScreen> {
  late final AgeWiseReportController _con = AgeWiseReportController(args: widget.args)..addListener(_onChange);
  bool _byClass = false;
  bool _showFilter = false;
  final Set<String> _open = {};

  @override
  void initState() {
    super.initState();
    _con.load();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _con;
    final maxAge = c.ages.fold<int>(0, (a, r) => r.total > a ? r.total : a);
    final byClass = c.byClass;
    final maxClass = byClass.fold<int>(0, (a, r) => r.total > a ? r.total : a);
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Age-wise Report' : widget.args.item.label,
      child: withStudentInputs(
        context,
        ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          NavyStats(
            stats: [('Students', c.loading ? '–' : '${c.total}'), ('Boys', c.loading ? '–' : '${c.boys}'), ('Girls', c.loading ? '–' : '${c.girls}')],
            caption: 'Counted from each student\'s date of birth, today.',
          ),
          gap(14),
          _filterCard(c),
          gap(12),
          if (c.loading) const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
          if (c.error != null) Notice(c.error!, kind: NoticeKind.error),
          if (!c.loading && c.error == null && c.ages.isEmpty) const KitMessage(icon: Icons.bar_chart_rounded, text: 'No students with a date of birth and gender were found.'),
          if (c.ages.isNotEmpty) ...[
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('By age'), icon: Icon(Icons.cake_outlined, size: 18)), ButtonSegment(value: true, label: Text('By class'), icon: Icon(Icons.class_outlined, size: 18))],
              selected: {_byClass},
              onSelectionChanged: (v) => setState(() => _byClass = v.first),
            ),
            gap(12),
            if (!_byClass)
              for (final a in c.ages) _ageCard(a, maxAge)
            else
              for (final k in byClass) _classCard(k, maxClass),
          ],
        ]),
      ),
    );
  }

  Widget _filterCard(AgeWiseReportController c) => SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => _showFilter = !_showFilter),
            child: Row(children: [
              const IconTile(Icons.filter_list_rounded, size: 30),
              const SizedBox(width: 10),
              const Expanded(child: Text('Filter by class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
              Icon(_showFilter ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.muted),
            ]),
          ),
          if (_showFilter) ...[
            gap(12),
            CascadeFilter(api: widget.args.api, onChanged: c.setCascade),
            gap(12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                onPressed: c.loading ? null : c.load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Show report'),
              ),
            ),
          ],
        ]),
      );

  Widget _ageCard(AgeRow a, int max) {
    final open = _open.contains(a.label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line), boxShadow: Brand.softShadow),
        child: Column(children: [
          InkWell(
            onTap: () => setState(() => open ? _open.remove(a.label) : _open.add(a.label)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(AgeWiseReportController.ageTitle(a.label), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  Text('${a.total}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Brand.primaryDark)),
                  const SizedBox(width: 4),
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.ink3),
                ]),
                const SizedBox(height: 8),
                MiniBar(value: a.total, max: max),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [countChip('Boys', a.boys, Brand.info, Brand.info0), countChip('Girls', a.girls, const Color(0xFFBE185D), const Color(0xFFFCE7F3))]),
              ]),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: const BoxDecoration(color: Brand.surface, border: Border(top: BorderSide(color: Brand.line))),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in a.classes) _classPill(k),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _classPill(AgeClassCount k) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Brand.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(k.className, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(width: 8),
          Text('M ${k.boys}', style: const TextStyle(color: Brand.info, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('F ${k.girls}', style: const TextStyle(color: Color(0xFFBE185D), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _classCard(AgeClassCount k, int max) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(k.className, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Text('${k.total}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Brand.primaryDark)),
            ]),
            const SizedBox(height: 8),
            MiniBar(value: k.total, max: max),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [countChip('Boys', k.boys, Brand.info, Brand.info0), countChip('Girls', k.girls, const Color(0xFFBE185D), const Color(0xFFFCE7F3))]),
          ]),
        ),
      );
}
