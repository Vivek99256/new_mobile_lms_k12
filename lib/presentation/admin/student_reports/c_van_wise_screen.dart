import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'c_report_ui.dart';
import '../../../ui/app_loader.dart';

/// Van Wise Report: the students on each van, for the pickup or the drop run. The pickers (van / shift / route)
/// come from `GET transportation/van_wise_report`; the list from `GET transportation/van_wise_report/create`.
class CVanWiseScreen extends StatefulWidget {
  const CVanWiseScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<CVanWiseScreen> createState() => _CVanWiseScreenState();
}

class _CVanWiseScreenState extends State<CVanWiseScreen> {
  List<Opt> _vans = [], _shifts = [], _routes = [];
  bool _metaLoading = true;
  bool _loading = false;
  bool _searched = false;
  String? _error;

  String _run = 'pickup'; // pickup | drop
  String? _van, _shift, _route;
  List<Map<String, dynamic>> _all = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _meta();
  }

  /// `{id: title}` maps from the server, as dropdown options.
  List<Opt> _opts(dynamic v) {
    if (v is Map) return [for (final e in v.entries) Opt('${e.key}', s(e.value))];
    if (v is List) return [for (var i = 0; i < v.length; i++) Opt('$i', s(v[i]))];
    return const [];
  }

  Future<void> _meta() async {
    setState(() {
      _metaLoading = true;
      _error = null;
    });
    try {
      final res = await widget.args.api.get('/transportation/van_wise_report');
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      final d = m(res['data']);
      _vans = _opts(d['ddVan']);
      _shifts = _opts(d['ddShift']);
      _routes = _opts(d['ddRoute']);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the filters. Try again.';
    }
    if (mounted) setState(() => _metaLoading = false);
  }

  Future<void> _show() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.args.api.get('/transportation/van_wise_report/create', query: {
        'pickup': _run,
        if (_van != null) 'van': _van,
        if (_shift != null) 'shift': _shift,
        if (_route != null) 'route': _route,
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      _all = rows(res['data']);
      // Group by van so each van's students sit together.
      _all.sort((a, b) => '${s(a['bus_name'])}|${s(a['shift_title'])}'.compareTo('${s(b['bus_name'])}|${s(b['shift_title'])}'));
      _searched = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the report. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _shown {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return [for (final r in _all) if ('${r['name']} ${r['enrollment_no']} ${r['stddiv']} ${r['route_name']} ${r['bus_name']}'.toLowerCase().contains(q)) r];
  }

  num _amount(Map<String, dynamic> r) => num.tryParse(s(r['van_vise_amount'])) ?? 0;

  @override
  Widget build(BuildContext context) {
    final title = widget.args.item.label.isEmpty ? 'Van Wise Report' : widget.args.item.label;
    if (_metaLoading) return KitPage(title: title, child: const AppLoader());
    if (_error != null && !_searched && _vans.isEmpty && _shifts.isEmpty) {
      return KitPage(title: title, child: KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _meta));
    }
    final shown = _shown;
    final vans = _all.map((r) => '${s(r['bus_name'])}|${s(r['shift_title'])}').toSet().length;
    final total = _all.fold<num>(0, (a, r) => a + _amount(r));
    return KitPage(
      title: title,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: 1 + (!_searched || _loading || shown.isEmpty || _error != null ? 1 : shown.length),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CHero(
                icon: Icons.directions_bus_rounded,
                title: _run == 'pickup' ? 'Pickup run' : 'Drop run',
                subtitle: 'Students on each van',
                stats: _searched ? [('Students', '${_all.length}'), ('Vans', '$vans'), if (total > 0) ('Amount', '₹${total.toStringAsFixed(0)}')] : const [],
              ),
              gap(12),
              _filters(),
              if (_searched && _all.isNotEmpty) ...[gap(12), CSearchBox(hint: 'Find a student, GR, route or van', onChanged: (v) => setState(() => _q = v))],
              gap(12),
            ]);
          }
          if (_loading) return const Padding(padding: EdgeInsets.only(top: 40), child: const AppLoader());
          if (_error != null) return KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _show);
          if (!_searched) return const Padding(padding: EdgeInsets.only(top: 30), child: KitMessage(icon: Icons.directions_bus_outlined, text: 'Choose a van, shift or route (or leave them empty for all) and tap Show.'));
          if (shown.isEmpty) return const Padding(padding: EdgeInsets.only(top: 30), child: KitMessage(icon: Icons.people_outline, text: 'No students found.'));
          final r = shown[i - 1];
          final key = '${s(r['bus_name'])}|${s(r['shift_title'])}';
          final prev = i - 2 >= 0 ? shown[i - 2] : null;
          final newGroup = prev == null || '${s(prev['bus_name'])}|${s(prev['shift_title'])}' != key;
          final groupCount = shown.where((x) => '${s(x['bus_name'])}|${s(x['shift_title'])}' == key).length;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (newGroup) _groupHeader(s(r['bus_name']), s(r['shift_title']), groupCount),
            _card(r),
          ]);
        },
      ),
    );
  }

  Widget _filters() => SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'pickup', label: Text('Pickup'), icon: Icon(Icons.north_east_rounded, size: 16)),
                ButtonSegment(value: 'drop', label: Text('Drop'), icon: Icon(Icons.south_west_rounded, size: 16)),
              ],
              selected: {_run},
              onSelectionChanged: (v) => setState(() => _run = v.first),
            ),
          ),
          gap(12),
          DropdownField(label: 'Van (all)', options: _vans, value: _van, onChanged: (v) => setState(() => _van = v)),
          gap(10),
          Row(children: [
            Expanded(child: DropdownField(label: 'Shift (all)', options: _shifts, value: _shift, onChanged: (v) => setState(() => _shift = v))),
            const SizedBox(width: 10),
            Expanded(child: DropdownField(label: 'Route (all)', options: _routes, value: _route, onChanged: (v) => setState(() => _route = v))),
          ]),
          if (_van != null || _shift != null || _route != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => setState(() => _van = _shift = _route = null), child: const Text('Clear filters')),
            ),
          gap(6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: _loading ? null : _show,
              icon: const Icon(Icons.search_rounded),
              label: Text(_loading ? 'Loading…' : 'Show report'),
            ),
          ),
        ]),
      );

  Widget _groupHeader(String bus, String shift, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Row(children: [
          const IconTile(Icons.directions_bus_rounded, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text([bus, shift].where((e) => e.isNotEmpty).join('  ·  '), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          ),
          Tag('$count student${count == 1 ? '' : 's'}'),
        ]),
      );

  Widget _card(Map<String, dynamic> r) {
    final mobile = s(r['mobile']);
    final amount = _amount(r);
    final from = s(r['from_stop_name']);
    final to = s(r['to_stop_name']);
    final crew = [if (s(r['driver']).isNotEmpty) 'Driver ${s(r['driver'])}', if (s(r['conductor']).isNotEmpty) 'Conductor ${s(r['conductor'])}'].join('   ·   ');
    final dates = [if (s(r['start_date']).isNotEmpty) 'From ${s(r['start_date'])}', if (s(r['end_date']).isNotEmpty) 'to ${s(r['end_date'])}'].join(' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PersonAvatar(url: '', name: s(r['name']), radius: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s(r['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                Text([if (s(r['enrollment_no']).isNotEmpty) 'GR ${s(r['enrollment_no'])}', s(r['stddiv'])].where((e) => e.isNotEmpty).join('  ·  '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted, fontSize: 12)),
              ]),
            ),
            if (amount > 0) Text('₹${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}', style: TextStyle(fontWeight: FontWeight.w800, color: Brand.primaryDark)),
          ]),
          const SizedBox(height: 6),
          CInfoLine(Icons.alt_route_rounded, s(r['route_name'])),
          CInfoLine(Icons.place_outlined, [if (from.isNotEmpty) from, if (to.isNotEmpty) to].join('  →  ')),
          CInfoLine(Icons.badge_outlined, crew),
          CInfoLine(Icons.date_range_outlined, dates),
          CInfoLine(Icons.home_outlined, s(r['address'])),
          if (mobile.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: () => openUrl(context, 'tel:$mobile'), icon: const Icon(Icons.call_rounded, size: 17), label: Text(mobile)),
            ),
        ]),
      ),
    );
  }
}
