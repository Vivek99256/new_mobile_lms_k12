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
import '../../../ui/app_loader.dart';

class StrengthRow {
  const StrengthRow(this.standard, this.division, this.total, this.boys, this.girls);
  final String standard;
  final String division;
  final int total;
  final int boys;
  final int girls;
  int get other => total - boys - girls;
  String get title => division.isEmpty ? standard : '$standard · $division';
}

/// State and API calls for the Student Strength Report: `GET /student/student_strength_report/create`
/// with `strength[]` = M, F and (for division-wise) `standard_wise[]` = division.
class StrengthReportController extends ChangeNotifier {
  StrengthReportController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  bool loading = true;
  bool divisionWise = false;
  String? error;
  List<StrengthRow> items = [];

  int get total => items.fold(0, (a, r) => a + r.total);
  int get boys => items.fold(0, (a, r) => a + r.boys);
  int get girls => items.fold(0, (a, r) => a + r.girls);

  void setDivisionWise(bool v) {
    if (divisionWise == v) return;
    divisionWise = v;
    load();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get('/student/student_strength_report/create', query: {
        'strength[0]': 'M',
        'strength[1]': 'F',
        if (divisionWise) 'standard_wise[0]': 'division',
      });
      if (statusOf(res) != '1' || res['result'] is! List) throw ApiException(LegacyApi.messageOf(res, "Couldn't load the report. Try again."));
      items = [
        for (final r in rows(res['result']))
          StrengthRow(s(r['standard_name']), divisionWise ? s(r['division_name']) : '', toInt(r['total_students']), toInt(r['M']), toInt(r['F'])),
      ];
    } on ApiException catch (e) {
      error = e.message;
      items = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

/// Student Strength Report: students per standard (or per division), split into boys and girls.
class StrengthReportScreen extends StatefulWidget {
  const StrengthReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StrengthReportScreen> createState() => _StrengthReportScreenState();
}

class _StrengthReportScreenState extends State<StrengthReportScreen> {
  late final StrengthReportController _con = StrengthReportController(args: widget.args)..addListener(_onChange);

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
    final max = c.items.fold<int>(0, (a, r) => r.total > a ? r.total : a);
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Student Strength Report' : widget.args.item.label,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        NavyStats(
          stats: [('Students', c.loading ? '–' : '${c.total}'), ('Boys', c.loading ? '–' : '${c.boys}'), ('Girls', c.loading ? '–' : '${c.girls}')],
          caption: 'Students enrolled this year, by ${c.divisionWise ? 'division' : 'standard'}.',
        ),
        gap(14),
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Standard-wise'), icon: Icon(Icons.stairs_outlined, size: 18)), ButtonSegment(value: true, label: Text('Division-wise'), icon: Icon(Icons.grid_view_rounded, size: 18))],
          selected: {c.divisionWise},
          onSelectionChanged: c.loading ? null : (v) => c.setDivisionWise(v.first),
        ),
        gap(14),
        if (c.loading) const Padding(padding: EdgeInsets.only(top: 24), child: const AppLoader()),
        if (c.error != null) ...[Notice(c.error!, kind: NoticeKind.error), gap(8), Center(child: TextButton(onPressed: c.load, child: const Text('Try again')))],
        if (!c.loading && c.error == null && c.items.isEmpty) const KitMessage(icon: Icons.groups_outlined, text: 'No students are enrolled yet.'),
        for (final r in c.items) _card(r, max),
      ]),
    );
  }

  Widget _card(StrengthRow r, int max) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconTile(Icons.groups_2_outlined, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Text('${r.total}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Brand.primaryDark)),
            ]),
            const SizedBox(height: 10),
            MiniBar(value: r.total, max: max),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              countChip('Boys', r.boys, Brand.info, Brand.info0),
              countChip('Girls', r.girls, const Color(0xFFBE185D), const Color(0xFFFCE7F3)),
              if (r.other > 0) countChip('Other', r.other, Brand.ink2, Brand.surface),
            ]),
          ]),
        ),
      );
}
