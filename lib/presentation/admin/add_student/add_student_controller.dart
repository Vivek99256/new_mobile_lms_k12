import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// State and API calls for Add Student (same calls and rules as the web page):
/// `GET student-registration/metadata`, `GET student-registration/next-enrollment-no`, `POST student-registration`.
class AddStudentController extends ChangeNotifier {
  AddStudentController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  static const _textKeys = [
    'enrollment_no', 'roll_no', 'first_name', 'middle_name', 'last_name',
    'father_name', 'mother_name', 'mobile', 'email', 'address',
  ];
  static const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  /// Stored values the ERP uses for gender (M / F / O).
  static const genders = [Opt('M', 'Male'), Opt('F', 'Female'), Opt('O', 'Other')];

  final text = {for (final k in _textKeys) k: TextEditingController()};
  CascadeSelection cascade = CascadeSelection();
  DateTime? dob;
  String gender = '';
  String? bloodGroup, quota, house;

  List<Opt> quotas = [], houses = [];
  bool loading = true, saving = false, loadingGr = false;
  String? error;

  /// Bumped after a save so the class pickers start empty again.
  int epoch = 0;

  Future<void> init() async {
    loading = true;
    error = null;
    notifyListeners();
    await Future.wait([_loadMetadata(), fetchGr()]);
    loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _read(String path) async {
    final res = await _api.get(path);
    if (statusOf(res) != '1') throw ApiException(LegacyApi.messageOf(res, 'Request failed.'));
    return m(res['data']);
  }

  Future<void> _loadMetadata() async {
    try {
      final d = await _read('/student-registration/metadata');
      quotas = [for (final r in rows(d['quotas'])) Opt(s(r['id']), s(r['name']))];
      houses = [for (final r in rows(d['houses'])) Opt(s(r['id']), s(r['name']))];
    } on ApiException catch (e) {
      error = e.message;
    }
  }

  /// The next GR number (MAX + 1 across the institute); the field is read-only.
  Future<void> fetchGr() async {
    loadingGr = true;
    notifyListeners();
    try {
      final d = await _read('/student-registration/next-enrollment-no');
      text['enrollment_no']!.text = s(d['enrollment_no']);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loadingGr = false;
      notifyListeners();
    }
  }

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  void setDob(DateTime d) {
    dob = d;
    notifyListeners();
  }

  void setGender(String g) {
    gender = g;
    notifyListeners();
  }

  void setBlood(String? v) {
    bloodGroup = v;
    notifyListeners();
  }

  void setQuota(String? v) {
    quota = v;
    notifyListeners();
  }

  void setHouse(String? v) {
    house = v;
    notifyListeners();
  }

  String _t(String k) => text[k]!.text.trim();

  /// The same required fields as the web form. Returns the first problem, or null.
  String? validate() {
    if (cascade.sectionId == null) return 'Choose the section.';
    if (cascade.standardId == null) return 'Choose the standard.';
    if (cascade.divisionId == null) return 'Choose the division.';
    if (_t('enrollment_no').isEmpty) return 'The GR number is still loading. Wait a moment.';
    if (_t('first_name').isEmpty) return 'Enter the first name.';
    if (_t('last_name').isEmpty) return 'Enter the last name.';
    if (dob == null) return 'Choose the date of birth.';
    if (_t('mobile').isEmpty) return 'Enter the mobile number.';
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_t('mobile'))) return 'Enter a valid 10-digit mobile number.';
    if (_t('email').isEmpty) return 'Enter the email.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_t('email'))) return 'Enter a valid email address.';
    if (bloodGroup == null) return 'Choose the blood group.';
    if (gender.isEmpty) return 'Choose the gender.';
    if (quota == null) return 'Choose the student quota.';
    return null;
  }

  Map<String, dynamic> _body() => {
        'enrollment_no': _t('enrollment_no'),
        'roll_no': _t('roll_no'),
        'first_name': _t('first_name'),
        'middle_name': _t('middle_name'),
        'last_name': _t('last_name'),
        'father_name': _t('father_name'),
        'mother_name': _t('mother_name'),
        'dob': ymd(dob!),
        'mobile': _t('mobile'),
        'email': _t('email'),
        'address': _t('address'),
        'bloodgroup': bloodGroup,
        'gender': gender,
        'student_quota': quota,
        if (house != null) 'house': house,
        'grade': cascade.sectionId,
        'standard': cascade.standardId,
        'division': cascade.divisionId,
      };

  /// Creates the student. If another admin took the same GR number meanwhile, fetches a fresh one and retries (twice), as the web does.
  Future<(bool, String)> submit() async {
    if (saving) return (false, 'Saving already.');
    saving = true;
    notifyListeners();
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final res = await _api.post('/student-registration', body: _body());
        if (statusOf(res) == '1') {
          final msg = LegacyApi.messageOf(res, 'Student created.');
          _reset();
          await fetchGr();
          return (true, msg);
        }
        final msg = LegacyApi.messageOf(res, "Couldn't create student. Try again.");
        final duplicate = RegExp(r'GR no\.?\s*already exists', caseSensitive: false).hasMatch(msg);
        if (!duplicate || attempt == 2) return (false, msg);
        await fetchGr();
      }
      return (false, "Couldn't create student. Try again.");
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  void _reset() {
    for (final k in _textKeys) {
      text[k]!.clear();
    }
    cascade = CascadeSelection();
    dob = null;
    gender = '';
    bloodGroup = quota = house = null;
    epoch++;
  }

  @override
  void dispose() {
    for (final c in text.values) {
      c.dispose();
    }
    super.dispose();
  }
}
