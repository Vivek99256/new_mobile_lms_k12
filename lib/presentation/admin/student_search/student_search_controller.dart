import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// One student as the search returns it (`tblstudent` + current enrollment + class names).
class StudentRecord {
  StudentRecord(this.raw);
  final Map<String, dynamic> raw;

  String get id => s(raw['student_id']).isNotEmpty ? s(raw['student_id']) : s(raw['id']);
  String get name => [raw['first_name'], raw['middle_name'], raw['last_name']].map(s).where((e) => e.isNotEmpty).join(' ');
  String get firstName => s(raw['first_name']);
  String get enrollmentNo => s(raw['enrollment_no']);
  String get uniqueId => s(raw['uniqueid']);
  String get rollNo => s(raw['roll_no']);
  String get standard => s(raw['standard']);
  String get division => s(raw['division']);
  String get grade => s(raw['grade']);
  String get cls => [standard, division].where((e) => e.isNotEmpty).join(' - ');
  String get gender => s(raw['gender']);
  String get dob => s(raw['dob']);
  String get mobile => s(raw['mobile']);
  String get email => s(raw['email']);
  String get address => s(raw['address']);
  String get father => s(raw['father_name']);
  String get mother => s(raw['mother_name']);
  String get house => s(raw['house']);
  String get bloodGroup => s(raw['bloodgroup']);
  String get quota => s(raw['student_quota']);

  /// Ended enrollments are listed only when "include inactive" is on, and shown as inactive.
  bool get inactive => s(raw['inactive_colour']).isNotEmpty || s(raw['end_date']).isNotEmpty;

  String get genderLabel {
    final g = gender.toLowerCase();
    if (g.startsWith('m')) return 'Male';
    if (g.startsWith('f')) return 'Female';
    return gender;
  }
}

/// State and API calls for Search / Edit Student (`POST /get_adminStudentSearch`, `PUT /get_adminStudentSearch/{id}`).
class StudentSearchController extends ChangeNotifier {
  StudentSearchController({required this.args});
  final ScreenArgs args;

  CascadeSelection cascade = CascadeSelection();
  final firstName = TextEditingController();
  final grNo = TextEditingController();
  bool includeInactive = false;

  bool busy = false;
  bool searched = false;
  String? error;
  List<StudentRecord> students = [];

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  void setInactive(bool v) {
    includeInactive = v;
    notifyListeners();
  }

  /// Searching the whole school would return thousands of rows, so a class, a name or a GR number is needed.
  String? validate() {
    final hasClass = cascade.standardId != null || cascade.sectionId != null;
    if (!hasClass && firstName.text.trim().isEmpty && grNo.text.trim().isEmpty) {
      return 'Choose a class, or type a name or GR number.';
    }
    return null;
  }

  Future<void> search() async {
    busy = true;
    searched = true;
    error = null;
    students = [];
    notifyListeners();
    try {
      final res = await args.api.post('/get_adminStudentSearch', body: {
        if (cascade.sectionId != null) 'grade': cascade.sectionId,
        if (cascade.standardId != null) 'standard': cascade.standardId,
        if (cascade.divisionId != null) 'division': cascade.divisionId,
        if (firstName.text.trim().isNotEmpty) 'first_name': firstName.text.trim(),
        if (grNo.text.trim().isNotEmpty) 'gr_no': grNo.text.trim(),
        if (includeInactive) 'including_inactive': 'Yes',
      });
      if (statusOf(res) != '1') {
        error = LegacyApi.messageOf(res, "Couldn't load students. Try again.");
      } else {
        students = rows(res['data']).map(StudentRecord.new).toList();
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Saves the edited fields of [st] (the same fields the web form sends).
  Future<(bool, String)> update(StudentRecord st, Map<String, String> v) async {
    final session = args.session;
    try {
      final res = await AdminHttp.put(session, '/get_adminStudentSearch/${st.id}', {
        'sub_institute_id': '${session.subInstituteId}',
        'syear': syearOf(session),
        'user_id': '${session.userId}',
        ...v,
      });
      final ok = statusOf(res) == '1';
      return (ok, LegacyApi.messageOf(res, ok ? 'Student updated successfully.' : "Couldn't update student. Try again."));
    } on ApiException catch (e) {
      return (false, e.message);
    }
  }

  @override
  void dispose() {
    firstName.dispose();
    grNo.dispose();
    super.dispose();
  }
}
