import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/api_client.dart';
import '../../../core/config.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class BulkField {
  const BulkField(this.key, this.label, this.type);
  final String key;
  final String label;

  /// text | email | date | select
  final String type;
}

/// State and API calls for Bulk Student Update:
/// `GET bulk-students/metadata`, `POST bulk-students/search`, `PUT bulk-students` (JSON body).
class BulkStudentUpdateController extends ChangeNotifier {
  BulkStudentUpdateController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const defaultFields = ['enrollment_no', 'first_name', 'last_name', 'roll_no'];
  static const orderOptions = [
    Opt('student_name', 'Student name'),
    Opt('standard_id', 'Standard'),
    Opt('enrollment_no', 'GR no.'),
    Opt('roll_no', 'Roll no.'),
    Opt('last_name', 'Last name'),
  ];

  List<BulkField> fields = [];
  Map<String, List<Opt>> options = {};
  List<String> selected = [];
  CascadeSelection cascade = CascadeSelection();
  String orderBy = 'student_name';

  bool loading = true, searching = false, saving = false;
  String? error;

  /// Result rows: `id`, `student_name`, `updated_on` and one entry per searched field. Edited in place.
  List<Map<String, String>> students = [];
  final Map<String, Map<String, String>> _original = {};
  final Map<String, TextEditingController> _text = {};

  /// Ids of students whose values differ from what the server gave. Kept up to date as cells change, so the screen
  /// never has to compare every student on every key press.
  final Set<String> _dirty = {};
  List<String> searchedFields = [];
  bool searched = false;

  BulkField? fieldOf(String key) => fields.where((f) => f.key == key).firstOrNull;
  List<BulkField> get searchedDefs => [for (final k in searchedFields) ?fieldOf(k)];

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get('/bulk-students/metadata');
      if (statusOf(res) != '1') throw ApiException(LegacyApi.messageOf(res, "Couldn't load bulk update. Try again."));
      final d = m(res['data']);
      fields = [
        for (final r in rows(d['fields']))
          if (s(r['key']).isNotEmpty) BulkField(s(r['key']), s(r['label']), s(r['type'])),
      ];
      options = {
        for (final e in m(d['options']).entries) e.key: [for (final o in rows(e.value)) Opt(s(o['id']), s(o['label']))],
      };
      if (selected.isEmpty) selected = [for (final k in defaultFields) if (fieldOf(k) != null) k];
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  void setOrder(String? v) {
    orderBy = v ?? 'student_name';
    notifyListeners();
  }

  void toggleField(String key) {
    selected.contains(key) ? selected.remove(key) : selected.add(key);
    notifyListeners();
  }

  void toggleAllFields() {
    selected = selected.length == fields.length ? [] : [for (final f in fields) f.key];
    notifyListeners();
  }

  void _clearRows() {
    for (final c in _text.values) {
      c.dispose();
    }
    _text.clear();
    _original.clear();
    _dirty.clear();
    students = [];
  }

