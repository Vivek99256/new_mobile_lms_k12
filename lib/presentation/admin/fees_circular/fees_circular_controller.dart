import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class CircularStudent {
  CircularStudent(Map<String, dynamic> row)
      : id = s(_stu(row)['student_id'] ?? _stu(row)['id']),
        enrollmentNo = s(_stu(row)['enrollment'] ?? _stu(row)['enrollment_no']),
        name = _name(_stu(row)),
        stdDiv = s(_stu(row)['stddiv']).isNotEmpty
            ? s(_stu(row)['stddiv'])
            : [s(_stu(row)['standard_name']), s(_stu(row)['division_name'])].where((e) => e.isNotEmpty).join('/'),
        pending = num.tryParse(s(_stu(row)['pending'] ?? row['pending']).replaceAll(',', '')) ?? 0;

  final String id, enrollmentNo, name, stdDiv;
  final num pending;

  static Map<String, dynamic> _stu(Map<String, dynamic> row) => row['stu_data'] is Map && (row['stu_data'] as Map).isNotEmpty ? m(row['stu_data']) : row;

  static String _name(Map<String, dynamic> st) {
    final n = s(st['name']);
    if (n.isNotEmpty) return n.replaceAll(RegExp(r'\s+'), ' ');
    return [st['first_name'], st['middle_name'], st['last_name']].map(s).where((e) => e.isNotEmpty).join(' ');
  }
}

/// One student's generated circular: the fee heads and the total.
class GeneratedCircular {
  GeneratedCircular({required this.id, required this.name, required this.enrollmentNo, required this.cls, required this.heads, required this.total, this.otherMonths = const []});
  final String id, name, enrollmentNo, cls;
  final List<(String, num)> heads;
  final num total;

  /// Months (not selected) in which this student does have a fee, e.g. "Jul 2022": shown when the chosen months come to 0.
  final List<String> otherMonths;
}

/// State and API calls for Fees Circular (same workflow as the web): pick class, months and receipt book,
/// find students, then generate circulars.
class FeesCircularController extends ChangeNotifier {
  FeesCircularController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  bool loadingFilters = true;
  bool busy = false;
  String? error;

  // Filters loaded from the server.
  List<Opt> months = [];
  List<Opt> receiptBooks = [];

  // Choices.
  CascadeSelection cascade = CascadeSelection();
  final selectedMonths = <String>{};
  String? receiptId;

  // Students.
  List<CircularStudent> students = [];
  final selectedStudents = <String>{};
  bool searched = false;

  // Result.
  List<GeneratedCircular> generated = [];
  String html = '';
  String resultMessage = '';

  void _fail(String? msg) {
    error = msg;
  }

  Future<void> loadFilters() async {
    loadingFilters = true;
    _fail(null);
    notifyListeners();
    try {
      final res = await _api.post('/api/fees-circular/filters');
      if (statusOf(res) != '1') {
        _fail(LegacyApi.messageOf(res, 'Could not load the circular filters.'));
      } else {
        months = _monthOpts(res['months']);
        receiptBooks = [
          for (final r in rows(res['receipt_books']))
            if ((s(r['receipt_id']).isNotEmpty ? s(r['receipt_id']) : s(r['id'])).isNotEmpty)
              Opt(s(r['receipt_id']).isNotEmpty ? s(r['receipt_id']) : s(r['id']),
                  s(r['receipt_line_1']).isNotEmpty ? s(r['receipt_line_1']) : (s(r['name']).isNotEmpty ? s(r['name']) : 'Receipt book ${s(r['id'])}')),
        ];
        if (receiptBooks.length == 1) receiptId = receiptBooks.first.id;
      }
    } on ApiException catch (e) {
      _fail(e.message);
    } finally {
      loadingFilters = false;
      notifyListeners();
    }
  }

  List<Opt> _monthOpts(dynamic v) {
    if (v is List) {
      return [
        for (var i = 0; i < v.length; i++)
          if (v[i] is Map)
            Opt(
              s((v[i] as Map)['id'] ?? (v[i] as Map)['month_id'] ?? (v[i] as Map)['value']).isEmpty ? '$i' : s((v[i] as Map)['id'] ?? (v[i] as Map)['month_id'] ?? (v[i] as Map)['value']),
              s((v[i] as Map)['name'] ?? (v[i] as Map)['label'] ?? (v[i] as Map)['month']),
            ),
      ];
    }
    if (v is Map) return [for (final e in v.entries) Opt('${e.key}', s(e.value).isEmpty ? '${e.key}' : s(e.value))];
    return [];
  }

  void setCascade(CascadeSelection c) {
    cascade = c;
    students = [];
    selectedStudents.clear();
    searched = false;
    notifyListeners();
  }

  void toggleMonth(String id) {
    selectedMonths.contains(id) ? selectedMonths.remove(id) : selectedMonths.add(id);
    notifyListeners();
  }

