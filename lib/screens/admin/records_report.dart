import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/design.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import '../../presentation/admin/fees_master/fees_master_controller.dart';
import '../../presentation/admin/fees_master/fees_master_form_screen.dart';
import '../../presentation/admin/fees_master/fees_master_spec.dart';
import 'admin_common.dart';
import '../../ui/app_loader.dart';

/// One field line on a record card.
class RecField {
  const RecField(this.label, this.keys, {this.date = false, this.yesNo = false});
  final String label;

  /// Show 1 / Y as "Yes" and 0 / N as "No".
  final bool yesNo;

  /// First non-empty key wins.
  final List<String> keys;
  final bool date;
}

/// Read-only, searchable list of records from a JSON API, drawn as polished cards.
/// A new screen is one config: the endpoint, where the rows sit in the response, and which
/// keys are the title / subtitle / badge / extra lines. Writes stay on the web for now.
class RecordsReportScreen extends StatefulWidget {
  const RecordsReportScreen({
    super.key,
    required this.args,
    required this.endpoint,
    this.rowsKey = '',
    this.titleKeys = const [],
    this.auto = false,
    this.subtitleKeys = const [],
    this.dateKey,
    this.badgeKeys = const [],
    this.amountKey,
    this.fields = const [],
    this.icon = Icons.description_outlined,
    this.emptyText = 'Nothing to show yet.',
    this.query = const {},
    this.dateRange = false,
    this.post = false,
    this.master,
    this.addLabel,
    this.addScreen,
    this.dedupeKey,
    this.classFilter = false,
    this.labelMapKey,
    this.hideZero = false,
    this.headPrefix,
  });

  /// Also show a tile for every record key starting with this prefix (a fee head's amount, e.g. `total_`),
  /// named from [labelMapKey], skipping zeros.
  final String? headPrefix;

  /// A response key holding `{column: "Nice label"}`, used to name the auto-detected detail tiles.
  final String? labelMapKey;

  /// Leave out tiles whose value is 0 (a daily summary with many empty heads).
  final bool hideZero;

  /// Show a Section / Standard / Division picker; sent as grade / standard / division.
  final bool classFilter;

  /// The server lists one row per class x head; when set, keep one card per value of this key.
  final String? dedupeKey;

  /// A custom "Add" flow (a full screen of its own) instead of a [master] form; the list reloads after it saves.
  final String? addLabel;
  final Widget Function()? addScreen;

  /// When set, the list can Add, Edit and Delete rows of this Fees (Master).
  final FeesMasterSpec? master;

  final ScreenArgs args;
  final String endpoint;

  /// Show From / To pickers (this month by default); sent as from_date / to_date.
  final bool dateRange;

  /// Call the endpoint with POST (the legacy report forms post their filters).
  final bool post;

  /// Unknown shape (a legacy ERP page opened via type=API): find the biggest list of records in the
  /// response and pick the title / subtitle / detail lines from its keys.
  final bool auto;

  /// Path into the response, e.g. `data.entries`.
  final String rowsKey;
  final List<String> titleKeys;
  final List<String> subtitleKeys;
  final String? dateKey;
  final List<String> badgeKeys;

  /// Shown as a bold ₹ amount on the right and summed in the header.
  final String? amountKey;
  final List<RecField> fields;
  final IconData icon;
  final String emptyText;
  final Map<String, String> query;

  @override
  State<RecordsReportScreen> createState() => _RecordsReportScreenState();
}

class _RecordsReportScreenState extends State<RecordsReportScreen> {
  List<Map<String, dynamic>> _all = [];
  String _q = '';
  bool _loading = true;
  String? _error;
  CascadeSelection _cascade = CascadeSelection();
  Map<String, String> _labels = {};
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  dynamic _dig(dynamic v, String path) {
    for (final p in path.split('.')) {
      if (v is Map) {
        v = v[p];
      } else {
        return null;
      }
    }
    return v;
  }

