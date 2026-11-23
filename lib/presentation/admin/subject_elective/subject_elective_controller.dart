import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class ElectiveRow {
  ElectiveRow({required this.id, required this.standardId, required this.divisionId, required this.subjectId, required this.standard, required this.division, required this.subject, required this.code});
  final String id;
  final String standardId;
  final String divisionId;
  final String subjectId;
  final String standard;
  final String division;
  final String subject;
  final String code;

  bool get hasSubject => subjectId.isNotEmpty && subjectId != '0';
}

/// State and API calls for Subject Elective (Standard - Division elective mapping). The web page uses
/// the `migration-modules/subject-electives` API: GET lists, POST saves (insert or update of the
/// standard + division pair), DELETE removes. The elective subjects of a standard come from the
/// ERP route `school_setup/optional_subject`.
class SubjectElectiveController extends ChangeNotifier {
  SubjectElectiveController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const _path = '/api/migration-modules/subject-electives';

  List<ElectiveRow> items = [];
  bool loading = true;
  bool saving = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get(_path);
      if (statusOf(res) != '1') throw ApiException(LegacyApi.messageOf(res, "Couldn't load the electives. Try again."));
      items = [
        for (final r in rows(m(res['data'])['records']))
          ElectiveRow(
            id: s(r['id']),
            standardId: s(r['standard_id']),
            divisionId: s(r['division_id']),
            subjectId: s(r['subject_id']),
            standard: s(r['standard_name']),
            division: s(r['division_name']),
            subject: s(r['subject_name']),
            code: s(r['elective_sub_no']),
          ),
      ];
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// The elective subjects of a standard (`sub_std_map` rows flagged elective).
  Future<List<Opt>> electiveSubjects(String standardId) async {
    final res = await _api.get('/school_setup/optional_subject', query: {'standard_id': standardId});
    final seen = <String>{};
    final out = <Opt>[];
    // The route returns a bare JSON list, which LegacyApi wraps as `data`.
    for (final r in rows(res['data'])) {
      final id = s(r['subject_id']);
      if (id.isEmpty || !seen.add(id)) continue;
      final name = s(r['display_name']).isNotEmpty ? s(r['display_name']) : (s(r['subject_name']).isNotEmpty ? s(r['subject_name']) : 'Subject $id');
      out.add(Opt(id, name));
    }
    return out;
  }

  bool exists(String standardId, String divisionId) => items.any((e) => e.standardId == standardId && e.divisionId == divisionId);

  /// Saves the mapping of one standard + division; returns the server's message and whether it worked.
  Future<(bool, String)> save({required String standardId, required String divisionId, required String subjectId}) async {
    saving = true;
    notifyListeners();
    try {
      final res = await _api.post(_path, body: {'standard_id': standardId, 'division_id': divisionId, 'subject_id': subjectId});
      final ok = statusOf(res) == '1';
      if (ok) await load();
      return (ok, LegacyApi.messageOf(res, ok ? 'Elective mapping saved.' : 'Could not save.'));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<(bool, String)> delete(ElectiveRow row) async {
    try {
      final res = await _api.post('$_path/${row.id}', body: {'_method': 'DELETE'});
      final ok = statusOf(res) == '1';
      if (ok) await load();
      return (ok, LegacyApi.messageOf(res, ok ? 'Record deleted.' : 'Could not delete.'));
    } on ApiException catch (e) {
      return (false, e.message);
    }
  }
}
