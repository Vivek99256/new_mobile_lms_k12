import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

class ChangeRequest {
  ChangeRequest(Map<String, dynamic> r)
      : id = s(r['ID'] ?? r['id']),
        type = _title(s(r['request_title'])),
        student = s(r['student_name']),
        father = s(r['father_name']),
        grade = s(r['grade']),
        standard = s(r['standard']),
        division = s(r['division']),
        gr = s(r['enrollment_no']),
        reason = s(r['REASON']),
        description = s(r['DESCRIPTION']),
        proof = s(r['PROOF_OF_DOCUMENT']),
        status = _status(s(r['STATUS'])),
        createdOn = s(r['CREATED_ON']),
        decidedOn = s(r['DECIDED_ON']),
        image = s(r['student_image']);

  final String id, type, student, father, grade, standard, division, gr, reason, description, proof, status, createdOn, decidedOn, image;

  static String _status(String v) {
    final x = v.toLowerCase();
    return x == 'approved' ? 'Approved' : (x == 'rejected' ? 'Rejected' : 'Pending');
  }

  static String _title(String v) => v
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ')
      .trim();

  String get cls => [standard, division].where((e) => e.isNotEmpty).join(' - ');
}

class RequestType {
  RequestType(this.id, this.title, this.proofRequired, this.proofLabel);
  final String id;
  final String title;
  final bool proofRequired;
  final String proofLabel;
}

class RosterStudent {
  RosterStudent(Map<String, dynamic> r)
      : id = s(r['id'] ?? r['student_id']),
        gr = s(r['enrollment_no']),
        name = [r['first_name'], r['middle_name'], r['last_name']].map(s).where((e) => e.isNotEmpty).join(' '),
        image = s(r['image'] ?? r['student_image']),
        standardId = s(r['standard_id']),
        sectionId = s(r['section_id']),
        cls = [s(r['standard_name']), s(r['division_name'])].where((e) => e.isNotEmpty).join(' - ');
  final String id, gr, name, image, standardId, sectionId, cls;
}

/// A selected student's request being filled in.
class RequestDraft {
  String typeId = '';
  final proof = TextEditingController();
  final reason = TextEditingController();
  final description = TextEditingController();
  void dispose() {
    proof.dispose();
    reason.dispose();
    description.dispose();
  }
}

/// State and API calls for Student Request: the list (`student/student_request_fixed`), approve / reject
/// (`student/student_request/{id}/status`) and raising requests (`student/student_request/create` + store).
class StudentRequestController extends ChangeNotifier {
  StudentRequestController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  // --- list
  List<ChangeRequest> requests = [];
  bool loading = true;
  String? error;
  String statusFilter = 'All';
  CascadeSelection filter = CascadeSelection();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get('/student/student_request_fixed', query: {
        'status': '',
        'grade': filter.sectionId ?? '',
        'standard': filter.standardId ?? '',
        'division': filter.divisionId ?? '',
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      requests = [for (final r in rows(res['data'])) ChangeRequest(r)];
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setFilter(CascadeSelection c) => filter = c;

  void setStatusFilter(String v) {
    statusFilter = v;
    notifyListeners();
  }

  int count(String status) => requests.where((r) => r.status == status).length;

  List<ChangeRequest> get visible => statusFilter == 'All' ? requests : [for (final r in requests) if (r.status == statusFilter) r];

  /// Approves or rejects a request; returns the server message and whether it worked.
  Future<(bool, String)> decide(ChangeRequest r, bool approve) async {
    try {
      final res = await _api.post('/student/student_request/${r.id}/status', body: {'status': approve ? 'Approved' : 'Rejected'});
      final ok = statusOf(res) == '1';
      if (ok) await load();
      return (ok, LegacyApi.messageOf(res, ok ? 'Request ${approve ? 'approved' : 'rejected'}.' : 'Could not update the request.'));
    } on ApiException catch (e) {
      return (false, e.message);
    }
  }

  // --- raise requests
  List<RosterStudent> roster = [];
  List<RequestType> types = [];
  final selected = <String>{};
  final drafts = <String, RequestDraft>{};
  bool searching = false;
  bool searched = false;
  bool submitting = false;
  String? formError;

  RequestDraft draft(String studentId) => drafts.putIfAbsent(studentId, RequestDraft.new);

  Future<void> searchStudents(CascadeSelection c) async {
    searching = true;
    formError = null;
    notifyListeners();
    try {
      final res = await _api.get('/student/student_request/create', query: {
        'grade': c.sectionId ?? '',
        'standard': c.standardId ?? '',
        'division': c.divisionId ?? '',
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      // Cleared drafts are left to the garbage collector: their fields may still be on screen this frame.
      drafts.clear();
      selected.clear();
      roster = [for (final r in rows(res['student_data'])) RosterStudent(r)];
      types = [
        for (final r in rows(res['request_type_data']))
          RequestType(
            s(r['ID'] ?? r['id']),
            s(r['REQUEST_TITLE'] ?? r['request_title']),
            s(r['PROOF_DOCUMENT_REQUIED'] ?? r['proof_document_requied']) == 'Y',
            s(r['PROOF_DOCUMENT_NAME'] ?? r['proof_document_name']).isEmpty ? 'Document' : s(r['PROOF_DOCUMENT_NAME'] ?? r['proof_document_name']),
          ),
      ];
      searched = true;
    } on ApiException catch (e) {
      formError = e.message;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  void toggleStudent(String id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notifyListeners();
  }

  void setType(String studentId, String typeId) {
    draft(studentId).typeId = typeId;
    notifyListeners();
  }

  RequestType? typeOf(String id) => types.where((t) => t.id == id).firstOrNull;

  /// The first problem, as the web page words it, or null when the selection can be submitted.
  String? validate() {
    if (selected.isEmpty) return 'Select at least one student to proceed.';
    for (final id in selected) {
      if (draft(id).typeId.isEmpty) return 'Choose a request type for every selected student.';
    }
    for (final id in selected) {
      final d = draft(id);
      if ((typeOf(d.typeId)?.proofRequired ?? false) && d.proof.text.trim().isEmpty) return 'Provide the required document for every selected student.';
    }
    return null;
  }

  Future<(bool, String)> submit() async {
    submitting = true;
    notifyListeners();
    try {
      final body = <String, dynamic>{};
      var i = 0;
      for (final st in roster.where((e) => selected.contains(e.id))) {
        final d = draft(st.id);
        body['student_request[${i++}]'] = st.id;
        body['CHANGE_REQUEST_IDS[${st.id}]'] = d.typeId;
        body['PROOF_OF_DOCUMENTS[${st.id}]'] = d.proof.text.trim();
        body['REASONS[${st.id}]'] = d.reason.text.trim();
        body['DESCRIPTIONS[${st.id}]'] = d.description.text.trim();
        body['STANDARD_IDS[${st.id}]'] = st.standardId;
        body['SECTION_IDS[${st.id}]'] = st.sectionId;
      }
      final res = await _api.post('/student/student_request', body: body);
      final ok = statusOf(res) == '1';
      if (ok) {
        selected.clear();
        drafts.clear();
        await load();
      }
      return (ok, LegacyApi.messageOf(res, ok ? 'Student request submitted successfully.' : 'Could not submit the requests.'));
    } on ApiException catch (e) {
      return (false, e.message);
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final d in drafts.values) {
      d.dispose();
    }
    super.dispose();
  }
}
