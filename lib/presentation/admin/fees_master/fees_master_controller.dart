import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import 'fees_master_spec.dart';

/// State and API calls for one master's Add / Edit form, and for deleting a row.
class FeesMasterController extends ChangeNotifier {
  FeesMasterController({required this.args, required this.spec, this.row});

  final ScreenArgs args;
  final FeesMasterSpec spec;

  /// The row being edited; null when adding.
  final Map<String, dynamic>? row;
  bool get editing => row != null;

  LegacyApi get _api => args.api;

  Map<String, List<Opt>> options = {};
  bool loading = true;
  bool saving = false;
  String? error;

  final text = <String, TextEditingController>{};
  final dates = <String, DateTime?>{};
  final picks = <String, String?>{};
  final multis = <String, Set<String>>{};
  final toggles = <String, bool>{};
  CascadeSelection cascade = CascadeSelection();
  bool changeClass = false;

  List<MField> get fields => [
        for (final f in spec.fields)
          if (!(f.addOnly && editing) && !(f.editOnly && !editing)) f,
      ];

  Future<void> init() async {
    var r = row ?? const <String, dynamic>{};
    if (editing && spec.loadRecord != null) {
      try {
        r = {...r, ...await spec.loadRecord!(_api, r)};
      } on ApiException catch (e) {
        error = e.message;
      }
    }
    for (final f in spec.fields) {
      final saved = s(r[f.recordKey ?? f.key]);
      final v = saved.isNotEmpty ? saved : (editing ? '' : (f.initial ?? ''));
      switch (f.kind) {
        case MKind.date:
          dates[f.key] = DateTime.tryParse(v.split(' ').first);
        case MKind.dropdown:
          picks[f.key] = v.isEmpty ? null : v;
        case MKind.multi:
          multis[f.key] = {for (final id in v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty)) id};
        case MKind.toggle:
          toggles[f.key] = v == '1' || v.toLowerCase() == 'y' || v.toLowerCase() == 'yes';
        default:
          text[f.key] = TextEditingController(text: v);
      }
    }
    if (spec.loadOptions != null) {
      try {
        options = await spec.loadOptions!(_api);
      } on ApiException catch (e) {
        error = e.message;
      }
    }
    // Server-generated defaults (e.g. the next receipt book number) fill empty text fields.
    for (final d in options['_defaults'] ?? const <Opt>[]) {
      final c = text[d.id];
      if (c != null && c.text.isEmpty && !editing) c.text = d.label;
    }
    // Dependent multi lists (standards of the chosen grades), including the saved choice when editing.
    for (final f in spec.fields.where((f) => f.dependsOn != null)) {
      await _reloadDependent(f);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _reloadDependent(MField f) async {
    final load = spec.loadDependent;
    if (load == null || f.options == null) return;
    try {
      options[f.options!] = await load(_api, f.options!, multis[f.dependsOn]!.toSet());
    } on ApiException catch (e) {
      error = e.message;
    }
  }

  void setPick(String key, String? v) {
    picks[key] = v;
    notifyListeners();
  }

  void setDate(String key, DateTime d) {
    dates[key] = d;
    notifyListeners();
  }

  Future<void> toggleMulti(String key, String id) async {
    final set = multis[key]!;
    set.contains(id) ? set.remove(id) : set.add(id);
    notifyListeners();
    // Changing a parent (grade) reloads and clears what depends on it (standard).
    for (final f in spec.fields.where((f) => f.dependsOn == key)) {
      multis[f.key]!.clear();
      await _reloadDependent(f);
      notifyListeners();
    }
  }

  void setToggle(String key, bool v) {
    toggles[key] = v;
    notifyListeners();
  }

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  void setChangeClass(bool v) {
    changeClass = v;
    notifyListeners();
  }

  /// A message for the first problem, or null when the form can be saved.
  String? validate() {
    for (final f in fields) {
      if (!f.required) continue;
      final missing = switch (f.kind) {
        MKind.date => dates[f.key] == null,
        MKind.dropdown => (picks[f.key] ?? '').isEmpty,
        MKind.multi => (multis[f.key] ?? {}).isEmpty,
        MKind.toggle => false,
        _ => (text[f.key]?.text.trim() ?? '').isEmpty,
      };
      if (missing) return '${f.label} is required.';
    }
    if (spec.needsClass && (!editing || changeClass)) {
      if (cascade.sectionId == null) return 'Please select a section.';
      if (cascade.standardId == null) return 'Please select a standard.';
    }
    return null;
  }

  Map<String, dynamic> _body() {
    final b = <String, dynamic>{};
    for (final f in fields) {
      switch (f.kind) {
        case MKind.date:
          final d = dates[f.key];
          if (d != null) b[f.key] = ymd(d);
        case MKind.dropdown:
          if ((picks[f.key] ?? '').isNotEmpty) b[f.key] = picks[f.key];
        case MKind.multi:
          var i = 0;
          for (final id in multis[f.key]!) {
            b['${f.key}[${i++}]'] = id;
          }
        case MKind.toggle:
          b[f.key] = (toggles[f.key] ?? false) ? '1' : '0';
        default:
          b[f.key] = text[f.key]!.text.trim();
      }
    }
    if (spec.extraBody != null) b.addAll(spec.extraBody!(editing));
    if (spec.needsClass) {
      if (!editing || changeClass) {
        b['grade'] = cascade.sectionId;
        b['standard'] = cascade.standardId;
      } else {
        b['grade'] = s(row!['grade_id']);
        b['standard'] = s(row!['standard_id']);
      }
    }
    return b;
  }

  /// Saves; returns the server's message and whether it worked.
  Future<(bool, String)> save() async {
    saving = true;
    notifyListeners();
    try {
      final body = _body();
      final Map<String, dynamic> res;
      if (editing && spec.updateViaStore) {
        res = await _call(_api, args, spec, '/fees/${spec.resource}', body);
      } else if (editing) {
        res = await _call(_api, args, spec, '/fees/${spec.resource}/${s(row![spec.idKey])}', {...body, '_method': 'PUT'});
      } else {
        res = await _call(_api, args, spec, '/fees/${spec.resource}', body);
      }
      final ok = statusOf(res) == '1';
      return (ok, LegacyApi.messageOf(res, ok ? 'Saved.' : 'Could not save. Check the details and try again.'));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  static Future<Map<String, dynamic>> _call(LegacyApi api, ScreenArgs args, FeesMasterSpec spec, String path, Map<String, dynamic> body) {
    if (!spec.bare) return api.post(path, body: body);
    final q = Uri(queryParameters: {
      'type': 'API',
      'sub_institute_id': '${args.session.subInstituteId}',
      'syear': syearOf(args.session),
    }).query;
    return api.post('$path?$q', body: body, withIdentity: false);
  }

  /// Deletes a row of [spec]; returns the server's message and whether it worked.
  static Future<(bool, String)> delete(LegacyApi api, ScreenArgs args, FeesMasterSpec spec, Map<String, dynamic> row) async {
    try {
      final res = await _call(api, args, spec, '/fees/${spec.resource}/${s(row[spec.idKey])}', {'_method': 'DELETE'});
      final ok = statusOf(res) == '1';
      return (ok, LegacyApi.messageOf(res, ok ? 'Deleted.' : 'Could not delete.'));
    } on ApiException catch (e) {
      return (false, e.message);
    }
  }

  @override
  void dispose() {
    for (final c in text.values) {
      c.dispose();
    }
    super.dispose();
  }
}