  String _first(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = s(r[k]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  List<(String, String)> _peek = [];

  /// Top-level shape of a response, for the "no records" card: scalar values and list sizes.
  List<(String, String)> _summarise(dynamic res) {
    if (res is! Map) return [];
    final out = <(String, String)>[];
    void add(String prefix, Map m, int depth) {
      for (final e in m.entries) {
        final k = prefix.isEmpty ? '${e.key}' : '$prefix.${e.key}';
        final v = e.value;
        if (v is List) {
          out.add((k, '${v.length} item${v.length == 1 ? '' : 's'}'));
        } else if (v is Map) {
          if (depth < 2) add(k, v, depth + 1);
        } else {
          final t = s(v);
          if (t.isNotEmpty) out.add((k, t.length > 80 ? '${t.substring(0, 80)}…' : t));
        }
      }
    }

    add('', res, 0);
    return out.take(14).toList();
  }

  // Auto mode: keys chosen from the first record.
  List<String> _autoTitle = [], _autoSub = [];
  List<RecField> _autoFields = [];

  List<String> get _titleKeys => widget.auto ? _autoTitle : widget.titleKeys;
  List<String> get _subKeys => widget.auto ? _autoSub : widget.subtitleKeys;
  List<RecField> get _fieldList => widget.auto ? _autoFields : widget.fields;

  /// The largest list of record maps anywhere in the response (depth-limited).
  List<Map<String, dynamic>> _autoRows(dynamic root) {
    var best = <Map<String, dynamic>>[];
    void walk(dynamic v, int depth) {
      if (depth > 4) return;
      if (v is List) {
        final maps = v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        if (maps.length > best.length && maps.length >= v.length * 0.8) best = maps;
        for (final x in v.take(3)) {
          walk(x, depth + 1);
        }
      } else if (v is Map) {
        // A map keyed by day / id whose values are records: one row per entry, the key kept as `_key`.
        final entries = v.entries.where((e) => e.value is Map && (e.value as Map).isNotEmpty).toList();
        if (entries.length >= 2 && entries.length >= v.length * 0.5 && entries.length > best.length && entries.every((e) => (e.value as Map).values.every((x) => x is! Map && x is! List))) {
          best = [for (final e in entries) {...Map<String, dynamic>.from(e.value as Map), '_key': '${e.key}'}];
        }
        for (final x in v.values) {
          walk(x, depth + 1);
        }
      }
    }

    walk(root, 0);
    return best;
  }

  static const _skipKeys = {'id', 'sub_institute_id', 'syear', 'created_at', 'updated_at', 'created_by', 'created_on', 'created_ip', 'created_ip_address', 'deleted_at', 'status_code'};

  Map<String, String> _labelMap(Map<String, dynamic> res) {
    final src = widget.labelMapKey == null ? null : res[widget.labelMapKey];
    if (src is Map) return {for (final e in src.entries) '${e.key}': s(e.value)};
    if (src is List) {
      return {
        for (final r in src.whereType<Map>())
          if (s(r['fees_title']).isNotEmpty) s(r['fees_title']): s(r['display_name']).isNotEmpty ? s(r['display_name']) : s(r['fees_title']),
      };
    }
    return {};
  }

  String _label(String k) {
    final mapped = _labels[k] ?? _labels[k.replaceFirst('total_', '')];
    if (mapped != null && mapped.isNotEmpty) return mapped;
    final t = k.replaceAll('_', ' ').trim();
    return t.isEmpty ? k : '${t[0].toUpperCase()}${t.substring(1).toLowerCase()}';
  }

  void _deriveKeys() {
    if (_all.isEmpty) return;
    // Keys that carry readable text, in the record's own order.
    final keys = <String>[];
    for (final e in _all.first.entries) {
      final k = e.key;
      final v = e.value;
      if (v is Map || v is List) continue;
      if (_skipKeys.contains(k.toLowerCase()) || k.toLowerCase().endsWith('_id')) continue;
      if (s(v).isEmpty) continue;
      keys.add(k);
    }
    const preferred = ['_key', 'name', 'title', 'full_name', 'student_name', 'first_name', 'employee_name', 'item_name', 'subject_name', 'route_name', 'stop_name', 'label'];
    final title = keys.firstWhere((k) => preferred.contains(k.toLowerCase()), orElse: () => keys.isEmpty ? '' : keys.first);
    final rest = keys.where((k) => k != title).toList();
    _autoTitle = title.isEmpty ? [] : [title];
    _autoSub = rest.isEmpty ? [] : [rest.first];
    _autoFields = [for (final k in rest.skip(1).take(6)) RecField(_label(k), [k])];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, String>{
        ...widget.query,
        if (widget.dateRange) 'from_date': ymd(_from),
        if (widget.dateRange) 'to_date': ymd(_to),
        if (widget.classFilter && _cascade.sectionId != null) 'grade': _cascade.sectionId!,
        if (widget.classFilter && _cascade.standardId != null) 'standard': _cascade.standardId!,
        if (widget.classFilter && _cascade.divisionId != null) 'division': _cascade.divisionId!,
      };
      final res = widget.post
          ? await widget.args.api.post(widget.endpoint, body: params)
          : await widget.args.api.get(widget.endpoint, query: params);
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      if (widget.auto) {
        _all = _autoRows(res);
        _labels = _labelMap(res);
        _deriveKeys();
        _peek = _summarise(res);
      } else {
        _all = rows(_dig(res, widget.rowsKey));
      }
      if (!widget.auto && widget.labelMapKey != null) _labels = _labelMap(res);
      if (widget.dedupeKey != null) {
        final seen = <String>{};
        _all = [for (final r in _all) if (seen.add(s(r[widget.dedupeKey]))) r];
      }
    } on ApiException catch (e) {
      // A legacy page that answers with a web page instead of data has no mobile version yet.
      _error = widget.auto && e.message.toLowerCase().contains('unexpected response')
          ? 'This screen has no mobile version yet. Please use it on the web for now.'
          : e.message;
    } catch (_) {
      _error = 'Could not load this list. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openAdd() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => widget.addScreen!()));
    if (saved == true) await _load();
  }

  Future<void> _openForm(Map<String, dynamic>? row) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FeesMasterFormScreen(args: widget.args, spec: widget.master!, row: row)),
    );
    if (saved == true) await _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final spec = widget.master!;
    final name = spec.rowTitle?.call(row) ?? 'this record';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${spec.title.toLowerCase()}?'),
        content: Text('"$name" will be deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Back')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Brand.err), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final (done, message) = await FeesMasterController.delete(widget.args.api, widget.args, spec, row);
    if (!mounted) return;
    toast(context, message, error: !done);
    if (done) await _load();
  }

  List<Map<String, dynamic>> get _shown {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((r) => r.values.any((v) => v is! Map && v is! List && s(v).toLowerCase().contains(q))).toList();
  }

  String _money(num v) => '₹${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final total = widget.amountKey == null
        ? null
        : _all.fold<num>(0, (a, r) => a + (num.tryParse(s(r[widget.amountKey])) ?? 0));

    final master = widget.master;
    return KitPage(
      title: widget.args.item.label,
      bottom: master != null && master.canAdd && !_loading
          ? formBar(label: 'Add ${master.title.toLowerCase()}', busy: false, onPressed: () => _openForm(null))
          : (widget.addScreen != null && !_loading
              ? formBar(label: widget.addLabel ?? 'Add', busy: false, onPressed: _openAdd)
              : null),
      child: _loading && !widget.dateRange
          ? const AppLoader()
          : _error != null && !widget.dateRange
              ? KitMessage(icon: Icons.error_outline, text: _error!, action: 'Retry', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: Brand.softShadow,
                        ),
                        child: Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                            child: Icon(widget.icon, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${_all.length} ${_all.length == 1 ? 'record' : 'records'}',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                              if (total != null)
                                Text('Total ${_money(total)}', style: const TextStyle(color: Brand.champagne, fontSize: 13, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                      ),
                      if (widget.classFilter) ...[
                        const SizedBox(height: 12),
                        SoftCard(
                          radius: 16,
                          padding: const EdgeInsets.all(12),
                          child: CascadeFilter(
                            api: widget.args.api,
                            onChanged: (c) {
                              _cascade = c;
                              _load();
                            },
                          ),
                        ),
                      ],
                      if (widget.dateRange) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: DateField(
                              label: 'From',
                              value: _from,
                              last: DateTime.now(),
                              onChanged: (d) {
                                setState(() {
                                  _from = d;
                                  if (_to.isBefore(_from)) _to = _from;
                                });
                                _load();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DateField(
                              label: 'To',
                              value: _to,
                              last: DateTime.now(),
                              onChanged: (d) {
                                setState(() {
                                  _to = d;
                                  if (_from.isAfter(_to)) _from = _to;
                                });
                                _load();
                              },
                            ),
                          ),
                        ]),
                        if (_loading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 3)),
                        if (_error != null)
                          Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Brand.err, fontSize: 13))),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (v) => setState(() => _q = v),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Brand.card,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Brand.line)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (shown.isEmpty && widget.auto && _all.isEmpty && _peek.isNotEmpty)
                        KitCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('This page returned no records', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              'It probably needs a filter (class, date…) before it shows data. What the server sent:',
                              style: TextStyle(color: Brand.muted, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            for (final line in _peek) KV(line.$1, line.$2),
                            const SizedBox(height: 8),
                            Text(widget.endpoint, style: TextStyle(color: Brand.muted, fontSize: 11.5)),
                          ]),
                        )
                      else if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Center(child: Text(_all.isEmpty ? widget.emptyText : 'No matches.', style: TextStyle(color: Brand.muted))),
                        ),
                      for (final r in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _card(r),
                        ),
                    ],
                  ),
                ),
    );
  }

  String _factValue(Map<String, dynamic> r, RecField f) {
    final raw = f.date ? fmtDate(_first(r, f.keys)) : _first(r, f.keys);
    if (widget.hideZero && (num.tryParse(raw) ?? 1) == 0) return '';
    if (!f.yesNo) return raw;
    final v = raw.toLowerCase();
    if (v == '1' || v == 'y' || v == 'yes' || v == 'true') return 'Yes';
    if (v == '0' || v == 'n' || v == 'no' || v == 'false') return 'No';
    return raw;
  }

  /// The card's details as small tiles, two per row: a short label over a bold value.
  Widget _facts(Map<String, dynamic> r) {
    final items = <(String, String)>[
      for (final f in _fieldList)
        if (_factValue(r, f).isNotEmpty) (f.label, _factValue(r, f)),
    ];
    final prefix = widget.headPrefix;
    if (prefix != null) {
      for (final e in r.entries) {
        if (!e.key.startsWith(prefix) || e.value is Map || e.value is List) continue;
        final v = num.tryParse(s(e.value));
        if (v == null || v == 0) continue;
        items.add((_label(e.key), '${v % 1 == 0 ? v.toInt() : v}'));
      }
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 8) / 2;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final it in items)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Brand.muted)),
                  const SizedBox(height: 2),
                  Text(it.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Brand.ink)),
                ]),
              ),
            ),
        ]);
      }),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final rawTitle = _first(r, _titleKeys);
    final title = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawTitle) ? fmtDate(rawTitle) : rawTitle;
    final sub = _first(r, _subKeys);
    final badge = _first(r, widget.badgeKeys);
    final date = widget.dateKey == null ? '' : fmtDate(r[widget.dateKey]);
    final amount = widget.amountKey == null ? '' : s(r[widget.amountKey]);

    final master = widget.master;
    final editable = master != null && master.canEdit;
    return KitCard(
      onTap: editable ? () => _openForm(r) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Brand.tint, borderRadius: BorderRadius.circular(12)),
            child: Icon(widget.icon, color: Brand.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.isEmpty ? '—' : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted, fontSize: 13)),
              ],
            ]),
          ),
          if (amount.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(_money(num.tryParse(amount) ?? 0), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Brand.primaryDark)),
            ),
          if (master != null && (master.canEdit || master.canDelete))
            SizedBox(
              width: 36,
              height: 36,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                tooltip: 'Actions',
                icon: Icon(Icons.more_vert_rounded, color: Brand.ink3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) => v == 'edit' ? _openForm(r) : _confirmDelete(r),
                itemBuilder: (_) => [
                  if (master.canEdit)
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 10), Text('Edit')])),
                  if (master.canDelete)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Brand.err), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Brand.err))]),
                    ),
                ],
              ),
            ),
        ]),
        if (date.isNotEmpty || badge.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (date.isNotEmpty) Pill(date, color: Brand.info),
            if (badge.isNotEmpty) Pill(badge),
          ]),
        ],
        _facts(r),
      ]),
    );
  }
}
