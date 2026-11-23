import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// One fee head of one month for a student.
class BreakoffHead {
  BreakoffHead(this.title, this.amount, this.paid);
  final String title;
  final num amount;
  final num paid;
}

class BreakoffMonth {
  BreakoffMonth(this.id, this.heads);
  final String id;
  final List<BreakoffHead> heads;
  num get amount => heads.fold<num>(0, (a, h) => a + h.amount);
  num get paid => heads.fold<num>(0, (a, h) => a + h.paid);
}

/// A student's fee structure (what is due, month by month) and how much of it is paid.
class StudentBreakoff {
  StudentBreakoff({required this.name, required this.enrollmentNo, required this.father, required this.mobile, required this.months});
  final String name, enrollmentNo, father, mobile;
  final List<BreakoffMonth> months;

  num get amount => months.fold<num>(0, (a, m) => a + m.amount);
  num get paid => months.fold<num>(0, (a, m) => a + m.paid);
  num get pending => amount - paid;
}

/// State and API calls for the Student Breakoff Report (`GET /fees/student_breakoff_report/create`): pick a class,
/// see every student's fee structure. The server computes each student on its own, so a class is required.
class StudentBreakoffReportController extends ChangeNotifier {
  StudentBreakoffReportController({required this.args});
  final ScreenArgs args;

  CascadeSelection cascade = CascadeSelection();
  bool busy = false;
  bool searched = false;
  String? error;
  String? message;
  Map<String, String> monthLabels = {};
  List<StudentBreakoff> students = [];

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  num _n(dynamic v) => num.tryParse(s(v).replaceAll(',', '')) ?? 0;

  String? validate() {
    if (cascade.sectionId == null || cascade.standardId == null) return 'Please select a section and a standard.';
    return null;
  }

  Future<void> search() async {
    busy = true;
    searched = true;
    error = null;
    message = null;
    students = [];
    notifyListeners();
    try {
      final res = await args.api.get('/fees/student_breakoff_report/create', query: {
        'grade': cascade.sectionId!,
        'standard': cascade.standardId!,
        if (cascade.divisionId != null) 'division': cascade.divisionId!,
      });
      monthLabels = {for (final e in m(res['months_arr']).entries) e.key: s(e.value)};
      final list = res['fees_data'];
      final out = <StudentBreakoff>[];
      if (list is List) {
        for (final item in list) {
          // Each entry is `{studentId: {...student..., breakoff: {monthId: {head: {amount, paid_amount, title}}}}}`.
          for (final stu in m(item).values) {
            final st = m(stu);
            if (s(st['student_name']).isEmpty && s(st['first_name']).isEmpty) continue;
            final months = <BreakoffMonth>[
              for (final mo in m(st['breakoff']).entries)
                BreakoffMonth(mo.key, [
                  for (final h in m(mo.value).values)
                    if (h is Map) BreakoffHead(s(h['title']), _n(h['amount']), _n(h['paid_amount'])),
                ]),
            ];
            out.add(StudentBreakoff(
              name: s(st['student_name']).isNotEmpty ? s(st['student_name']) : '${s(st['first_name'])} ${s(st['surname'])}'.trim(),
              enrollmentNo: s(st['enrollment_no']),
              father: s(st['father_name']),
              mobile: s(st['mobile']),
              months: months,
            ));
          }
        }
      }
      students = out;
      message = s(res['message']);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String monthLabel(String id) => monthLabels[id] ?? id;
}