  void setReceipt(String? id) {
    receiptId = id;
    notifyListeners();
  }

  /// null when the choices are enough to search.
  String? validateSearch() {
    if (cascade.sectionId == null) return 'Please select a section.';
    if (cascade.standardId == null) return 'Please select a standard.';
    if (selectedMonths.isEmpty) return 'Please select at least one month.';
    if ((receiptId ?? '').isEmpty) return 'Please select a receipt book.';
    return null;
  }

  Future<void> searchStudents() async {
    busy = true;
    searched = true;
    students = [];
    selectedStudents.clear();
    _fail(null);
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'grade': cascade.sectionId,
        'standard': cascade.standardId,
        if (cascade.divisionId != null) 'division': cascade.divisionId,
        'receipt_id': receiptId,
        for (var i = 0; i < selectedMonths.length; i++) 'month[$i]': selectedMonths.elementAt(i),
      };
      final res = await _api.post('/api/fees-circular/students', body: body);
      if (statusOf(res) != '1') {
        _fail(LegacyApi.messageOf(res, 'No students found.'));
      } else {
        final d = res['data'];
        final list = d is List ? rows(d) : (d is Map ? rows(d.values.toList()) : <Map<String, dynamic>>[]);
        students = list.map(CircularStudent.new).where((st) => st.id.isNotEmpty).toList();
      }
    } on ApiException catch (e) {
      _fail(e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void toggleStudent(String id) {
    selectedStudents.contains(id) ? selectedStudents.remove(id) : selectedStudents.add(id);
    notifyListeners();
  }

  void toggleAll() {
    if (selectedStudents.length == students.length) {
      selectedStudents.clear();
    } else {
      selectedStudents
        ..clear()
        ..addAll(students.map((e) => e.id));
    }
    notifyListeners();
  }

  Future<bool> generate() async {
    busy = true;
    _fail(null);
    notifyListeners();
    try {
      final chosen = selectedStudents.toList();
      final body = <String, dynamic>{
        'month': selectedMonths.join(','),
        'receipt_id': receiptId,
        'grade_id': cascade.sectionId,
        'standard_id': cascade.standardId,
        for (var i = 0; i < chosen.length; i++) 'students[$i]': chosen[i],
      };
      final res = await _api.post('/api/fees-circular/generate', body: body);
      if (statusOf(res) != '1') {
        _fail(LegacyApi.messageOf(res, "Couldn't generate fee circulars. Try again."));
        return false;
      }
      resultMessage = LegacyApi.messageOf(res, 'Fee circulars generated successfully.');
      html = _html(res);
      final breakoff = m(res['breakoff']);
      final d = res['data'];
      final list = d is List ? rows(d) : (d is Map ? rows(d.values.toList()) : <Map<String, dynamic>>[]);
      generated = [
        for (final r in list)
          () {
            final id = s(r['id']);
            final heads = [for (final e in m(breakoff[id]).entries) (e.key, num.tryParse(s(e.value).replaceAll(',', '')) ?? 0)];
            final override = s(m(res['fees_circular_amount'])[id]);
            final total = override.isNotEmpty ? (num.tryParse(override) ?? 0) : heads.fold<num>(0, (a, h) => a + h.$2);
            return GeneratedCircular(
              id: id,
              name: '${s(r['student_name'])} ${s(r['surname'])}'.replaceAll(RegExp(r'\s+'), ' ').trim(),
              enrollmentNo: s(r['enrollment_no']),
              cls: [s(r['standard_name']), s(r['division_name'])].where((e) => e.isNotEmpty).join(' - '),
              heads: heads,
              total: total,
              otherMonths: total == 0 ? _monthsWithFee(r, selectedMonths) : const [],
            );
          }(),
      ];
      return true;
    } on ApiException catch (e) {
      _fail(e.message);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Month keys look like 72022 (month 7, year 2022). Lists those that carry a fee and were not selected.
  static List<String> _monthsWithFee(Map<String, dynamic> row, Set<String> selected) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final out = <String>[];
    for (final e in m(row['breakoff']).entries) {
      if (selected.contains(e.key)) continue;
      final heads = e.value is Map ? (e.value as Map).values : (e.value is List ? e.value as List : const []);
      final sum = heads.fold<num>(0, (a, h) => a + (h is Map ? (num.tryParse(s(h['amount'])) ?? 0) : 0));
      if (sum <= 0) continue;
      final k = int.tryParse(e.key);
      if (k == null) continue;
      final month = k ~/ 10000;
      if (month < 1 || month > 12) continue;
      out.add('${names[month - 1]} ${e.key.substring(e.key.length - 4)}');
    }
    return out;
  }

  String _html(Map<String, dynamic> res) {
    for (final src in [res, m(res['data'])]) {
      for (final k in const ['html', 'str', 'circular_html', 'fees_circular_html', 'challan_html', 'print_html']) {
        final v = s(src[k]);
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }
}
