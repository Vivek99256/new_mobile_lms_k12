import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class IcardTemplate {
  IcardTemplate(Map<String, dynamic> r)
      : value = s(r['value']),
        label = s(r['label']);
  final String value, label;
}

class IcardStudent {
  IcardStudent(Map<String, dynamic> r)
      : id = s(r['id']),
        enrollmentNo = s(r['enrollment_no']),
        name = s(r['student_name']).isNotEmpty
            ? s(r['student_name'])
            : [r['first_name'], r['middle_name'], r['last_name']].map(s).where((e) => e.isNotEmpty).join(' '),
        standard = s(r['standard_name']),
        division = s(r['division_name']);
  final String id, enrollmentNo, name, standard, division;
}

/// State and API calls for Student I-card: metadata, student search and the HTML preview.
/// Routes: `GET student/api/student_icard/metadata`, `POST .../search`, `POST .../preview`.
class StudentIcardController extends ChangeNotifier {
  StudentIcardController({required this.args});
  final ScreenArgs args;
  static const _base = '/student/api/student_icard';

  bool metaLoading = true;
  bool searching = false;
  bool previewing = false;
  bool searched = false;
  String? error;
  String? info;

  List<Opt> drivers = [];
  List<IcardTemplate> templates = [];
  String? template;
  String? driverId;
  CascadeSelection cascade = CascadeSelection();

  List<IcardStudent> students = [];
  final selected = <String>{};

  /// HTML of the generated cards (the server returns one document for all selected students).
  String? html;

  List<Opt> _drivers(dynamic v) => [
        for (final d in rows(v))
          if (s(d['id']).isNotEmpty && s(d['first_name']).isNotEmpty) Opt(s(d['id']), s(d['first_name'])),
      ];

  Future<void> loadMeta() async {
    metaLoading = true;
    error = null;
    notifyListeners();
    try {
      final res = await args.api.get('$_base/metadata');
      if (statusOf(res) != '1') {
        error = LegacyApi.messageOf(res, "Couldn't load student I-card metadata. Try again.");
      } else {
        drivers = _drivers(res['drivers']);
        templates = rows(res['templates']).map(IcardTemplate.new).where((t) => t.value.isNotEmpty && t.label.isNotEmpty).toList();
        if (templates.isNotEmpty) template ??= templates.first.value;
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      metaLoading = false;
      notifyListeners();
    }
  }

  void setCascade(CascadeSelection c) {
    cascade = c;
  }

  void setDriver(String? v) {
    driverId = v;
    notifyListeners();
  }

  void setTemplate(String? v) {
    template = v;
    notifyListeners();
  }

  Future<void> search() async {
    searching = true;
    searched = true;
    info = null;
    error = null;
    html = null;
    students = [];
    selected.clear();
    notifyListeners();
    try {
      final res = await args.api.post('$_base/search', body: {
        'grade': cascade.sectionId ?? '',
        'standard': cascade.standardId ?? '',
        'division': cascade.divisionId ?? '',
        'driver_id': driverId ?? '',
      });
      if (statusOf(res) != '1') {
        info = LegacyApi.messageOf(res, 'No students found.');
      } else {
        students = rows(res['data']).map(IcardStudent.new).where((x) => x.id.isNotEmpty).toList();
        final d = _drivers(res['driver'] ?? res['drivers']);
        if (d.isNotEmpty) drivers = d;
        if (students.isEmpty) info = 'No students found.';
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  bool get allSelected => students.isNotEmpty && selected.length == students.length;

  void toggle(String id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notifyListeners();
  }

  void toggleAll() {
    if (allSelected) {
      selected.clear();
    } else {
      selected
        ..clear()
        ..addAll(students.map((e) => e.id));
    }
    notifyListeners();
  }

  /// Generates the cards for the selected students (one card per row/column: 1 x 1 on a phone).
  Future<bool> preview() async {
    if (template == null) {
      info = 'Select a template before generating Student I-cards.';
      notifyListeners();
      return false;
    }
    if (selected.isEmpty) {
      info = 'Select at least one student before generating Student I-cards.';
      notifyListeners();
      return false;
    }
    previewing = true;
    info = null;
    error = null;
    notifyListeners();
    try {
      final ids = students.where((e) => selected.contains(e.id)).map((e) => e.id).toList();
      final res = await args.api.post('$_base/preview', body: {
        'template': template,
        'row': '1',
        'column': '1',
        // PHP reads `students[]` as an array; LegacyApi sends each body entry as one field,
        // so the ids go as a comma list, which the endpoint accepts ("explode(',')").
        'students': ids.join(','),
      });
      final out = s(res['html']);
      if (statusOf(res) != '1' || out.isEmpty) {
        error = LegacyApi.messageOf(res, "Couldn't generate student I-cards. Try again.");
        return false;
      }
      html = out;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      previewing = false;
      notifyListeners();
    }
  }
}
