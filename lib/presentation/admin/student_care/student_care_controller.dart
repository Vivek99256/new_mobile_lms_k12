import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/config.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import 'care_common.dart';

enum CareKind { text, phone, date, number, multiline, file }

/// One field of a care module (the web's `CareField`).
class CareField {
  const CareField(this.key, this.label, {this.kind = CareKind.text, this.required = false, this.unit = ''});
  final String key, label;
  final CareKind kind;
  final bool required;
  final String unit;
}

/// One care module, as the web's page wrappers configure `StudentCareModule`.
class CareSpec {
  const CareSpec({required this.module, required this.title, required this.singular, required this.icon, required this.fields});
  final String module, title, singular;
  final IconData icon;
  final List<CareField> fields;

  static const doctorName = CareField('doctor_name', 'Doctor name');
  static const doctorContact = CareField('doctor_contact', 'Doctor contact', kind: CareKind.phone);
  static const date = CareField('date', 'Date', kind: CareKind.date, required: true);

  static const vaccination = CareSpec(
    module: 'vaccination',
    title: 'Student Vaccination',
    singular: 'Vaccination',
    icon: Icons.vaccines_outlined,
    fields: [doctorName, doctorContact, date, CareField('vaccination_type', 'Vaccination type'), CareField('note', 'Note', kind: CareKind.multiline)],
  );

  static const heightWeight = CareSpec(
    module: 'height-weight',
    title: 'Student Height Weight',
    singular: 'Height Weight',
    icon: Icons.monitor_weight_outlined,
    fields: [doctorName, doctorContact, date, CareField('height', 'Height', kind: CareKind.number, unit: 'cm'), CareField('weight', 'Weight', kind: CareKind.number, unit: 'kg')],
  );

  static const health = CareSpec(
    module: 'health',
    title: 'Student Health',
    singular: 'Health Record',
    icon: Icons.monitor_heart_outlined,
    fields: [doctorName, doctorContact, date, CareField('remarks', 'Remarks', kind: CareKind.multiline), CareField('file', 'Document', kind: CareKind.file)],
  );
}

/// A record from `GET /student-care/{module}`: every column of the table plus `student_name`.
class CareRecord {
  CareRecord(Map<String, dynamic> r)
      : raw = {for (final e in r.entries) e.key: s(e.value)},
        id = s(r['id']),
        studentId = s(r['student_id']),
        studentName = s(r['student_name']);
  final Map<String, String> raw;
  final String id, studentId, studentName;

  String operator [](String key) => raw[key] ?? '';
  String get searchText => raw.values.join(' ').toLowerCase();
}

/// State and API calls for one care module (Vaccination, Height Weight or Health).
class StudentCareController extends ChangeNotifier {
  StudentCareController({required this.args, required this.spec}) : care = CareApi(args);
  final ScreenArgs args;
  final CareSpec spec;
  final CareApi care;

  String get path => '/student-care/${spec.module}';

  /// Documents are stored on the public disk under `frontdesk/`.
  static String documentUrl(String file) => file.isEmpty ? '' : '${AppConfig.apiBase}/storage/frontdesk/$file';

  bool loading = true;
  String? error;
  List<CareRecord> records = [];

  Future<void> load() async {
    error = null;
    notifyListeners();
    try {
      final res = await args.api.get(path);
      if (statusOf(res) != '1') {
        error = LegacyApi.messageOf(res, "Couldn't load records. Try again.");
      } else {
        records = rows(res['data']).map(CareRecord.new).toList();
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static const maxFileBytes = 5 * 1024 * 1024;

  /// [values] holds the text of each non-file field; [file] is a newly chosen document (Health only).
  Future<(bool, String)> save({required String? id, required String studentId, required Map<String, String> values, PickedFile? file}) async {
    final body = <String, dynamic>{'student_id': studentId, ...values};
    if (file != null) {
      final f = File(file.path);
      final length = await f.length();
      if (length > maxFileBytes) return (false, 'The document is larger than 5 MB. Choose a smaller file.');
      // The API takes the document as a data URL (same as the web form).
      body['file_name'] = file.name;
      body['file_data'] = 'data:application/octet-stream;base64,${base64Encode(await f.readAsBytes())}';
    }
    final r = await care.save(path, id, body);
    if (r.$1) await load();
    return r;
  }

  Future<(bool, String)> remove(CareRecord r) async {
    final res = await care.delete(path, r.id);
    if (res.$1) await load();
    return res;
  }
}
