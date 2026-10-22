import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';
import 'camera_helper.dart';

/// Photo-based attendance: capture class photos, let the server recognise students, correct
/// the result by hand and save it. [isAdmin] is kept for the teacher/admin contract; both
/// roles pick the class with the cascade filter because the new login has no
/// `standard_division`.
class CaptureAttendanceScreen extends StatefulWidget {
  const CaptureAttendanceScreen({super.key, required this.args, required this.isAdmin});
  final ScreenArgs args;
  final bool isAdmin;

  @override
  State<CaptureAttendanceScreen> createState() => _CaptureAttendanceScreenState();
}

class _CaptureAttendanceScreenState extends State<CaptureAttendanceScreen> with SubmitGuard {
  LegacyApi get api => widget.args.api;
  CascadeSelection sel = CascadeSelection();
  DateTime date = DateTime.now();
  final photos = <String>[];

  /// Step 2: recognised/manual roster. Null while still in step 1.
  List<Map<String, dynamic>>? results;
  final status = <String, String>{}; // student id -> P | A

  String get _classLabel => [sel.standardName, sel.divisionName].whereType<String>().join(' - ');

  Future<void> _capture() async {
    final p = await takePhoto(context);
    if (p != null && mounted) setState(() => photos.add(p));
  }

  Future<void> _submitPhotos() async {
    if (sel.standardId == null || sel.divisionId == null) {
      toast(context, 'Please select a standard and division.', error: true);
      return;
    }
    if (photos.isEmpty) {
      toast(context, 'Please capture at least one photo.', error: true);
      return;
    }
    await guarded(() async {
      final a = await api.post('/add_studentCaptureAttendanceAPI',
          body: {'date': ymd(date), 'standard_id': sel.standardId, 'division_id': sel.divisionId},
          files: [for (var i = 0; i < photos.length; i++) UploadFile('image[$i]', photos[i])]);
      if (!mounted) return;
      if (!submitOk(a)) {
        toast(context, LegacyApi.messageOf(a), error: true);
        return;
      }
      // Assumption: the upload response carries the recognised students (same shape the old
      // stub json_data had); hand those to get_attendanceDataAPI, otherwise send the class.
      final recognised = a['data'] is List ? rows(a['data']) : <Map<String, dynamic>>[];
      final payload = recognised.isNotEmpty
          ? recognised
          : [
              {'standard_id': sel.standardId, 'division_id': sel.divisionId, 'attendance_date': ymd(date)}
            ];
      final b = await api.post('/get_attendanceDataAPI', body: {'json_data': jsonEncode(payload)});
      if (!mounted) return;
      var list = submitOk(b) ? rows(b['data']) : <Map<String, dynamic>>[];
      list = list.where((r) => s(r['student_id']).isNotEmpty).toList();
      if (list.isEmpty) {
        // Nothing recognised: fall back to the class roster so attendance can be marked by hand.
        final r = await api.post('/get_adminStudentList', body: {
          'grade_id': sel.sectionId,
          'standard_id': sel.standardId,
          'division_id': sel.divisionId,
        });
        if (!mounted) return;
        list = [
          for (final st in rows(r['data'])) {...st, 'student_id': s(st['id']), 'attendance_code': 'A'}
        ];
        if (list.isNotEmpty) toast(context, 'No students were recognised. Mark attendance by hand.');
      }
      setState(() {
        results = list;
        status
          ..clear()
          ..addEntries([for (final r in list) MapEntry(s(r['student_id']), s(r['attendance_code']).toUpperCase() == 'P' ? 'P' : 'A')]);
      });
    });
  }

  Future<void> _save() async {
    final list = results ?? const [];
    if (list.isEmpty) return;
    await guarded(() async {
      final res = await api.post('/student/save_student_attendance', body: {
        'teacher_id': widget.args.session.userId,
        'standard_division': '${sel.standardId}||${sel.divisionId}',
        'date': ymd(date),
        for (final r in list) 'student[${s(r['student_id'])}]': status[s(r['student_id'])] ?? 'A',
      });
      if (!mounted) return;
      if (report(res, ok: 'Attendance saved.')) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inResults = results != null;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Capture attendance' : widget.args.item.label,
      bottom: inResults
          ? formBar(label: 'Save attendance', busy: busy, onPressed: results!.isEmpty ? null : _save)
          : formBar(label: 'Upload photos', busy: busy, onPressed: sel.divisionId == null ? null : _submitPhotos),
      child: inResults ? _resultsView() : _captureView(),
    );
  }

  Widget _captureView() => ListView(padding: const EdgeInsets.all(16), children: [
        CascadeFilter(api: api, onChanged: (v) => setState(() => sel = v)),
        gap(),
        DateField(label: 'Date', value: date, onChanged: (d) => setState(() => date = d)),
        gap(16),
        const SectionLabel('Class photos'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (var i = 0; i < photos.length; i++) PhotoTile(path: photos[i], done: true, onRemove: () => setState(() => photos.removeAt(i))),
            AddPhotoTile(onTap: _capture),
          ],
        ),
      ]);

  Widget _resultsView() {
    final list = results!;
    if (list.isEmpty) {
      return KitMessage(icon: Icons.people_outline, text: 'No students found for this class.', action: 'Back', onAction: () => setState(() => results = null));
    }
    final present = status.values.where((v) => v == 'P').length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      KitCard(
        child: Row(children: [
          Expanded(
            child: Text('$_classLabel  |  ${fmtDate(ymd(date))}\n$present present, ${list.length - present} absent',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          TextButton(onPressed: () => setState(() => status.updateAll((_, _) => 'P')), child: const Text('All present')),
          TextButton(onPressed: () => setState(() => status.updateAll((_, _) => 'A')), child: const Text('All absent')),
        ]),
      ),
      gap(),
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: KitCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s(r['student_name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Roll ${s(r['roll_no'])}  |  GR ${s(r['enrollment_no'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: 'P', label: Text('P')), ButtonSegment(value: 'A', label: Text('A'))],
                selected: {status[s(r['student_id'])] ?? 'A'},
                onSelectionChanged: (v) => setState(() => status[s(r['student_id'])] = v.first),
              ),
            ]),
          ),
        ),
    ]);
  }
}
