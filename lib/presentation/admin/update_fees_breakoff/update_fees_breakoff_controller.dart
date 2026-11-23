import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// The fee structure of one class and month: amount per student quota per fee head, for new and old students.
class BreakoffMatrix {
  BreakoffMatrix(this.cells);

  /// quota id -> fee-title id -> amount field.
  final Map<String, Map<String, TextEditingController>> cells;

  void dispose() {
    for (final row in cells.values) {
      for (final c in row.values) {
        c.dispose();
      }
    }
  }
}

/// State and API calls for Update Fees BreckOff (same steps as the web): pick a class and billing month,
/// load its editable structure, change amounts, and submit.
class UpdateFeesBreakoffController extends ChangeNotifier {
  UpdateFeesBreakoffController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const _path = '/fees/update_fees_breackoff_api';

  List<Opt> months = [];
  bool loadingMonths = true;
  bool busy = false;
  String? error;

  CascadeSelection cascade = CascadeSelection();
  String? month;

  List<(String, String)> titles = [];
  List<(String, String)> quotas = [];
  BreakoffMatrix? current; // new students
  BreakoffMatrix? previous; // old students
  Set<String> paidCurrent = {};
  Set<String> paidPrevious = {};
  bool get loaded => current != null;

  Future<void> loadMonths() async {
    loadingMonths = true;
    error = null;
    notifyListeners();
    try {
      // The web tolerates status 0 here: the month list is in the payload either way.
      final res = await _api.get(_path);
      final dd = m(m(res['data'])['ddMonth']);
      months = [for (final e in dd.entries) Opt(e.key, s(e.value).isEmpty ? e.key : s(e.value))];
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loadingMonths = false;
      notifyListeners();
    }
  }

  void setCascade(CascadeSelection c) {
    cascade = c;
    _clear();
    notifyListeners();
  }

  void setMonth(String? v) {
    month = v;
    _clear();
    notifyListeners();
  }

  void _clear() {
    current?.dispose();
    previous?.dispose();
    current = null;
    previous = null;
    paidCurrent = {};
    paidPrevious = {};
  }

  String? validateSearch() {
    if (cascade.sectionId == null || cascade.standardId == null || (month ?? '').isEmpty) return 'Select Grade, Standard, and Month.';
    return null;
  }

  List<(String, String)> _pairs(dynamic v) => [for (final e in m(v).entries) (e.key, s(e.value))];

  BreakoffMatrix _matrix(dynamic v) {
    final src = m(v);
    return BreakoffMatrix({
      for (final q in quotas)
        q.$1: {
          for (final t in titles) t.$1: TextEditingController(text: s(m(src[q.$1])[t.$1])),
        },
    });
  }

  Future<void> search() async {
    busy = true;
    error = null;
    _clear();
    notifyListeners();
    try {
      final res = await _api.post(_path, body: {'grade': cascade.sectionId, 'standard': cascade.standardId, 'month_id': month});
      final data = m(res['data']);
      if (data.isEmpty) {
        error = LegacyApi.messageOf(res, "Couldn't load fee structure. Try again.");
      } else {
        titles = _pairs(data['title_arr']);
        quotas = _pairs(data['quota_arr']);
        final bk = m(data['bk_arr']);
        final paid = m(data['paid_arr']);
        current = _matrix(bk['new']);
        previous = _matrix(bk['old']);
        paidCurrent = m(paid['new']).keys.toSet();
        paidPrevious = m(paid['old']).keys.toSet();
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  num total(BreakoffMatrix mx, String quota) =>
      mx.cells[quota]?.values.fold<num>(0, (a, c) => a + (num.tryParse(c.text.trim()) ?? 0)) ?? 0;

  void changed() => notifyListeners();

  /// The first invalid amount, or null.
  String? validateAmounts() {
    for (final entry in {'New student': current!, 'Old student': previous!}.entries) {
      for (final q in entry.value.cells.entries) {
        for (final c in q.value.values) {
          final t = c.text.trim();
          if (t.isNotEmpty && (num.tryParse(t) == null || num.parse(t) < 0)) return '${entry.key}: "$t" is not a valid amount.';
        }
      }
    }
    return null;
  }

  Future<(bool, String)> submit() async {
    busy = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'action': 'insert',
        'grade': cascade.sectionId,
        'standard': cascade.standardId,
        'month_id': month,
      };
      void put(String bucket, BreakoffMatrix mx) {
        for (final q in mx.cells.entries) {
          for (final t in q.value.entries) {
            body['$bucket[${q.key}][${t.key}]'] = t.value.text.trim();
          }
        }
      }

      put('NewValues', current!);
      put('OldValues', previous!);
      final res = await _api.post(_path, body: body);
      final ok = statusOf(res) == '1';
      return (ok, LegacyApi.messageOf(res, ok ? 'Data Update Successfully' : 'Could not update fees structure.'));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void resetAfterSave() {
    _clear();
    month = null;
    notifyListeners();
  }

  @override
  void dispose() {
    current?.dispose();
    previous?.dispose();
    super.dispose();
  }
}
