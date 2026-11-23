import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class CertStudent {
  CertStudent({required this.id, required this.enrollmentNo, required this.name, required this.standard, required this.division});
  final String id;
  final String enrollmentNo;
  final String name;
  final String standard;
  final String division;
  String get classLabel => [standard, division].where((e) => e.isNotEmpty).join(' - ');
}

class CertPreview {
  CertPreview({required this.html, required this.insertIds, required this.template});
  final String html;
  final String insertIds;
  final String template;
}

class CertHistoryRow {
  CertHistoryRow({
    required this.id,
    required this.enrollmentNo,
    required this.name,
    required this.classLabel,
    required this.number,
    required this.type,
    required this.createdAt,
    required this.html,
  });
  final String id;
  final String enrollmentNo;
  final String name;
  final String classLabel;
  final String number;
  final String type;
  final String createdAt;
  final String html;
}

/// A search panel's values (class pickers plus the text filters the web page has).
class CertSearch {
  CascadeSelection cascade = CascadeSelection();
  final name = TextEditingController();
  final uniqueId = TextEditingController();
  final mobile = TextEditingController();
  final grNo = TextEditingController();

  void dispose() {
    name.dispose();
    uniqueId.dispose();
    mobile.dispose();
    grNo.dispose();
  }

  Map<String, dynamic> toMap() => {
        'grade': cascade.sectionId ?? '',
        'standard': cascade.standardId ?? '',
        'division': cascade.divisionId ?? '',
        'stu_name': name.text.trim(),
        'uniqueid': uniqueId.text.trim(),
        'mobile': mobile.text.trim(),
        'grno': grNo.text.trim(),
      };
}

/// State and API calls for Student Certificate (`student/api/student_certificate/*`):
/// pick a template, search students, preview the certificate, issue it, and review history.
class StudentCertificateController extends ChangeNotifier {
  StudentCertificateController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const _base = '/student/api/student_certificate';

  final issueSearch = CertSearch();
  final historySearch = CertSearch();
  final reason = TextEditingController();

  // Templates
  List<Opt> templates = [];
  bool loadingTemplates = true;
  String? template;
  String? templateError;

  // Issue
  List<CertStudent> students = [];
  final Set<String> selected = {};
  bool searched = false;
  bool searching = false;
  bool previewing = false;
  bool issuing = false;
  String? issueMessage;

  // History
  List<CertHistoryRow> history = [];
  bool loadingHistory = false;
  bool historyLoaded = false;
  String? historyMessage;
  String? historyType;
  DateTime? fromDate;
  DateTime? toDate;
  String historyQuery = '';

