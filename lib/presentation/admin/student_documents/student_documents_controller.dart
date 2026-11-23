import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

enum DocStatus { complete, partial, missing }

/// One student's document completeness.
class StudentDocRow {
  StudentDocRow({
    required this.name,
    required this.enrollmentNo,
    required this.standard,
    required this.division,
    required this.have,
    required this.total,
    required this.missingNames,
    required this.haveNames,
  });
  final String name;
  final String enrollmentNo;
  final String standard;
  final String division;
  final int have;
  final int total;
  final List<String> missingNames;
  final List<String> haveNames;

  /// Same rule as the web: none = missing, all = complete, otherwise pending.
  DocStatus get status => have == 0 ? DocStatus.missing : (have >= total ? DocStatus.complete : DocStatus.partial);
  String get classLabel => [standard, division].where((e) => e.isNotEmpty).join(' - ');
}

/// State and API call for Student Documents: the missing-document report
/// (`student/missing_document_report/create`, user_type=student), optionally narrowed by class.
class StudentDocumentsController extends ChangeNotifier {
  StudentDocumentsController({required this.args});
  final ScreenArgs args;

  static const _path = '/student/missing_document_report/create';

  bool loading = true;
  String? error;
  List<StudentDocRow> all = [];
  int docTypeCount = 0;
  CascadeSelection cascade = CascadeSelection();
  String query = '';
  DocStatus? statusFilter;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await args.api.get(_path, query: {
        'user_type': 'student',
        'grade': cascade.sectionId ?? '',
        'standard': cascade.standardId ?? '',
        'division': cascade.divisionId ?? '',
      });
      final types = {for (final t in rows(res['docment_type_data'])) s(t['id']): s(t['document_type'])};
      docTypeCount = types.length;
      all = [
        for (final r in rows(res['result_report'])) _row(r, types),
      ];
      if (all.isEmpty && !LegacyApi.ok(res)) error = LegacyApi.messageOf(res, "Couldn't load student documents. Try again.");
    } on ApiException catch (e) {
      error = e.message;
      all = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  StudentDocRow _row(Map<String, dynamic> r, Map<String, String> types) {
    final ids = s(r['document_list']).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final haveIds = ids.where(types.containsKey).toSet();
    return StudentDocRow(
      name: s(r['student_name']),
      enrollmentNo: s(r['enrollment_no']),
      standard: s(r['standard_name']),
      division: s(r['division_name']),
      have: haveIds.length,
      total: types.length,
      haveNames: [for (final id in haveIds) types[id]!],
      missingNames: [for (final e in types.entries) if (!haveIds.contains(e.key)) e.value],
    );
  }

  void setCascade(CascadeSelection c) => cascade = c;

  void setQuery(String v) {
    query = v.trim().toLowerCase();
    notifyListeners();
  }

  void setStatus(DocStatus? v) {
    statusFilter = statusFilter == v ? null : v;
    notifyListeners();
  }

  int count(DocStatus st) => all.where((r) => r.status == st).length;
  int get complianceRate => all.isEmpty ? 0 : (count(DocStatus.complete) * 100 / all.length).round();

  List<StudentDocRow> get visible => [
        for (final r in all)
          if ((statusFilter == null || r.status == statusFilter) &&
              (query.isEmpty || r.name.toLowerCase().contains(query) || r.enrollmentNo.toLowerCase().contains(query)))
            r,
      ];
}
