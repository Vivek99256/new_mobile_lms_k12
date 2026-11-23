import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// Boys and girls of one house in one division.
class HouseCount {
  const HouseCount(this.house, this.boys, this.girls);
  final String house;
  final int boys, girls;
}

/// One division of the standard: how many students it has now, and what the shuffle gives it.
class DivisionPlan {
  DivisionPlan(this.name, this.before, this.after, this.houses);
  final String name;
  final int before, after;
  final List<HouseCount> houses;
}

/// What the shuffle is expected to do, worked out on the phone from the current students.
class ShufflePreview {
  ShufflePreview({
    required this.standardName,
    required this.divisions,
    required this.houseCount,
    required this.boys,
    required this.girls,
    required this.skipped,
    required this.estimated,
  });
  final String standardName;
  final List<DivisionPlan> divisions;
  final int houseCount;
  final int boys, girls;

  /// Students the shuffle will not touch (no house, or gender not M/F).
  final int skipped;

  /// False for the optional-subject mode: the current spread is shown but not the result.
  final bool estimated;
}

/// The server's own answer after the shuffle ran.
class ShuffleResult {
  ShuffleResult({required this.message, required this.rows, required this.houseNames, required this.boys, required this.girls, required this.divisions});
  final String message;
  final List<Map<String, dynamic>> rows;
  final List<String> houseNames;
  final String boys, girls, divisions;
}

/// State and API calls for Student Shuffling (Laravel `house_automation`). The server action is
/// `GET /student/house_automation/create?standard_id=..&opt_sub=No|Yes` and it applies the change straight away,
/// so the preview here is calculated from the current students and the houses before anything is sent.
class StudentShufflingController extends ChangeNotifier {
  StudentShufflingController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  /// The server never moves students out of, or into, this division (the "T" division).
  static const excludedDivision = '1397';

  CascadeSelection cascade = CascadeSelection();
  bool optionalSubjects = false;

  bool previewing = false, applying = false;
  String? error;
  ShufflePreview? preview;
  ShuffleResult? result;

  String get optSub => optionalSubjects ? 'Yes' : 'No';
  bool get hasStandard => cascade.standardId != null;

  void setCascade(CascadeSelection c) {
    cascade = c;
    preview = null;
    result = null;
    error = null;
    notifyListeners();
  }

  void setOptional(bool v) {
    optionalSubjects = v;
    preview = null;
    result = null;
    notifyListeners();
  }

  Future<void> loadPreview() async {
    if (!hasStandard) return;
    previewing = true;
    error = null;
    result = null;
    preview = null;
    notifyListeners();
    try {
      final stdId = cascade.standardId!;
      final houseRes = await _api.get('/student-setup/house');
      if (statusOf(houseRes) != '1') throw ApiException(LegacyApi.messageOf(houseRes, "Couldn't load the houses."));
      final houses = [for (final r in rows(houseRes['data'])) (id: s(r['id']), name: s(r['house_name']))];
      if (houses.isEmpty) throw ApiException('Please create the houses first (Add House).');

      final divRes = await _api.post('/get_adminDivision', body: {'standard_id': stdId});
      final divisions = [for (final r in rows(divRes['data'])) (id: s(r['id']), name: s(r['name']))];

      final stuRes = await _api.post('/get_adminStudentSearch', body: {'standard': stdId});
      if (statusOf(stuRes) != '1') throw ApiException(LegacyApi.messageOf(stuRes, "Couldn't load the students."));
      final students = rows(stuRes['data']);

      preview = _plan(houses, divisions, students);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      previewing = false;
      notifyListeners();
    }
  }

  ShufflePreview _plan(List<({String id, String name})> houses, List<({String id, String name})> divisions, List<Map<String, dynamic>> students) {
    final houseIds = {for (final h in houses) h.id};
    final target = [for (final d in divisions) if (d.id != excludedDivision) d];

    final before = <String, int>{};
    for (final st in students) {
      before.update(s(st['section_id']), (v) => v + 1, ifAbsent: () => 1);
    }

    // Who the shuffle touches: a house of this school and a gender of M or F.
    bool moves(Map<String, dynamic> st) => houseIds.contains(s(st['house_id'])) && (s(st['gender']) == 'M' || s(st['gender']) == 'F');
    final untouchedByDivision = <String, int>{};
    var skipped = 0;
    for (final st in students) {
      if (!moves(st)) {
        skipped++;
        untouchedByDivision.update(s(st['section_id']), (v) => v + 1, ifAbsent: () => 1);
      }
    }

    int boys = 0, girls = 0;
    for (final st in students) {
      if (!moves(st)) continue;
      s(st['gender']) == 'M' ? boys++ : girls++;
    }

    if (optionalSubjects) {
      // The elective-subject mode regroups by subject: show today's spread only.
      return ShufflePreview(
        standardName: cascade.standardName ?? '',
        divisions: [for (final d in divisions) DivisionPlan(d.name, before[d.id] ?? 0, before[d.id] ?? 0, const [])],
        houseCount: houses.length,
        boys: boys,
        girls: girls,
        skipped: skipped,
        estimated: false,
      );
    }

    final d = target.length;
    final plan = <String, List<HouseCount>>{for (final t in target) t.id: []};
    for (final h in houses) {
      var nb = 0, ng = 0;
      for (final st in students) {
        if (s(st['house_id']) != h.id) continue;
        if (s(st['gender']) == 'M') nb++;
        if (s(st['gender']) == 'F') ng++;
      }
      // Round robin across the divisions: the first (n mod d) divisions get one more.
      for (var i = 0; i < d; i++) {
        final b = d == 0 ? 0 : nb ~/ d + (i < nb % d ? 1 : 0);
        final g = d == 0 ? 0 : ng ~/ d + (i < ng % d ? 1 : 0);
        plan[target[i].id]!.add(HouseCount(h.name, b, g));
      }
    }

    final out = <DivisionPlan>[];
    for (final dv in divisions) {
      final list = plan[dv.id] ?? const <HouseCount>[];
      final moved = list.fold<int>(0, (a, h) => a + h.boys + h.girls);
      final after = moved + (untouchedByDivision[dv.id] ?? 0);
      if (dv.id == excludedDivision && (before[dv.id] ?? 0) == 0 && after == 0) continue;
      out.add(DivisionPlan(dv.name, before[dv.id] ?? 0, after, list));
    }
    return ShufflePreview(
      standardName: cascade.standardName ?? '',
      divisions: out,
      houseCount: houses.length,
      boys: boys,
      girls: girls,
      skipped: skipped,
      estimated: true,
    );
  }

  /// Runs the shuffle on the server. Returns an error message, or null on success.
  Future<String?> apply() async {
    if (!hasStandard || applying) return 'Choose a standard first.';
    applying = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.get('/student/house_automation/create', query: {
        'standard_id': cascade.standardId,
        'opt_sub': optSub,
      });
      if (statusOf(res) != '1') return LegacyApi.messageOf(res, "Couldn't shuffle the students. Try again.");
      final houseNames = <String>{};
      final data = rows(res['student_house']);
      for (final r in data) {
        for (final k in r.keys) {
          if (k.endsWith('_b')) houseNames.add(k.substring(0, k.length - 2));
        }
      }
      result = ShuffleResult(
        message: LegacyApi.messageOf(res, 'Students shuffled.'),
        rows: data,
        houseNames: houseNames.toList(),
        boys: s(res['total_boys']),
        girls: s(res['total_girls']),
        divisions: s(res['total_div']),
      );
      preview = null;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } finally {
      applying = false;
      notifyListeners();
    }
  }
}
