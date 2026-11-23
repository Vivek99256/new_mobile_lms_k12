import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// A document type and the standards it is required for (one row of the mapping list).
class DocMapping {
  DocMapping({required this.documentTypeId, required this.documentType, required this.standards, required this.grades, required this.standardIds});
  final String documentTypeId;
  final String documentType;
  final String standards; // comma separated standard names
  final String grades; // comma separated grade names
  final Set<String> standardIds;

  List<String> get standardList => standards.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

class GradeStandards {
  GradeStandards(this.id, this.title, this.standards);
  final String id;
  final String title;
  final List<Opt> standards;
}

/// State and API calls for Standardized Document Type (route `document_standard_mapping`):
/// which student document types are required for which standards.
class DocumentStandardMappingController extends ChangeNotifier {
  DocumentStandardMappingController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const _base = '/school_setup/document_standard_mapping';

  bool loading = true;
  bool busy = false;
  String? error;
  List<DocMapping> items = [];
  String query = '';

  List<DocMapping> get visible => query.isEmpty
      ? items
      : [for (final i in items) if (i.documentType.toLowerCase().contains(query) || i.standards.toLowerCase().contains(query)) i];

  void setQuery(String v) {
    query = v.trim().toLowerCase();
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get(_base);
      items = [
        for (final r in rows(res['mappedData']))
          DocMapping(
            documentTypeId: s(r['document_type_id']),
            documentType: s(r['document_type']),
            standards: s(r['standard']),
            grades: s(r['grade_name']),
            standardIds: {for (final id in s(r['all_std']).split(',')) if (id.trim().isNotEmpty) id.trim()},
          ),
      ];
    } on ApiException catch (e) {
      error = e.message;
      items = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Student document types (`create` returns a map id -> name).
  Future<List<Opt>> documentTypes() async {
    final res = await _api.get('$_base/create');
    final src = res['documentTypeList'];
    if (src is Map) return [for (final e in src.entries) Opt('${e.key}', s(e.value))];
    if (src is List) return [for (var i = 0; i < src.length; i++) Opt('${i + 1}', s(src[i]))];
    return const [];
  }

  /// Every grade with its standards, loaded the same way the class pickers do.
  Future<List<GradeStandards>> gradesWithStandards() async {
    final secRes = await _api.post('/get_adminAcademicSection');
    final secs = LegacyApi.ok(secRes) ? rows(secRes['data']) : <Map<String, dynamic>>[];
    final out = await Future.wait([
      for (final g in secs)
        () async {
          final r = await _api.post('/get_adminStandard', body: {'grade_id': s(g['id'])});
          final std = LegacyApi.ok(r) ? rows(r['data']) : <Map<String, dynamic>>[];
          return GradeStandards(
            s(g['id']),
            s(g['title']).isEmpty ? s(g['short_name']) : s(g['title']),
            [for (final x in std) Opt(s(x['id']), s(x['name']))],
          );
        }(),
    ]);
    return [for (final g in out) if (g.standards.isNotEmpty) g];
  }

  /// Adds the mapping (new) or adds standards to it (edit; the server only adds on update).
  Future<(bool, String)> save({required String documentTypeId, required Set<String> standardIds, String? editingId}) async {
    if (documentTypeId.isEmpty) return (false, 'Select a document type.');
    if (standardIds.isEmpty) return (false, 'Select at least one standard.');
    busy = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'document_type': documentTypeId,
        if (editingId != null) '_method': 'PUT',
      };
      var i = 0;
      for (final id in standardIds) {
        body['standard[${i++}]'] = id;
      }
      final res = await _api.post(editingId == null ? _base : '$_base/$editingId', body: body);
      final ok = statusOf(res) == '1';
      return (ok, LegacyApi.messageOf(res, ok ? 'Saved.' : 'Could not save.'));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