  Future<void> search() async {
    if (selected.isEmpty) {
      error = 'Select at least one field to update.';
      notifyListeners();
      return;
    }
    searching = true;
    error = null;
    notifyListeners();
    try {
      final fieldsNow = [for (final f in fields) if (selected.contains(f.key)) f.key];
      final res = await _api.post('/bulk-students/search', body: {
        if (cascade.sectionId != null) 'grade': cascade.sectionId,
        if (cascade.standardId != null) 'standard': cascade.standardId,
        if (cascade.divisionId != null) 'division': cascade.divisionId,
        'order_by': orderBy,
        for (var i = 0; i < fieldsNow.length; i++) 'fields[$i]': fieldsNow[i],
      });
      if (statusOf(res) != '1') throw ApiException(LegacyApi.messageOf(res, "Couldn't search students. Try again."));
      _clearRows();
      for (final r in rows(m(res['data'])['students'])) {
        final row = {for (final e in r.entries) e.key: s(e.value)};
        students.add(row);
        _original[row['id'] ?? ''] = {for (final k in fieldsNow) k: row[k] ?? ''};
      }
      searchedFields = fieldsNow;
      searched = true;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  /// A text box for one cell, kept alive while the result is on screen.
  TextEditingController textFor(Map<String, String> row, String field) =>
      _text.putIfAbsent('${row['id']}|$field', () => TextEditingController(text: row[field] ?? ''));

  void setValue(Map<String, String> row, String field, String value, {bool notify = false}) {
    row[field] = value;
    final before = isDirty(row);
    _refreshDirty(row);
    // Typing only redraws the screen when a student turns edited / unedited; a plain key press repaints nothing else.
    if (notify || before != isDirty(row)) notifyListeners();
  }

  void _refreshDirty(Map<String, String> row) {
    final id = row['id'] ?? '';
    final o = _original[id];
    final changed = o != null && searchedFields.any((k) => (row[k] ?? '') != (o[k] ?? ''));
    changed ? _dirty.add(id) : _dirty.remove(id);
  }

  /// Tapping a date cell: update the row and the visible text.
  void setDate(Map<String, String> row, String field, String value) {
    row[field] = value;
    textFor(row, field).text = value;
    _refreshDirty(row);
    notifyListeners();
  }

  bool isDirty(Map<String, String> row) => _dirty.contains(row['id'] ?? '');

  int get dirtyCount => _dirty.length;

  List<Map<String, String>> get dirtyRows => [for (final r in students) if (isDirty(r)) r];

  /// Saves only the rows that were changed. Returns (ok, message).
  Future<(bool, String)> save() async {
    final changed = dirtyRows;
    if (changed.isEmpty) return (false, 'No changes to save.');
    saving = true;
    notifyListeners();
    try {
      final session = args.session;
      final payload = {
        'type': 'API',
        'token': session.token,
        'sub_institute_id': session.subInstituteId,
        'syear': syearOf(session),
        'user_id': session.userId,
        'students': [
          for (final r in changed)
            {
              'id': r['id'],
              'values': {for (final k in searchedFields) k: r[k] ?? ''},
            },
        ],
      };
      final res = await _putJson('/bulk-students', payload);
      final ok = statusOf(res) == '1';
      if (ok) {
        for (final r in changed) {
          _original[r['id'] ?? ''] = {for (final k in searchedFields) k: r[k] ?? ''};
          _dirty.remove(r['id'] ?? '');
        }
      }
      return (ok, LegacyApi.messageOf(res, ok ? 'Students updated successfully.' : "Couldn't update students. Try again."));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// PUT with a JSON body (the form has too many fields for a query string).
  Future<Map<String, dynamic>> _putJson(String path, Map<String, dynamic> body) async {
    final req = http.Request('PUT', Uri.parse('${AppConfig.apiBase}$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${args.session.token}',
      })
      ..body = jsonEncode(body);
    final http.Response res;
    try {
      final c = AdminHttp.client ?? http.Client();
      res = await http.Response.fromStream(await c.send(req)).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Try again.');
    } catch (_) {
      throw ApiException('Check your internet connection and try again.');
    }
    if (res.statusCode >= 500) throw ApiException('The server had a problem. Try again shortly.');
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw ApiException('The server returned an unexpected response.', statusCode: res.statusCode);
    }
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'data': decoded};
    if (statusOf(map) == '2') {
      throw ApiException('${map['message'] ?? 'Your session has expired. Sign in again.'}', statusCode: 401);
    }
    return map;
  }

  String originalOf(Map<String, String> row, String field) => _original[row['id'] ?? '']?[field] ?? '';

  /// Whether one cell differs from what the server gave (the screen tints it).
  bool cellChanged(Map<String, String> row, String field) => (row[field] ?? '') != originalOf(row, field);

  void _restore(Map<String, String> row) {
    final o = _original[row['id'] ?? ''];
    if (o == null) return;
    for (final k in searchedFields) {
      row[k] = o[k] ?? '';
      _text['${row['id']}|$k']?.text = o[k] ?? '';
    }
    _refreshDirty(row);
  }

  /// Undo the edits of one student.
  void resetRow(Map<String, String> row) {
    _restore(row);
    notifyListeners();
  }

  /// Undo every edit.
  void resetAll() {
    for (final r in students) {
      _restore(r);
    }
    notifyListeners();
  }

  /// Put one value into a field for all the given students (the "quick fill").
  void applyToAll(String field, String value, List<Map<String, String>> targets) {
    for (final r in targets) {
      r[field] = value;
      _text['${r['id']}|$field']?.text = value;
      _refreshDirty(r);
    }
    notifyListeners();
  }

  /// Fields changed after a search no longer match the loaded rows, so the result is cleared.
  void clearResult() {
    _clearRows();
    searched = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }
}
