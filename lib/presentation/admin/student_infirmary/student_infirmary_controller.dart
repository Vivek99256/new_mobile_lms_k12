import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../student_care/care_common.dart';

/// One row of `GET /student-infirmary` (`data.records`).
class InfirmaryRecord {
  InfirmaryRecord(Map<String, dynamic> r)
      : id = s(r['id']),
        studentId = s(r['student_id']),
        studentName = s(r['student_name']),
        caseNo = s(r['medical_case_no']),
        doctorName = s(r['doctor_name']),
        doctorContact = s(r['doctor_contact']),
        date = s(r['date']),
        complaint = s(r['complaint']),
        symptoms = s(r['symptoms']),
        disease = s(r['disease']),
        treatments = s(r['treatments']),
        closeDate = s(r['medical_close_date']),
        healthCenter = s(r['health_center']);

  final String id, studentId, studentName, caseNo, doctorName, doctorContact, date;
  final String complaint, symptoms, disease, treatments, closeDate, healthCenter;

  bool get isOpen => parseDay(closeDate) == null;

  String get searchText => '$studentName $caseNo $doctorName $complaint $disease $healthCenter'.toLowerCase();
}

/// State and API calls for Student Infirmary (same endpoints and rules as the web page).
class StudentInfirmaryController extends ChangeNotifier {
  StudentInfirmaryController({required this.args}) : care = CareApi(args);
  final ScreenArgs args;
  final CareApi care;
  static const path = '/student-infirmary';

  bool loading = true;
  String? error;
  List<InfirmaryRecord> records = [];
  String nextCaseNo = '';

  Future<void> load() async {
    error = null;
    notifyListeners();
    try {
      final res = await args.api.get(path);
      if (statusOf(res) != '1') {
        error = LegacyApi.messageOf(res, "Couldn't load infirmary records. Try again.");
      } else {
        final data = m(res['data']);
        records = rows(data['records']).map(InfirmaryRecord.new).toList();
        nextCaseNo = s(data['next_case_number']);
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Same payload the web sends. [id] is null when adding.
  Future<(bool, String)> save({
    required String? id,
    required String studentId,
    required String caseNo,
    required String doctorName,
    required String doctorContact,
    required DateTime date,
    required String complaint,
    required String symptoms,
    required String disease,
    required String treatments,
    required DateTime? closeDate,
    required String healthCenter,
  }) async {
    final r = await care.save(path, id, {
      'student_id': studentId,
      'medical_case_no': caseNo,
      'doctor_name': doctorName.trim(),
      'doctor_contact': doctorContact.trim(),
      'date': ymd(date),
      'complaint': complaint.trim(),
      'symptoms': symptoms.trim(),
      'disease': disease.trim(),
      'treatments': treatments.trim(),
      'medical_close_date': closeDate == null ? '' : ymd(closeDate),
      'health_center': healthCenter.trim(),
    });
    if (r.$1) await load();
    return r;
  }

  Future<(bool, String)> remove(InfirmaryRecord r) async {
    final res = await care.delete(path, r.id);
    if (res.$1) await load();
    return res;
  }
}
