import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../update_fees_breakoff/update_fees_breakoff_controller.dart';

/// State and API calls for adding a Fees BreakOff structure (same steps as the web): pick sections, standards
/// and months, generate the quota x fee-head grid, fill in the amounts, save.
class FeesBreakoffController extends ChangeNotifier {
  FeesBreakoffController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const _path = '/fees/fees_breackoff';

  bool loading = true;
  bool busy = false;
  String? error;

  List<Opt> sections = [];
  List<Opt> standards = [];
  List<Opt> months = [];

  final selectedSections = <String>{};
  final selectedStandards = <String>{};
  final selectedMonths = <String>{};

  List<(String, String)> titles = [];
  List<(String, String)> quotas = [];
  BreakoffMatrix? newValues;
  BreakoffMatrix? oldValues;
  bool get generated => newValues != null;

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final sec = await _api.post('/get_adminAcademicSection');
      sections = [
        for (final r in rows(sec['data']))
          if (s(r['id']).isNotEmpty) Opt(s(r['id']), s(r['title']).isNotEmpty ? s(r['title']) : (s(r['short_name']).isNotEmpty ? s(r['short_name']) : s(r['name']))),
      ];
      final res = await _api.get('$_path/create');
      final dd = m(m(res['data'])['ddMonth']);
      months = [for (final e in dd.entries) Opt(e.key, s(e.value).isEmpty ? e.key : s(e.value))];
      if (months.isEmpty && statusOf(res) == '0') error = LegacyApi.messageOf(res, 'Please map fees year first.');
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _resetGrid() {
    newValues?.dispose();
    oldValues?.dispose();
    newValues = null;
    oldValues = null;
  }

  Future<void> toggleSection(String id) async {
    selectedSections.contains(id) ? selectedSections.remove(id) : selectedSections.add(id);
    selectedStandards.clear();
    _resetGrid();
    notifyListeners();
    await _loadStandards();
  }

  Future<void> _loadStandards() async {
    if (selectedSections.isEmpty) {
      standards = [];
      notifyListeners();
      return;
    }
    try {
      final seen = <String, Opt>{};
      for (final g in selectedSections) {
        final res = await _api.post('/get_adminStandard', body: {'grade_id': g});
        for (final r in rows(res['data'])) {
          final id = s(r['id']);
          if (id.isEmpty || seen.containsKey(id)) continue;
          seen[id] = Opt(id, s(r['name']).isNotEmpty ? s(r['name']) : s(r['short_name']));
        }
      }
      standards = seen.values.toList();
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  void toggleStandard(String id) {
    selectedStandards.contains(id) ? selectedStandards.remove(id) : selectedStandards.add(id);
    _resetGrid();
    notifyListeners();
  }

  void toggleMonth(String id) {
    selectedMonths.contains(id) ? selectedMonths.remove(id) : selectedMonths.add(id);
    _resetGrid();
    notifyListeners();
  }

  String? validateSelection() {
    if (selectedSections.isEmpty || selectedStandards.isEmpty || selectedMonths.isEmpty) return 'Select grade, standard, and at least one month.';
    return null;
  }

  Map<String, dynamic> _selectionBody() {
    final b = <String, dynamic>{};
    var i = 0;
    for (final g in selectedSections) {
      b['grade[${i++}]'] = g;
    }
    i = 0;
    for (final st in selectedStandards) {
      b['standard[${i++}]'] = st;
    }
    for (final mo in selectedMonths) {
      b['month[$mo]'] = mo;
    }
    return b;
  }

  BreakoffMatrix _empty() => BreakoffMatrix({
        for (final q in quotas) q.$1: {for (final t in titles) t.$1: TextEditingController()},
      });

  Future<void> generate() async {
    busy = true;
    error = null;
    _resetGrid();
    notifyListeners();
    try {
      final res = await _api.post(_path, body: _selectionBody());
      final data = m(res['data']);
      if (data['title_arr'] == null) {
        error = LegacyApi.messageOf(res, "Couldn't prepare fee breakoff. Try again.");
      } else {
        titles = [for (final e in m(data['title_arr']).entries) (e.key, s(e.value))];
        quotas = [for (final e in m(data['quota_arr']).entries) (e.key, s(e.value))];
        newValues = _empty();
        oldValues = _empty();
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void changed() => notifyListeners();

  String? validateAmounts() {
    for (final entry in {'New student': newValues!, 'Old student': oldValues!}.entries) {
      for (final q in entry.value.cells.values) {
        for (final c in q.values) {
          final t = c.text.trim();
          if (t.isNotEmpty && (num.tryParse(t) == null || num.parse(t) < 0)) return '${entry.key}: "$t" is not a valid amount.';
        }
      }
    }
    return null;
  }

  Future<(bool, String)> save() async {
    busy = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{'action': 'insert', ..._selectionBody()};
      void put(String bucket, BreakoffMatrix mx) {
        for (final q in mx.cells.entries) {
          for (final t in q.value.entries) {
            body['$bucket[${q.key}][${t.key}]'] = t.value.text.trim();
          }
        }
      }

      put('NewValues', newValues!);
      put('OldValues', oldValues!);
      final res = await _api.post(_path, body: body);
      final ok = statusOf(res) == '1';
      return (ok, LegacyApi.messageOf(res, ok ? 'Fee breakoff saved.' : "Couldn't save fee breakoff. Try again."));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _resetGrid();
    super.dispose();
  }
}
