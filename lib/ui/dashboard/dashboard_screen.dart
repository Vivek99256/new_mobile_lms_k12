import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/auth_controller.dart';
import '../../core/dashboard_cache.dart';
import '../../core/page_service.dart';
import '../native_screens.dart' show displayValue, formatIndian;
import '../theme.dart';

Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _rows(dynamic v) => v is List
    ? [
        for (final r in v)
          if (r is Map) Map<String, dynamic>.from(r),
      ]
    : const [];
num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

enum DashboardRole { admin, teacher, student }

DashboardRole roleOf(String profileName) {
  final p = profileName.trim().toLowerCase();
  if (p == 'student') return DashboardRole.student;
  if (p == 'teacher') return DashboardRole.teacher;
  return DashboardRole.admin;
}

/// Role dashboard. Paints from the last saved payload immediately, then refreshes it, so
/// opening the screen never waits on the network once it has been seen once.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  DateTime? _updated;
  String? _error;
  bool _refreshing = false;

  late final AuthController _auth = context.read<AuthController>();
  late final DashboardRole _role = roleOf(_auth.session?.userProfileName ?? '');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = _auth.session;
    if (s == null) return;
    final cached = await DashboardCache.read(s.userId, _role.name);
    if (cached != null && mounted) {
      setState(() {
        _data = cached.data;
        _updated = cached.savedAt;
      });
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final s = _auth.session;
    if (s == null || _refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final svc = PageService(_auth.api, s);
      final res = await svc.callAuto(svc.dashboardEndpoint);
      await DashboardCache.write(s.userId, _role.name, res);
      if (mounted) {
        setState(() {
          _data = res;
          _updated = DateTime.now();
        });
      }
    } on ApiException catch (e) {
      // Keep showing cached data if we have it; only a first-ever load surfaces the error.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String get _agoText {
    final u = _updated;
    if (u == null) return '';
    final d = DateTime.now().difference(u);
    if (d.inMinutes < 1) return 'Updated just now';
    if (d.inMinutes < 60) return 'Updated ${d.inMinutes} min ago';
    if (d.inHours < 24) return 'Updated ${d.inHours} h ago';
    return 'Updated ${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final session = _auth.session;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 100,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: HeroHeader(
                bottomRadius: 20,
                padding: EdgeInsets.fromLTRB(
                  8,
                  MediaQuery.paddingOf(context).top + 8,
                  20,
                  22,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (_role) {
                              DashboardRole.admin => 'School overview',
                              DashboardRole.teacher => 'Teaching overview',
                              DashboardRole.student => 'My learning',
                            },
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _refreshing && data != null
                                ? 'Refreshing…'
                                : (_agoText.isEmpty
                                      ? (session?.schoolName ?? '')
                                      : _agoText),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_refreshing)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (data == null && _error == null)
              const SliverToBoxAdapter(child: _Skeleton())
            else if (data == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 40,
                          color: Brand.muted,
                        ),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(140, 44),
                          ),
                          onPressed: _refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                sliver: SliverList.list(
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3DC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 16,
                              color: Color(0xFFB45309),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Showing your last saved data. Pull down to retry.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ..._sections(data),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(Map<String, dynamic> d) {
    final summary = _m(d['summary']);
    return switch (_role) {
      DashboardRole.admin => [
        _Kpis(summary: summary, spec: _adminKpis),
        _Section(
          'Fees collected · last 7 days',
          child: _TrendBars(rows: _rows(d['fee_collection_trend'])),
        ),
        _Section(
          'Students by class',
          child: _HBars(
            rows: _rows(d['students_by_class']),
            labelKey: 'standard_name',
            valueKey: 'students',
          ),
        ),
        _Section(
          'Recent fee receipts',
          child: _ReceiptList(rows: _rows(d['recent_fee_receipts'])),
        ),
        _Section(
          'Birthdays this week',
          child: _Birthdays(rows: _rows(d['upcoming_birthdays'])),
        ),
      ],
      DashboardRole.teacher => [
        _Kpis(summary: summary, spec: _teacherKpis),
        _Section(
          'My classes',
          child: _Chips(
            items: [
              for (final c in _rows(d['my_classes']))
                '${_s(c['standard_name'])} - ${_s(c['division_name'])}',
            ],
          ),
        ),
        _Section(
          'Students by class',
          child: _HBars(
            rows: _rows(d['students_by_class']),
            labelKey: 'label',
            valueKey: 'students',
          ),
        ),
        _Section(
          'Assignments to grade',
          child: _SimpleList(
            rows: _rows(d['assignments_to_grade']),
            titleKey: 'title',
            subKey: 'student_submitted_date',
            subPrefix: 'Submitted ',
            icon: Icons.assignment_turned_in_outlined,
          ),
        ),
        _Section(
          'Recent circulars',
          child: _SimpleList(
            rows: _rows(d['recent_circulars']),
            titleKey: 'title',
            subKey: 'date_',
            icon: Icons.campaign_outlined,
          ),
        ),
        _Section(
          'My subjects',
          child: _Chips(
            items: [
              for (final c in _rows(d['my_subjects'])) _s(c['subject_name']),
            ],
          ),
        ),
      ],
      DashboardRole.student => [
        _EnrollmentCard(row: _m(d['enrollment'])),
        _Kpis(summary: summary, spec: _studentKpis),
        _Section(
          'Task status',
          child: _TaskStatus(rows: _rows(d['task_status'])),
        ),
        _Section(
          'Pending homework',
          child: _SimpleList(
            rows: _rows(d['pending_homework']),
            titleKey: 'title',
            subKey: 'submission_date',
            subPrefix: 'Due ',
            icon: Icons.edit_note_outlined,
          ),
        ),
        _Section(
          'Pending assignments',
          child: _SimpleList(
            rows: _rows(d['pending_assignments']),
            titleKey: 'title',
            subKey: 'submission_date',
            subPrefix: 'Due ',
            icon: Icons.assignment_outlined,
          ),
        ),
        _Section(
          'Recent circulars',
          child: _SimpleList(
            rows: _rows(d['recent_circulars']),
            titleKey: 'title',
            subKey: 'date_',
            icon: Icons.campaign_outlined,
          ),
        ),
        _Section(
          'My subjects',
          child: _Chips(
            items: [
              for (final c in _rows(d['my_subjects'])) _s(c['subject_name']),
            ],
          ),
        ),
      ],
    };
  }
}

// ---- KPI grid -----------------------------------------------------------------------------

typedef _Kpi = ({String key, String label, IconData icon, bool money});

const List<_Kpi> _adminKpis = [
  (
    key: 'total_students',
    label: 'Students',
    icon: Icons.groups_rounded,
    money: false,
  ),
  (key: 'total_staff', label: 'Staff', icon: Icons.badge_rounded, money: false),
  (
    key: 'total_classes',
    label: 'Classes',
    icon: Icons.class_rounded,
    money: false,
  ),
  (
    key: 'fees_collected_today',
    label: 'Fees today',
    icon: Icons.payments_rounded,
    money: true,
  ),
  (
    key: 'admissions_this_year',
    label: 'Admission enquiries',
    icon: Icons.person_add_alt_1_rounded,
    money: false,
  ),
  (
    key: 'homework_today',
    label: 'Homework today',
    icon: Icons.edit_note_rounded,
    money: false,
  ),
  (
    key: 'circulars_today',
    label: 'Circulars today',
    icon: Icons.campaign_rounded,
    money: false,
  ),
  (
    key: 'pending_parent_communications',
    label: 'Awaiting reply',
    icon: Icons.mark_email_unread_rounded,
    money: false,
  ),
];

const List<_Kpi> _teacherKpis = [
  (
    key: 'total_classes',
    label: 'My classes',
    icon: Icons.class_rounded,
    money: false,
  ),
  (
    key: 'total_students',
    label: 'My students',
    icon: Icons.groups_rounded,
    money: false,
  ),
  (
    key: 'total_subjects',
    label: 'Subjects',
    icon: Icons.menu_book_rounded,
    money: false,
  ),
  (
    key: 'homework_to_review',
    label: 'Homework to review',
    icon: Icons.edit_note_rounded,
    money: false,
  ),
  (
    key: 'assignments_to_grade',
    label: 'To grade',
    icon: Icons.assignment_turned_in_rounded,
    money: false,
  ),
];

const List<_Kpi> _studentKpis = [
  (
    key: 'total_subjects',
    label: 'Subjects',
    icon: Icons.menu_book_rounded,
    money: false,
  ),
  (
    key: 'pending_homework',
    label: 'Pending homework',
    icon: Icons.edit_note_rounded,
    money: false,
  ),
  (
    key: 'pending_assignments',
    label: 'Pending assignments',
    icon: Icons.assignment_rounded,
    money: false,
  ),
];

class _Kpis extends StatelessWidget {
  const _Kpis({required this.summary, required this.spec});
  final Map<String, dynamic> summary;
  final List<_Kpi> spec;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final k in spec)
        if (summary.containsKey(k.key)) k,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: shown.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
        ),
        itemBuilder: (_, i) {
          final k = shown[i];
          final v = _n(summary[k.key]);
          final accent = Brand.accent(i);
          return RepaintBoundary(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: Brand.softShadow,
              ),
              child: Row(
                children: [
                  IconBubble(icon: k.icon, accent: accent, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            k.money
                                ? '₹${formatIndian(v, decimals: v % 1 == 0 ? 0 : 2)}'
                                : formatIndian(v),
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Brand.text,
                            ),
                          ),
                        ),
                        Text(
                          k.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Brand.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---- sections & charts ----------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: Brand.text,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: Brand.softShadow,
    ),
    child: child,
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => _Card(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(color: Brand.muted, fontSize: 13),
        ),
      ),
    ),
  );
}

