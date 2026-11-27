import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/design.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import '../teacher/api_migration.dart';
import 'admin_common.dart';
import 'admission_charts.dart';
import 'admission_form.dart';
import 'admission_registration_form.dart';
import '../../ui/app_loader.dart';

enum AdmissionStage { enquiry, registration, confirmation }

extension AdmissionStageInfo on AdmissionStage {
  String get path => switch (this) {
        AdmissionStage.enquiry => '/admission/admission_enquiry',
        AdmissionStage.registration => '/admission/admission_registration',
        AdmissionStage.confirmation => '/admission/admission_confirmation',
      };
  /// Newer endpoint (rows 76-78). Confirmations use the registration list query.
  String get apiPath => switch (this) {
        AdmissionStage.enquiry => '/api/admission_enquiry',
        AdmissionStage.registration || AdmissionStage.confirmation => '/api/admission_registration',
      };
  String get title => switch (this) {
        AdmissionStage.enquiry => 'Admission enquiry',
        AdmissionStage.registration => 'Admission registration',
        AdmissionStage.confirmation => 'Admission confirmation',
      };
  String get emptyText => switch (this) {
        AdmissionStage.enquiry => 'No admission enquiries yet.',
        AdmissionStage.registration => 'No admission registrations yet.',
        AdmissionStage.confirmation => 'No confirmed admissions yet.',
      };
}

/// t_enquiry / t_registration / t_confirmation: the admission pipeline lists.
/// Enquiries can be added and edited, registrations edited; confirmations are read-only
/// because the old create/edit screen for them was broken.
class AdmissionListScreen extends StatefulWidget {
  const AdmissionListScreen({super.key, required this.args, required this.stage, this.readOnly = false, this.withoutConfirmation = false});
  final ScreenArgs args;
  final AdmissionStage stage;

  /// The "Admission Without Confirmation" report: enquiries that never got a registration.
  final bool withoutConfirmation;

  /// Report views: the same rows with no Add / Edit.
  final bool readOnly;

  @override
  State<AdmissionListScreen> createState() => _AdmissionListScreenState();
}

