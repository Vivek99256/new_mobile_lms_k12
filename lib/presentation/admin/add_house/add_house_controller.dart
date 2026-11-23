import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class HouseRow {
  const HouseRow(this.id, this.name, this.sortOrder);
  final String id;
  final String name;
  final String sortOrder;
}

/// State and API calls for Add House (the web's student-setup "house" master):
/// `GET/POST student-setup/house`, `PUT/DELETE student-setup/house/{id}`.
class AddHouseController extends ChangeNotifier {
  AddHouseController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const _path = '/student-setup/house';

  List<HouseRow> houses = [];
  bool loading = true, busy = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get(_path);
      if (statusOf(res) != '1') throw ApiException(LegacyApi.messageOf(res, "Couldn't load data. Try again."));
      houses = [for (final r in rows(res['data'])) HouseRow(s(r['id']), s(r['house_name']), s(r['sort_order']))];
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Validation as the server applies it: name required, sort order a whole number from 0.
  static String? validate(String name, String sort) {
    if (name.trim().isEmpty) return 'Enter the house name.';
    if (name.trim().length > 255) return 'The house name is too long.';
    if (sort.trim().isNotEmpty) {
      final n = int.tryParse(sort.trim());
      if (n == null || n < 0) return 'Sort order must be a whole number, 0 or more.';
    }
    return null;
  }

  Map<String, String> _sessionQuery() {
    final session = args.session;
    return {
      'sub_institute_id': '${session.subInstituteId}',
      'syear': syearOf(session),
      'user_id': '${session.userId}',
    };
  }

  /// Adds a house, or updates [id]. Returns (ok, message) and reloads the list on success.
  Future<(bool, String)> save({String? id, required String name, required String sort}) async {
    busy = true;
    notifyListeners();
    try {
      final Map<String, dynamic> res;
      if (id == null) {
        res = await _api.post(_path, body: {'name': name.trim(), if (sort.trim().isNotEmpty) 'sort_order': sort.trim()});
      } else {
        res = await AdminHttp.put(args.session, '$_path/$id', {..._sessionQuery(), 'name': name.trim(), 'sort_order': sort.trim()});
      }
      final ok = statusOf(res) == '1';
      final msg = LegacyApi.messageOf(res, ok ? 'Saved.' : "Couldn't save. Try again.");
      if (ok) await load();
      return (ok, msg);
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<(bool, String)> delete(String id) async {
    busy = true;
    notifyListeners();
    try {
      final res = await AdminHttp.delete(args.session, '$_path/$id', _sessionQuery());
      final ok = statusOf(res) == '1';
      final msg = LegacyApi.messageOf(res, ok ? 'Deleted.' : "Couldn't delete. Try again.");
      if (ok) await load();
      return (ok, msg);
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