/// 7-day bar chart. No chart package: seven animated columns.
class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('No collections yet.');
    final max = rows
        .map((r) => _n(r['amount']))
        .fold<num>(0, (a, b) => a > b ? a : b);
    final total = rows.fold<num>(0, (a, r) => a + _n(r['amount']));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '₹${formatIndian(total)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const Text(
            'collected in the last 7 days',
            style: TextStyle(color: Brand.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < rows.length; i++)
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: max == 0
                            ? 0
                            : (_n(rows[i]['amount']) / max).toDouble(),
                      ),
                      duration: Duration(milliseconds: 450 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, _) => Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_n(rows[i]['amount']) > 0 && t > 0.15)
                            Text(
                              _short(_n(rows[i]['amount'])),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Brand.muted,
                              ),
                            ),
                          const SizedBox(height: 3),
                          Container(
                            height: 8 + 82 * t,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              gradient: Brand.heroGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _s(rows[i]['label']),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Brand.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _short(num v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

/// Horizontal bars (students per class). Shows the top eight, with an expander.
class _HBars extends StatefulWidget {
  const _HBars({
    required this.rows,
    required this.labelKey,
    required this.valueKey,
  });
  final List<Map<String, dynamic>> rows;
  final String labelKey;
  final String valueKey;

  @override
  State<_HBars> createState() => _HBarsState();
}

class _HBarsState extends State<_HBars> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const _Empty('Nothing to show yet.');
    final max = widget.rows
        .map((r) => _n(r[widget.valueKey]))
        .fold<num>(1, (a, b) => a > b ? a : b);
    final shown = _all ? widget.rows : widget.rows.take(8).toList();
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      _s(shown[i][widget.labelKey]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: (_n(shown[i][widget.valueKey]) / max).toDouble(),
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: t,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE8EDFC),
                          color: Brand.accent(i).$1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      formatIndian(_n(shown[i][widget.valueKey])),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.rows.length > 8)
            TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(
                _all ? 'Show less' : 'Show all ${widget.rows.length}',
              ),
            ),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final list = items.where((e) => e.trim().isNotEmpty && e != ' - ').toList();
    if (list.isEmpty) return const _Empty('Nothing assigned yet.');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < list.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Brand.accent(i).$2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              list[i],
              style: TextStyle(
                color: Brand.accent(i).$1,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _SimpleList extends StatelessWidget {
  const _SimpleList({
    required this.rows,
    required this.titleKey,
    required this.subKey,
    this.subPrefix = '',
    required this.icon,
  });
  final List<Map<String, dynamic>> rows;
  final String titleKey;
  final String subKey;
  final String subPrefix;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('All clear.');
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length && i < 6; i++)
            ListTile(
              dense: true,
              leading: IconBubble(
                icon: icon,
                accent: Brand.accent(i),
                size: 38,
              ),
              title: Text(
                _s(rows[i][titleKey]).isEmpty
                    ? 'Untitled'
                    : _s(rows[i][titleKey]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: _s(rows[i][subKey]).isEmpty
                  ? null
                  : Text(
                      '$subPrefix${_s(rows[i][subKey])}',
                      style: const TextStyle(fontSize: 12),
                    ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptList extends StatelessWidget {
  const _ReceiptList({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('No receipts yet.');
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            ListTile(
              dense: true,
              leading: IconBubble(
                icon: Icons.receipt_long_rounded,
                accent: Brand.accent(5),
                size: 38,
              ),
              title: Text(
                _s(rows[i]['student_name']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Receipt ${_s(rows[i]['receipt_no'])} · ${_s(rows[i]['receiptdate'])}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                '₹${formatIndian(_n(rows[i]['amount']))}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Birthdays extends StatelessWidget {
  const _Birthdays({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('No birthdays in the next 7 days.');
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            ListTile(
              dense: true,
              leading: IconBubble(
                icon: Icons.cake_rounded,
                accent: Brand.accent(3),
                size: 38,
              ),
              title: Text(
                _s(rows[i]['student_name']),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${_s(rows[i]['standard_name'])} - ${_s(rows[i]['division_name'])}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                _s(rows[i]['dob']),
                style: const TextStyle(fontSize: 12, color: Brand.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    if (row.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: Brand.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class ${_s(row['standard_name'])} - ${_s(row['section_name'])}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Academic year ${_s(row['syear'])}',
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Done-vs-pending pairs ("Homework done" / "Homework pending") as completion bars.
class _TaskStatus extends StatelessWidget {
  const _TaskStatus({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _Empty('No tasks yet.');
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _s(rows[i]['label']),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Brand.accent(i).$2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      displayValue(rows[i]['value']),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Brand.accent(i).$1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---- loading skeleton ---------------------------------------------------------------------

class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _box(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFE2E8F0),
      borderRadius: BorderRadius.circular(18),
    ),
  );

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _box(72)),
              const SizedBox(width: 12),
              Expanded(child: _box(72)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _box(72)),
              const SizedBox(width: 12),
              Expanded(child: _box(72)),
            ],
          ),
          const SizedBox(height: 22),
          _box(170),
          const SizedBox(height: 18),
          _box(120),
        ],
      ),
    ),
  );
}
