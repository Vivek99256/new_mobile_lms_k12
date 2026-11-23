import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// One quota's fee structure in one standard: amount per billing month, for new and old students.
class QuotaStructure {
  QuotaStructure(this.name, this.newByMonth, this.oldByMonth);
  final String name;
  final Map<String, num> newByMonth;
  final Map<String, num> oldByMonth;

  num get newTotal => newByMonth.values.fold<num>(0, (a, b) => a + b);
  num get oldTotal => oldByMonth.values.fold<num>(0, (a, b) => a + b);
}

class StandardStructure {
  StandardStructure(this.name, this.quotas);
  final String name;
  final List<QuotaStructure> quotas;
}

/// State and API calls for the Fees Structure Report: choose a section (and standard), see what each student quota
/// pays per month. (`POST /fees/fees_structure_report`)
class FeesStructureReportController extends ChangeNotifier {
  FeesStructureReportController({required this.args});
  final ScreenArgs args;

  CascadeSelection cascade = CascadeSelection();
  bool busy = false;
  bool searched = false;
  String? error;
  String? message;

  /// month id -> label (e.g. "Apr/2022"), in the order the server gives them.
  Map<String, String> months = {};
  List<StandardStructure> standards = [];

  void setCascade(CascadeSelection c) {
    cascade = c;
    notifyListeners();
  }

  num _n(dynamic v) => num.tryParse(s(v).replaceAll(',', '')) ?? 0;

  Map<String, num> _byMonth(dynamic v) => {for (final e in m(v).entries) e.key: _n(e.value)};

  Future<void> search() async {
    busy = true;
    searched = true;
    error = null;
    message = null;
    standards = [];
    notifyListeners();
    try {
      final res = await args.api.post('/fees/fees_structure_report', body: {
        'grade': cascade.sectionId,
        if (cascade.standardId != null) 'standard': cascade.standardId,
      });
      final data = m(res['report_data']).isNotEmpty ? m(res['report_data']) : m(res['data']);
      months = {for (final e in m(res['months_arr']).entries) e.key: s(e.value)};
      standards = [
        for (final std in data.entries)
          StandardStructure(std.key, [
            for (final q in m(std.value).entries)
              QuotaStructure(q.key, _byMonth(m(q.value)['NEW']), _byMonth(m(q.value)['OLD'])),
          ]),
      ];
      message = s(res['message']);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String monthLabel(String id) => months[id] ?? id;
}
