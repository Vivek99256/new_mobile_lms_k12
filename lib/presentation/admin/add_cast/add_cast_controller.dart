import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class CastRow {
  CastRow(this.id, this.title, this.sortOrder);
  final String id;
  final String title;
  final String sortOrder;
}

/// State and API calls for Add Cast: the `front_desk/add_cast` resource of the ERP
/// (index returns `castData`; store / update take `title` and `sort_order`; destroy by id).
class AddCastController extends ChangeNotifier {
  AddCastController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const _path = '/front_desk/add_cast';

  List<CastRow> casts = [];
  bool loading = true;
  bool saving = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get(_path);
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      casts = [for (final r in rows(res['castData'])) CastRow(s(r['id']), s(r['title']), s(r['sort_order']))];
      casts.sort((a, b) {
        final x = int.tryParse(a.sortOrder), y = int.tryParse(b.sortOrder);
        if (x != null && y != null && x != y) return x.compareTo(y);
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Next free sort order (the web form pre-fills the last order + 1).
  String get nextOrder {
    var max = 0;
    for (final c in casts) {
      final n = int.tryParse(c.sortOrder);
      if (n != null && n > max) max = n;
    }
    return '${max + 1}';
  }

  bool titleExists(String title, {String? exceptId}) =>
      casts.any((c) => c.id != exceptId && c.title.trim().toLowerCase() == title.trim().toLowerCase());

  /// Adds (when [id] is null) or edits a cast; returns the server's message and whether it worked.
  Future<(bool, String)> save({String? id, required String title, required String sortOrder}) async {
    saving = true;
    notifyListeners();
    try {
      final body = {'title': title.trim(), 'sort_order': sortOrder.trim(), if (id != null) '_method': 'PUT'};
      final res = await _api.post(id == null ? _path : '$_path/$id', body: body);
      final ok = statusOf(res) == '1';
      if (ok) await load();
      return (ok, LegacyApi.messageOf(res, ok ? 'Saved.' : 'Could not save.'));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<(bool, String)> delete(CastRow row) async {
    try {
      final res = await _api.post('$_path/${row.id}', body: {'_method': 'DELETE'});
      final ok = statusOf(res) == '1';
      if (ok) await load();
      return (ok, LegacyApi.messageOf(res, ok ? 'Deleted.' : 'Could not delete.'));
    } on ApiException catch (e) {
      return (false, e.message);
    }
  }
}