class _AdmissionListScreenState extends State<AdmissionListScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _rows.isEmpty;
      _error = null;
    });
    try {
      final data = await _load();
      if (mounted) setState(() => _rows = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the list. Pull down to try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<List<Map<String, dynamic>>> _load() {
    final stage = widget.stage;
    if (widget.withoutConfirmation) return _loadWithoutConfirmation();
    if (stage == AdmissionStage.enquiry) return _loadEnquiries();
    // The web's Registration and Confirmation lists are both built from the enquiry list, then each
    // row's registration detail decides which list it belongs to (detail.status OPEN = still to
    // confirm; anything else = registered). /api/admission_registration lists a different set.
    return _loadPipeline(stage);
  }

  Future<List<Map<String, dynamic>>> _loadEnquiries() => readNewThenLegacy(
        'admission enquiry list',
        () async => adaptAdmissionRows(rows((await getNew(widget.args.api, '/api/admission_enquiry'))['data'])),
        () async {
          final res = await widget.args.api.get(widget.stage.path);
          if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
          return rows(res['data']);
        },
      );

  /// Same steps as the web report: list `admission_without_confirmation_report_v2`, read each row's
  /// detail, and keep the ones with no registration (`registration_enquiry_id` empty).
  Future<List<Map<String, dynamic>>> _loadWithoutConfirmation() async {
    final api = widget.args.api;
    final list = rows((await getNew(api, '/api/admission_without_confirmation_report_v2'))['data']);
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < list.length; i += 8) {
      final batch = list.skip(i).take(8).toList();
      final details = await Future.wait(batch.map((r) async {
        try {
          final res = await getNew(api, '/api/admission_without_confirmation_report_v2/${s(r['id'])}/edit');
          final d = res['editData'];
          return d is Map ? Map<String, dynamic>.from(d) : null;
        } catch (_) {
          return null;
        }
      }));
      for (var j = 0; j < batch.length; j++) {
        final d = details[j];
        if (d == null || s(d['registration_enquiry_id']).isNotEmpty) continue;
        out.add({...batch[j], ...d, 'pipeline_status': 'Open'});
      }
    }
    return adaptAdmissionRows(out);
  }

  Future<List<Map<String, dynamic>>> _loadPipeline(AdmissionStage stage) async {
    final enquiries = await _loadEnquiries();
    final out = <Map<String, dynamic>>[];
    // Small batches: one detail call per enquiry, but never hundreds at once on a phone.
    for (var i = 0; i < enquiries.length; i += 8) {
      final batch = enquiries.skip(i).take(8).toList();
      final details = await Future.wait(batch.map((r) async {
        try {
          final res = await getNew(widget.args.api, '/api/admission_registration/${s(r['id'])}/edit');
          final d = res['editData'];
          if (d is! Map) return null;
          // Kept for the Confirm / Add student actions (the same fields the web sends back).
          return <String, dynamic>{
            ...Map<String, dynamic>.from(d),
            '_display_save': s(res['display_save_student']),
            '_custom_names': [for (final f in rows(res['custom_fields'])) s(f['field_name'])],
          };
        } catch (_) {
          return null;
        }
      }));
      for (var j = 0; j < batch.length; j++) {
        final row = batch[j];
        final d = details[j];
        final open = (d == null ? '' : s(d['status'])).toUpperCase() == 'OPEN';
        if (stage == AdmissionStage.confirmation) {
          if (d == null || !open) continue;
          final hasStudent = (num.tryParse(s(d['total_student_count'])) ?? 0) > 0;
          final confirmed = s(d['admission_status']).toUpperCase() == 'YES';
          out.add({...row, 'pipeline_status': hasStudent ? 'Student Added' : confirmed ? 'Confirmed' : 'Open', '_detail': d});
        } else {
          if (open) continue;
          final raw = d == null ? '' : s(d['status']).toUpperCase();
          final hasStudent = d != null && (num.tryParse(s(d['total_student_count'])) ?? 0) > 0;
          out.add({...row, 'pipeline_status': raw == 'CLOSE' ? 'Closed' : hasStudent ? 'Approved' : 'Pending'});
        }
      }
    }
    return out;
  }

  static const _tracked = [
    'enquiry_no', 'first_name', 'middle_name', 'last_name', 'gender', 'mobile', 'email', 'date_of_birth', 'age',
    'address', 'previous_school_name', 'previous_standard', 'admission_standard', 'source_of_enquiry', 'remarks',
    'fees_remark', 'followup_date', 'register_number', 'mother_name', 'mother_mobile_number', 'aadhar_number',
    'status', 'place_of_birth', 'student_quota', 'admission_division', 'enrollment_no', 'amount', 'blood_group',
    'payment_mode', 'bank_name', 'bank_branch', 'cheque_no', 'cheque_date', 'date_of_payment', 'admission_date',
    'admission_status', 'religion', 'cast',
  ];

  bool _acting = false;

  Map<String, dynamic> _detailOf(Map<String, dynamic> r) =>
      r['_detail'] is Map ? Map<String, dynamic>.from(r['_detail'] as Map) : <String, dynamic>{};

  /// Web "Confirm": saves the registration with admission_status = YES; every other saved value is
  /// sent back unchanged, like the web's saveRegistration.
  Future<void> _confirm(Map<String, dynamic> r) async {
    final d = _detailOf(r);
    final session = widget.args.session;
    final body = <String, String>{
      'type': 'API',
      'sub_institute_id': '${session.subInstituteId}',
      'syear': syearOf(session),
      'user_id': '${session.userId}',
    };
    final custom = ((d['_custom_names'] as List?) ?? const []).map((e) => '$e');
    for (final k in [..._tracked, ...custom]) {
      final v = s(d[k]);
      if (v.isNotEmpty) body[k] = v;
    }
    body['enquiry_id'] = s(d['enquiry_id']).isEmpty ? s(r['id']) : s(d['enquiry_id']);
    body['admission_status'] = 'YES';
    await _run(() async {
      final res = await AdminHttp.put(session, '/api/admission_registration/${s(r['id'])}', body);
      return _report(res, 'Admission confirmed. You can now add the student.');
    });
  }

  /// Web "Add student": POST /api/admission_student with the linked enquiry id.
  Future<void> _addStudent(Map<String, dynamic> r) async {
    final d = _detailOf(r);
    final linked = [d['registration_enquiry_id'], d['enquiry_id'], r['id']].map(s).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    if (linked.isEmpty) {
      toast(context, 'This record is missing the linked enquiry.', error: true);
      return;
    }
    await _run(() async {
      final res = await widget.args.api.post('/api/admission_student?type=API', body: {'id': linked});
      return _report(res, 'Student added.');
    });
  }

  Future<void> _run(Future<bool> Function() action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      if (await action()) await _reload();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  bool _report(Map<String, dynamic> res, String ok) {
    final good = submitOk(res);
    toast(context, LegacyApi.messageOf(res, good ? ok : 'Something went wrong.'), error: !good);
    return good;
  }

  Widget? _confirmActions(Map<String, dynamic> r) {
    final status = s(r['pipeline_status']);
    if (status == 'Student Added') return null;
    if (status != 'Confirmed') {
      return FilledButton.icon(
        onPressed: _acting ? null : () => _confirm(r),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Confirm admission'),
      );
    }
    final canAdd = s(_detailOf(r)['_display_save']) == '1';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FilledButton.icon(
        onPressed: _acting || !canAdd ? null : () => _addStudent(r),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add student'),
      ),
      if (!canAdd)
        Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Please complete admission enquiry and registration before confirmation.', style: TextStyle(fontSize: 12.5, color: Brand.muted)),
        ),
    ]);
  }

  Future<void> _open(Map<String, dynamic>? row) async {
    // Registration uses the server-driven form (dropdowns and custom fields come from the API).
    final screen = widget.stage == AdmissionStage.registration && row != null && s(row['id']).isNotEmpty
        ? AdmissionRegistrationFormScreen(args: widget.args, row: row)
        : AdmissionFormScreen(args: widget.args, stage: widget.stage, row: row);
    final saved = await push<bool>(context, screen);
    if (saved == true) await _reload();
  }

  DateTime? _day(dynamic v) {
    final d = DateTime.tryParse(s(v).split(' ').first);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  /// -1 overdue, 0 today, 1 upcoming, null = no follow-up date.
  int? _followState(Map<String, dynamic> r) {
    final d = _day(r['followup_date']);
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today) ? -1 : (d == today ? 0 : 1);
  }

  List<String> get _filters {
    if (widget.stage == AdmissionStage.enquiry) return const ['All', 'Due today', 'Overdue', 'Upcoming'];
    final statuses = {for (final r in _rows) s(r['pipeline_status'])}..remove('');
    return ['All', ...statuses];
  }

  List<Map<String, dynamic>> get _shown {
    final q = _query.trim().toLowerCase();
    return _rows.where((r) {
      if (_filter != 'All') {
        if (widget.stage == AdmissionStage.enquiry) {
          final st = _followState(r);
          final ok = switch (_filter) {
            'Due today' => st == 0,
            'Overdue' => st == -1,
            'Upcoming' => st == 1,
            _ => true,
          };
          if (!ok) return false;
        } else if (s(r['pipeline_status']) != _filter) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      final hay = [r['first_name'], r['middle_name'], r['last_name'], r['mobile'], r['email'], r['enquiry_no'], r['std_name']].map(s).join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final canAdd = stage == AdmissionStage.enquiry && !widget.readOnly;
    final shown = _shown;
    final due = _rows.where((r) => _followState(r) == 0).length;
    final overdue = _rows.where((r) => _followState(r) == -1).length;
    final upcoming = _rows.where((r) => _followState(r) == 1).length;

    return KitPage(
      title: widget.args.item.label.isEmpty ? stage.title : widget.args.item.label,
      bottom: canAdd ? formBar(label: 'New enquiry', busy: false, onPressed: () => _open(null)) : null,
      child: _loading
          ? const AppLoader()
          : _error != null && _rows.isEmpty
              ? KitMessage(icon: Icons.error_outline, text: _error!, action: 'Retry', onAction: _reload)
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      Rise(
                        child: _Hero(
                          title: stage == AdmissionStage.enquiry ? 'Enquiries' : stage == AdmissionStage.registration ? 'Registrations' : 'Confirmations',
                          total: _rows.length,
                          stats: stage == AdmissionStage.enquiry
                              ? [('Due today', due, Colors.amber.shade300), ('Overdue', overdue, const Color(0xFFFCA5A5)), ('Upcoming', upcoming, const Color(0xFF93C5FD))]
                              : [for (final f in _filters.skip(1).take(3)) (f, _rows.where((r) => s(r['pipeline_status']) == f).length, const Color(0xFF93C5FD))],
                        ),
                      ),
                      if (widget.readOnly && _rows.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Rise(
                          delay: const Duration(milliseconds: 80),
                          child: AdmissionCharts(
                            rows: _rows,
                            noun: stage == AdmissionStage.enquiry ? 'Enquiries' : stage == AdmissionStage.registration ? 'Registrations' : 'Confirmations',
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search name, mobile, email or number',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Brand.card,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Brand.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Brand.line)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final f in _filters) PillChip(label: f, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 56),
                          child: Column(children: [
                            const IconTile(Icons.how_to_reg_outlined, size: 56),
                            const SizedBox(height: 12),
                            Text(_rows.isEmpty ? stage.emptyText : 'No matches', style: TextStyle(color: Brand.muted, fontSize: 15)),
                          ]),
                        ),
                      for (var i = 0; i < shown.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Rise(
                            delay: Duration(milliseconds: i < 8 ? 40 * i : 0),
                            child: AdmissionCard(
                              index: i + 1,
                              row: shown[i],
                              follow: _followState(shown[i]),
                              onEdit: stage == AdmissionStage.confirmation || widget.readOnly ? null : () => _open(shown[i]),
                              actions: stage == AdmissionStage.confirmation && !widget.readOnly ? _confirmActions(shown[i]) : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

/// Navy hero: the headline count and up to three live stats.
class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.total, required this.stats});
  final String title;
  final int total;
  final List<(String, int, Color)> stats;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        // One line: the total, a divider, then each stat as "number + label".
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            CountUp(
              value: total,
              builder: (v) => Text('$v', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
            ),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(color: Brand.champagne, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
          Container(width: 1, height: 34, margin: const EdgeInsets.symmetric(horizontal: 14), color: Colors.white.withValues(alpha: 0.16)),
          for (var i = 0; i < stats.length; i++)
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${stats[i].$2}', style: TextStyle(color: stats[i].$3, fontSize: 20, fontWeight: FontWeight.w800, height: 1)),
                const SizedBox(height: 3),
                Text(stats[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.champagne, fontSize: 11.5)),
              ]),
            ),
        ]),
      );
}

class AdmissionCard extends StatelessWidget {
  const AdmissionCard({super.key, required this.index, required this.row, this.onEdit, this.actions, this.follow});
  final int index;
  final Map<String, dynamic> row;
  final VoidCallback? onEdit;

  /// Confirm / Add student buttons under the card.
  final Widget? actions;

  /// -1 overdue, 0 today, 1 upcoming, null none.
  final int? follow;

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.length == 1 ? p.first[0] : p.first[0] + p.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final r = row;
    final name = [r['first_name'], r['middle_name'], r['last_name']].map(s).where((e) => e.isNotEmpty).join(' ');
    final std = s(r['std_name']).isNotEmpty ? s(r['std_name']) : s(r['admission_standard']);
    final status = s(r['pipeline_status']).isNotEmpty ? s(r['pipeline_status']) : s(r['enquiry_status']);
    final mobile = s(r['mobile']);
    final followDate = fmtDate(r['followup_date'], out: 'dd MMM');

    final (Color fg, Color bg, String followText) = switch (follow) {
      -1 => (Brand.err, Brand.err0, 'Overdue $followDate'),
      0 => (Brand.warn, Brand.warn0, 'Today'),
      1 => (Brand.info, Brand.info0, followDate),
      _ => (Brand.ink3, Brand.field, 'No follow-up'),
    };

    // One quiet line: number · standard · age · enquiry date.
    final meta = [
      if (s(r['enquiry_no']).isNotEmpty) '#${s(r['enquiry_no'])}',
      if (std.isNotEmpty) 'Std $std',
      if (s(r['age']).isNotEmpty) '${s(r['age'])} yrs',
      if (s(r['created_on']).isNotEmpty) fmtDate(r['created_on'], out: 'dd MMM'),
    ].join('  ·  ');

    final accent = switch (follow) { -1 => Brand.err, 0 => const Color(0xFFD97706), 1 => Brand.info, _ => Brand.border };

    return Container(
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.line),
        boxShadow: Brand.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Slim status rail: red overdue, amber today, blue upcoming.
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Brand.primary, Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(name.isEmpty ? 'Unnamed enquiry' : name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Brand.ink)),
                        ),
                        if (status.isNotEmpty) ...[const SizedBox(width: 6), Tag.ok(status)],
                      ]),
                      if (meta.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted, fontSize: 12)),
                        ),
                    ]),
                  ),
                ]),
                if (s(r['remarks']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(s(r['remarks']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.ink2, fontSize: 12.5)),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.schedule_rounded, size: 13, color: fg),
                      const SizedBox(width: 4),
                      Text(followText, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11.5)),
                    ]),
                  ),
                  if (mobile.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: InkWell(
                        onTap: () => openUrl(context, 'tel:$mobile'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.call_rounded, size: 14, color: Brand.primary),
                            const SizedBox(width: 4),
                            Flexible(child: Text(mobile, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.primaryDark, fontWeight: FontWeight.w700, fontSize: 12.5))),
                          ]),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (onEdit != null)
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: IconButton.filledTonal(
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 17),
                      ),
                    ),
                ]),
                if (actions != null) ...[const SizedBox(height: 10), actions!],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The new `api/admission_enquiry` list returns raw table rows (no standard join): fill in
/// `std_name` from the standard id so the card reads the same as before. Rows keep their numeric
/// `id`, which the new PUT routes use instead of the enquiry number.
List<Map<String, dynamic>> adaptAdmissionRows(List<Map<String, dynamic>> list) => [
      for (final r in list)
        {
          ...r,
          if (s(r['std_name']).isEmpty)
            'std_name': admissionStandards.where((o) => o.id == s(r['admission_standard'])).firstOrNull?.label ?? s(r['admission_standard']),
        }
    ];
