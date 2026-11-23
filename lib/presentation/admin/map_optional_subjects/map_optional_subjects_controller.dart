import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class OptionalStudent {
  OptionalStudent(this.id, this.name, this.gr);
  final String id;
  final String name;
  final String gr;
}

/// State and API calls for Map Optional Subjects (same calls as the web page):
/// `student-optional-subject/search` for students, elective subjects and the current mapping,
/// `student-optional-subject` (PUT) to save.
class MapOptionalSubjectsController extends ChangeNotifier {
  MapOptionalSubjectsController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const allDivisions = '__all__';

  List<Opt> sections = [], standards = [], divisions = [];
  String? section, standard, division;
  bool loadingSections = true, loadingStandards = false, loadingDivisions = false;

  bool searching = false;
  bool saving = false;
  bool searched = false;
  String? error;

  List<OptionalStudent> students = [];
  List<Opt> subjects = [];

  /// Mapping as loaded from the server and as edited: student id -> subject ids.
  Map<String, Set<String>> original = {};
  Map<String, Set<String>> mapped = {};

  Future<List<Map<String, dynamic>>> _list(String path, [Map<String, dynamic> body = const {}]) async {
    try {
      final res = await _api.post(path, body: body);
      return LegacyApi.ok(res) ? rows(res['data']) : const [];
    } on ApiException catch (e) {
      error = e.message;
      return const [];
    }
  }

  Future<void> loadSections() async {
    final r = await _list('/get_adminAcademicSection');
    sections = [for (final x in r) Opt(s(x['id']), s(x['short_name']).isEmpty ? s(x['title']) : s(x['short_name']))];
    loadingSections = false;
    notifyListeners();
  }

  void _reset() {
    searched = false;
    students = [];
    subjects = [];
    original = {};
    mapped = {};
    error = null;
  }

  Future<void> pickSection(String? id) async {
    section = id;
    standard = null;
    division = null;
    standards = [];
    divisions = [];
    _reset();
    loadingStandards = id != null;
    notifyListeners();
    if (id == null) return;
    final r = await _list('/get_adminStandard', {'grade_id': id});
    standards = [for (final x in r) Opt(s(x['id']), s(x['name']))];
    loadingStandards = false;
    notifyListeners();
  }

  Future<void> pickStandard(String? id) async {
    standard = id;
    division = null;
    divisions = [];
    _reset();
    loadingDivisions = id != null;
    notifyListeners();
    if (id == null) return;
    final r = await _list('/get_adminDivision', {'standard_id': id});
    divisions = [for (final x in r) Opt(s(x['id']), s(x['name']))];
    loadingDivisions = false;
    notifyListeners();
  }

  void pickDivision(String? id) {
    division = id;
    _reset();
    notifyListeners();
  }

  List<Opt> get divisionOptions => [if (divisions.length > 1) const Opt(allDivisions, 'All divisions'), ...divisions];

  bool get canSearch => standard != null && divisions.isNotEmpty && !searching;

  Future<void> search() async {
    searching = true;
    error = null;
    notifyListeners();
    try {
      final ids = division == null || division == allDivisions ? [for (final d in divisions) d.id] : [division!];
      final byStudent = <String, OptionalStudent>{};
      final bySubject = <String, Opt>{};
      final map = <String, Set<String>>{};
      for (final id in ids) {
        final res = await _api.post('/student-optional-subject/search', body: {'standard': standard, 'division': id});
        if (statusOf(res) != '1') throw ApiException(LegacyApi.messageOf(res, 'Search failed.'));
        for (final r in rows(res['data'])) {
          byStudent[s(r['id'])] = OptionalStudent(s(r['id']), s(r['student_name']), s(r['enrollment_no']));
        }
        for (final r in rows(res['subjects'])) {
          final code = s(r['subject_code']);
          bySubject[s(r['id'])] = Opt(s(r['id']), '${s(r['subject_name'])}${code.isEmpty ? '' : ' ($code)'}');
        }
        // `mapped` is an object keyed by student id (an empty list when nothing is mapped).
        final mp = res['mapped'];
        if (mp is Map) {
          mp.forEach((k, v) => map['$k'] = {if (v is List) for (final x in v) s(x)});
        }
      }
      students = byStudent.values.toList();
      subjects = bySubject.values.toList();
      mapped = {for (final st in students) st.id: {...?map[st.id]}};
      original = {for (final e in mapped.entries) e.key: {...e.value}};
      searched = true;
    } on ApiException catch (e) {
      error = e.message;
      searched = false;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  bool has(String studentId, String subjectId) => mapped[studentId]?.contains(subjectId) ?? false;

  void toggle(String studentId, String subjectId) {
    final set = mapped.putIfAbsent(studentId, () => {});
    set.contains(subjectId) ? set.remove(subjectId) : set.add(subjectId);
    notifyListeners();
  }

  bool allHave(String subjectId, Iterable<OptionalStudent> list) => list.isNotEmpty && list.every((st) => has(st.id, subjectId));

  void toggleAll(String subjectId, Iterable<OptionalStudent> list) {
    final check = !allHave(subjectId, list);
    for (final st in list) {
      final set = mapped.putIfAbsent(st.id, () => {});
      check ? set.add(subjectId) : set.remove(subjectId);
    }
    notifyListeners();
  }

  bool _same(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  List<OptionalStudent> get changed =>
      [for (final st in students) if (!_same(mapped[st.id] ?? {}, original[st.id] ?? {})) st];

  /// Saves the students whose choice changed; returns the server message and whether it worked.
  Future<(bool, String)> save() async {
    final list = changed;
    if (list.isEmpty) return (false, 'No changes to save.');
    saving = true;
    notifyListeners();
    try {
      // The route is PUT with a JSON array; a multipart POST with _method=PUT and bracketed fields
      // reaches the same controller and builds the same `assignments` array.
      final body = <String, dynamic>{'_method': 'PUT'};
      for (var i = 0; i < list.length; i++) {
        body['assignments[$i][student_id]'] = list[i].id;
        var j = 0;
        for (final sub in mapped[list[i].id] ?? <String>{}) {
          body['assignments[$i][subject_ids][${j++}]'] = sub;
        }
      }
      final res = await _api.post('/student-optional-subject', body: body);
      final ok = statusOf(res) == '1';
      if (ok) original = {for (final e in mapped.entries) e.key: {...e.value}};
      return (ok, LegacyApi.messageOf(res, ok ? 'Optional subjects mapped successfully.' : 'Could not save the mapping.'));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