  String _plain(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();

  Future<void> loadTemplates() async {
    loadingTemplates = true;
    templateError = null;
    notifyListeners();
    try {
      final res = await _api.get('$_base/templates');
      if (statusOf(res) != '1') {
        templateError = LegacyApi.messageOf(res, "Couldn't load certificate templates. Try again.");
      } else {
        templates = [
          for (final r in rows(res['report_types']))
            if (s(r['module_name']).isNotEmpty) Opt(s(r['module_name']), s(r['module_name'])),
        ];
        if (template == null && templates.isNotEmpty) template = templates.first.id;
      }
    } on ApiException catch (e) {
      templateError = e.message;
    } finally {
      loadingTemplates = false;
      notifyListeners();
    }
  }

  void setTemplate(String? v) {
    template = v;
    notifyListeners();
  }

  Future<void> searchStudents() async {
    searching = true;
    issueMessage = null;
    selected.clear();
    notifyListeners();
    try {
      final res = await _api.post('$_base/search', body: issueSearch.toMap());
      if (statusOf(res) != '1') {
        students = [];
        issueMessage = _plain(LegacyApi.messageOf(res, "Couldn't load students. Try again."));
      } else {
        students = [
          for (final r in rows(res['data']))
            if (s(r['id']).isNotEmpty)
              CertStudent(
                id: s(r['id']),
                enrollmentNo: s(r['enrollment_no']),
                name: s(r['student_name']).isNotEmpty
                    ? s(r['student_name'])
                    : [s(r['first_name']), s(r['middle_name']), s(r['last_name'])].where((e) => e.isNotEmpty).join(' '),
                standard: s(r['standard_name']),
                division: s(r['division_name']),
              ),
        ];
        if (students.isEmpty) issueMessage = 'No students found.';
      }
      searched = true;
    } on ApiException catch (e) {
      students = [];
      issueMessage = e.message;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  bool get allSelected => students.isNotEmpty && selected.length == students.length;

  void toggleAll(bool v) {
    selected
      ..clear()
      ..addAll(v ? students.map((e) => e.id) : const <String>[]);
    notifyListeners();
  }

  void toggle(String id) {
    if (!selected.remove(id)) selected.add(id);
    notifyListeners();
  }

  /// Validates and asks the server for the certificate HTML. Returns (preview, message).
  Future<(CertPreview?, String)> preview() async {
    if ((template ?? '').isEmpty) return (null, 'Select a certificate template before generating the preview.');
    if (selected.isEmpty) return (null, 'Select at least one student before generating the preview.');
    previewing = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'grade_id': issueSearch.cascade.sectionId ?? '',
        'standard_id': issueSearch.cascade.standardId ?? '',
        'template': template,
        'certificate_reason': reason.text.trim(),
      };
      var i = 0;
      for (final id in selected) {
        body['students[${i++}]'] = id;
      }
      final res = await _api.post('$_base/preview', body: body);
      if (statusOf(res) != '1') return (null, _plain(LegacyApi.messageOf(res, "Couldn't generate certificate preview. Try again.")));
      final p = CertPreview(html: s(res['str']), insertIds: s(res['insert_ids']), template: s(res['template']));
      if (p.html.isEmpty || p.insertIds.isEmpty || p.template.isEmpty) return (null, "Couldn't generate the certificate preview. Try again.");
      return (p, LegacyApi.messageOf(res, 'Certificate preview generated successfully.'));
    } on ApiException catch (e) {
      return (null, e.message);
    } finally {
      previewing = false;
      notifyListeners();
    }
  }

  Future<(bool, String)> issue(CertPreview p) async {
    issuing = true;
    notifyListeners();
    try {
      final res = await _api.post('$_base/save', body: {
        'insert_student_ids': p.insertIds,
        'template': p.template,
        'certificate_reason': reason.text.trim(),
      });
      final ok = statusOf(res) == '1';
      return (ok, _plain(LegacyApi.messageOf(res, ok ? 'Certificates issued successfully.' : "Couldn't issue certificates. Try again.")));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      issuing = false;
      notifyListeners();
    }
  }

  void setHistoryType(String? v) {
    historyType = v;
    notifyListeners();
  }

  void setDates({DateTime? from, DateTime? to}) {
    if (from != null) fromDate = from;
    if (to != null) toDate = to;
    notifyListeners();
  }

  void setHistoryQuery(String v) {
    historyQuery = v.trim().toLowerCase();
    notifyListeners();
  }

  List<CertHistoryRow> get visibleHistory => historyQuery.isEmpty
      ? history
      : [
          for (final r in history)
            if ([r.enrollmentNo, r.name, r.classLabel, r.number, r.type].any((e) => e.toLowerCase().contains(historyQuery))) r,
        ];

  Future<void> loadHistory({String? type}) async {
    if (type != null) historyType = type;
    loadingHistory = true;
    historyMessage = null;
    notifyListeners();
    try {
      final res = await _api.get('$_base/history', query: {
        ...historySearch.toMap(),
        'from_date': fromDate == null ? '' : ymd(fromDate!),
        'to_date': toDate == null ? '' : ymd(toDate!),
        'certificate_type': historyType ?? '',
      });
      if (statusOf(res) != '1') {
        history = [];
        historyMessage = _plain(LegacyApi.messageOf(res, "Couldn't load certificate history. Try again."));
      } else {
        history = [
          for (final r in rows(res['result_report']))
            if ((s(r['certi_id']).isNotEmpty ? s(r['certi_id']) : s(r['id'])).isNotEmpty)
              CertHistoryRow(
                id: s(r['certi_id']).isNotEmpty ? s(r['certi_id']) : s(r['id']),
                enrollmentNo: s(r['enrollment_no']),
                name: s(r['student_name']).isNotEmpty
                    ? s(r['student_name'])
                    : [s(r['first_name']), s(r['middle_name']), s(r['last_name'])].where((e) => e.isNotEmpty).join(' '),
                classLabel: [s(r['standard_name']), s(r['division_name'])].where((e) => e.isNotEmpty).join(' - '),
                number: s(r['certificate_number']),
                type: s(r['certificate_type']),
                createdAt: s(r['created_at']),
                html: s(r['certificate_html']),
              ),
        ];
        if (history.isEmpty) historyMessage = 'No certificate history found.';
      }
      historyLoaded = true;
    } on ApiException catch (e) {
      history = [];
      historyMessage = e.message;
    } finally {
      loadingHistory = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    issueSearch.dispose();
    historySearch.dispose();
    reason.dispose();
    super.dispose();
  }
}
