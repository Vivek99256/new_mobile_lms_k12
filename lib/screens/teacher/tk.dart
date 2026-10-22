import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';

/// Helpers shared by the teacher screens (class picker, student list, submit guard).

/// The old app branched on the Admin profile. Any staff profile that is not a plain teacher
/// (Admin, Principal, Trustee...) gets the admin endpoints.
bool isAdmin(ScreenArgs a) => a.session.userProfileName.trim().toLowerCase() != 'teacher';

String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// The old app sent a raw Dart DateTime (`2026-10-06 00:00:00.000`) in many forms.
String dts(DateTime d) => DateTime(d.year, d.month, d.day).toString();

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// `data` as a list of rows. The server sometimes returns a map keyed by anything.
List<Map<String, dynamic>> dataRows(Map<String, dynamic> res, [String key = 'data']) {
  final d = res[key];
  if (d is Map) return rows(d.values.toList());
  return rows(d);
}

/// POST and require success; throws [ApiException] carrying the server message otherwise.
Future<Map<String, dynamic>> postOk(
  LegacyApi api,
  String url, {
  Map<String, dynamic> body = const {},
  List<UploadFile> files = const [],
}) async {
  final res = await api.post(url, body: body, files: files);
  if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
  return res;
}

/// Same for GET.
Future<Map<String, dynamic>> getOk(LegacyApi api, String url, {Map<String, dynamic> query = const {}}) async {
  final res = await api.get(url, query: query);
  if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
  return res;
}

/// Guards a form against double submit and reports the server message.
mixin BusyMixin<T extends StatefulWidget> on State<T> {
  bool busy = false;

  /// Runs [call]; on success toasts the message and (optionally) pops with `true`.
  Future<bool> submit(Future<Map<String, dynamic>> Function() call, {bool pop = true, String fallback = 'Saved.'}) async {
    if (busy) return false;
    setState(() => busy = true);
    var done = false;
    try {
      final res = await call();
      if (!mounted) return false;
      if (LegacyApi.ok(res)) {
        done = true;
        toast(context, LegacyApi.messageOf(res, fallback));
        if (pop) Navigator.pop(context, true);
      } else {
        toast(context, LegacyApi.messageOf(res), error: true);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
    return done;
  }
}

Widget gap([double h = 12]) => SizedBox(height: h);

Widget addAction(BuildContext context, VoidCallback onTap, {String label = 'Add'}) => TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );

/// Attachment chip that opens the file externally.
Widget attachmentButton(BuildContext context, String url, {String label = 'Attachment'}) => url.isEmpty
    ? const SizedBox.shrink()
    : TextButton.icon(
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        onPressed: () => openUrl(context, url),
        icon: const Icon(Icons.attach_file_rounded, size: 18),
        label: Text(label),
      );

Widget titleRow(String title, {Widget? trailing}) => Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Brand.text))),
      ?trailing,
    ]);

/// Two date fields (From / To). Calls [onChanged] whenever either changes.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({super.key, required this.from, required this.to, required this.onChanged});
  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: DateField(label: 'From date', value: from, onChanged: (d) => onChanged(d, d.isAfter(to) ? d : to))),
        const SizedBox(width: 10),
        Expanded(child: DateField(label: 'To date', value: to, onChanged: (d) => onChanged(d.isBefore(from) ? d : from, d))),
      ]);
}

// ---------------------------------------------------------------------------------------
// Class picker
// ---------------------------------------------------------------------------------------

class ClassSel {
  String? sectionId, gradeId, stdId, stdName, divId, divName, subId, subName;
  String get classLabel => [stdName, divName].where((x) => x != null && x.isNotEmpty).join(' - ');
}

/// Standard > Division [> Subject] for a teacher (from the timetable endpoints), or
/// Section > Standard > Division [> Subject] for an admin (school-wide endpoints).
class ClassPicker extends StatefulWidget {
  const ClassPicker({
    super.key,
    required this.api,
    required this.admin,
    required this.onChanged,
    this.withDivision = true,
    this.withSubject = false,
    this.autoSelectFirst = false,
  });
  final LegacyApi api;
  final bool admin;
  final ValueChanged<ClassSel> onChanged;
  final bool withDivision;
  final bool withSubject;
  final bool autoSelectFirst;

  @override
  State<ClassPicker> createState() => _ClassPickerState();
}

class _ClassPickerState extends State<ClassPicker> {
  final sel = ClassSel();
  List<Opt> sections = [], standards = [], divisions = [], subjects = [];
  final Map<String, String> _gradeOf = {};
  bool loadingSec = false, loadingStd = true, loadingDiv = false, loadingSub = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.admin) {
      loadingSec = true;
      loadingStd = false;
      _sections();
    } else {
      _standards();
    }
  }

  Future<List<Map<String, dynamic>>> _fetch(String path, [Map<String, dynamic> extra = const {}]) async {
    try {
      final res = await widget.api.post(path, body: extra);
      if (!LegacyApi.ok(res)) {
        if (mounted) setState(() => _error = LegacyApi.messageOf(res, 'Could not load the list.'));
        return const [];
      }
      return dataRows(res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return const [];
    }
  }

  Future<void> _sections() async {
    final r = await _fetch('/get_adminAcademicSection');
    if (!mounted) return;
    setState(() {
      sections = [for (final x in r) Opt(s(x['id']), s(x['short_name']).isEmpty ? s(x['title']) : s(x['short_name']))];
      loadingSec = false;
    });
  }

  Future<void> _standards([String? gradeId]) async {
    setState(() {
      loadingStd = true;
      _error = null;
    });
    final r = widget.admin ? await _fetch('/get_adminStandard', {'grade_id': gradeId}) : await _fetch('/get_teacher_timetablewiseStandard');
    if (!mounted) return;
    final seen = <String>{};
    final list = <Opt>[];
    for (final x in r) {
      final id = s(widget.admin ? x['id'] : x['std_id']);
      final name = s(widget.admin ? x['name'] : x['std_name']);
      if (id.isEmpty || !seen.add(id)) continue;
      list.add(Opt(id, name));
      _gradeOf[id] = s(x['grade_id']);
    }
    setState(() {
      standards = list;
      loadingStd = false;
    });
    if (widget.autoSelectFirst && list.isNotEmpty && sel.stdId == null) _pickStandard(list.first.id);
  }

  Future<void> _pickSection(String? id) async {
    sel
      ..sectionId = id
      ..gradeId = id
      ..stdId = null
      ..stdName = null
      ..divId = null
      ..divName = null
      ..subId = null
      ..subName = null;
    setState(() {
      standards = [];
      divisions = [];
      subjects = [];
    });
    widget.onChanged(sel);
    await _standards(id);
  }

  Future<void> _pickStandard(String? id) async {
    sel
      ..stdId = id
      ..stdName = standards.where((o) => o.id == id).firstOrNull?.label
      ..gradeId = widget.admin ? sel.sectionId : _gradeOf[id]
      ..divId = null
      ..divName = null
      ..subId = null
      ..subName = null;
    setState(() {
      divisions = [];
      subjects = [];
      loadingDiv = widget.withDivision;
      loadingSub = widget.withSubject;
    });
    widget.onChanged(sel);
    final jobs = <Future<void>>[];
    if (widget.withDivision) {
      jobs.add((widget.admin ? _fetch('/get_adminDivision', {'standard_id': id}) : _fetch('/get_teacher_timetablewiseDivision', {'standard_id': id})).then((r) {
        if (!mounted || sel.stdId != id) return;
        setState(() {
          divisions = [for (final x in r) Opt(s(widget.admin ? x['id'] : x['div_id']), s(widget.admin ? x['name'] : x['div_name']))];
          loadingDiv = false;
        });
      }));
    }
    if (widget.withSubject) {
      jobs.add((widget.admin ? _fetch('/get_adminSubject', {'standard_id': id}) : _fetch('/get_teacher_timetablewiseSubject', {'standard_id': id})).then((r) {
        if (!mounted || sel.stdId != id) return;
        final seen = <String>{};
        setState(() {
          subjects = [
            for (final x in r)
              if (seen.add(s(widget.admin ? x['subject_id'] : x['sub_id'])))
                Opt(s(widget.admin ? x['subject_id'] : x['sub_id']), s(widget.admin ? x['subject_name'] : x['sub_name']))
          ];
          loadingSub = false;
        });
      }));
    }
    await Future.wait(jobs);
    if (mounted) {
      setState(() {
        loadingDiv = false;
        loadingSub = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.admin) ...[
          DropdownField(label: 'Section', options: sections, value: sel.sectionId, loading: loadingSec, onChanged: _pickSection),
          gap(),
        ],
        DropdownField(label: 'Standard', options: standards, value: sel.stdId, loading: loadingStd, onChanged: _pickStandard),
        if (!loadingStd && standards.isEmpty && (!widget.admin || sel.sectionId != null))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error ?? (widget.admin ? 'No standards found for this section.' : 'No classes are linked to your timetable yet.'),
                style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ),
        if (widget.withDivision) ...[
          gap(),
          DropdownField(
            label: 'Division',
            options: divisions,
            value: sel.divId,
            loading: loadingDiv,
            onChanged: (id) {
              sel
                ..divId = id
                ..divName = divisions.where((o) => o.id == id).firstOrNull?.label;
              setState(() {});
              widget.onChanged(sel);
            },
          ),
        ],
        if (widget.withSubject) ...[
          gap(),
          DropdownField(
            label: 'Subject',
            options: subjects,
            value: sel.subId,
            loading: loadingSub,
            onChanged: (id) {
              sel
                ..subId = id
                ..subName = subjects.where((o) => o.id == id).firstOrNull?.label;
              setState(() {});
              widget.onChanged(sel);
            },
          ),
        ],
      ]);
}

// ---------------------------------------------------------------------------------------
// Students
// ---------------------------------------------------------------------------------------

Future<List<Map<String, dynamic>>> loadStudents(LegacyApi api, ClassSel c, {String url = '/allStudentListAPI'}) async {
  final res = await api.post(url, body: {
    'standard_id': c.stdId,
    'division_id': c.divId,
    if (c.gradeId != null) 'grade_id': c.gradeId,
  });
  if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res, 'No students found.'));
  return dataRows(res);
}

/// Attendance already saved for a class and date.
class SavedAttendance {
  const SavedAttendance(this.codes, {this.note});

  /// student id -> 'P' | 'A'
  final Map<String, String> codes;

  /// Why nothing could be loaded (holiday, outside the academic year, a failed call), if so.
  final String? note;
}

/// Reads the marks already saved for [c] on [date] from the ERP's `show_student_attendance`
/// (the call the web register uses; it returns `attendance_data`: student id -> code).
Future<SavedAttendance> loadSavedAttendance(LegacyApi api, ClassSel c, DateTime date) async {
  try {
    final res = await api.post('/student/show_student_attendance', body: {
      'standard_division': '${c.stdId}||${c.divId}',
      // Plain yyyy-MM-dd: this endpoint string-compares the date with the academic year's
      // start/end, so the old app's `2026-10-09 00:00:00.000` is rejected.
      'date': ymd(date),
      'term_id': api.session.raw['term_id'] ?? '',
    });
    final saved = res['attendance_data'];
    final codes = saved is Map
        ? {
            for (final e in saved.entries)
              if ('${e.value}' == 'P' || '${e.value}' == 'A') '${e.key}': '${e.value}',
          }
        : <String, String>{};
    // A status of 0 carries the reason (holiday, Sunday, outside the academic year).
    final note = LegacyApi.ok(res) || codes.isNotEmpty ? null : LegacyApi.messageOf(res, '');
    return SavedAttendance(codes, note: (note ?? '').isEmpty ? null : note);
  } on ApiException catch (e) {
    return SavedAttendance(const {}, note: 'Saved attendance could not be loaded: ${e.message}');
  }
}

class StudentTile extends StatelessWidget {
  const StudentTile({super.key, required this.st, this.onTap, this.trailing});
  final Map<String, dynamic> st;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cls = [s(st['standard_name']), s(st['division_name'])].where((e) => e.isNotEmpty).join(' - ');
    return KitCard(
      onTap: onTap,
      child: Row(children: [
        PersonAvatar(url: s(st['student_image']), name: s(st['student_name'])),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s(st['student_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            if (cls.isNotEmpty) Text(cls, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            Text([
              if (s(st['roll_no']).isNotEmpty) 'Roll No. ${s(st['roll_no'])}',
              if (s(st['enrollment_no']).isNotEmpty) 'GR No. ${s(st['enrollment_no'])}',
            ].join('  |  '), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            if (s(st['mobile']).isNotEmpty) Text('+91${s(st['mobile'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// "Select all" + one checkbox row per student. Selection is keyed by student `id`.
class StudentChecklist extends StatelessWidget {
  const StudentChecklist({super.key, required this.students, required this.selected, required this.onChanged});
  final List<Map<String, dynamic>> students;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = students.isNotEmpty && students.every((x) => selected.contains(s(x['id'])));
    return Column(children: [
      KitCard(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        // The card paints a white decoration; the ListTile needs its own Material to draw ink on.
        child: Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            value: all,
            title: Text('Select all (${selected.length}/${students.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
            onChanged: (v) => onChanged(v == true ? {for (final x in students) s(x['id'])} : <String>{}),
          ),
        ),
      ),
      for (final st in students) ...[
        gap(8),
        StudentTile(
          st: st,
          onTap: () {
            final id = s(st['id']);
            onChanged(selected.contains(id) ? ({...selected}..remove(id)) : {...selected, id});
          },
          trailing: Checkbox(
            value: selected.contains(s(st['id'])),
            onChanged: (v) {
              final id = s(st['id']);
              onChanged(v == true ? {...selected, id} : ({...selected}..remove(id)));
            },
          ),
        ),
      ],
    ]);
  }
}

/// Small card section wrapper for forms.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children, this.title});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => KitCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[titleRow(title!), gap()],
          for (var i = 0; i < children.length; i++) ...[if (i > 0) gap(), children[i]],
        ]),
      );
}

/// A page with a title, optional date-range / filter header and an [AsyncList].
class ListPage extends StatelessWidget {
  const ListPage({
    super.key,
    required this.title,
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
    this.actions = const [],
    this.header,
    this.controller,
    this.emptyIcon = Icons.inbox_outlined,
    this.bottom,
  });
  final String title;
  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(BuildContext, Map<String, dynamic>, int) itemBuilder;
  final String emptyText;
  final List<Widget> actions;
  final Widget? header;
  final AsyncListController? controller;
  final IconData emptyIcon;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => KitPage(
        title: title,
        actions: actions,
        bottom: bottom,
        child: AsyncList(load: load, itemBuilder: itemBuilder, emptyText: emptyText, emptyIcon: emptyIcon, header: header, controller: controller),
      );
}

/// A list page with From/To pickers that reloads whenever the range changes.
class RangeListPage extends StatefulWidget {
  const RangeListPage({
    super.key,
    required this.title,
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
    this.actions = const [],
    this.onAdd,
    this.controller,
    this.emptyIcon = Icons.inbox_outlined,
  });
  final String title;
  final Future<List<Map<String, dynamic>>> Function(DateTime from, DateTime to) load;
  final Widget Function(BuildContext, Map<String, dynamic>, int) itemBuilder;
  final String emptyText;
  final List<Widget> actions;

  /// Opens the add form; the list reloads when it pops.
  final Future<void> Function()? onAdd;
  final AsyncListController? controller;
  final IconData emptyIcon;

  @override
  State<RangeListPage> createState() => _RangeListPageState();
}

class _RangeListPageState extends State<RangeListPage> {
  DateTime from = today(), to = today();
  late final AsyncListController ctrl = widget.controller ?? AsyncListController();

  @override
  Widget build(BuildContext context) => ListPage(
        title: widget.title,
        controller: ctrl,
        emptyText: widget.emptyText,
        emptyIcon: widget.emptyIcon,
        actions: [
          ...widget.actions,
          if (widget.onAdd != null)
            addAction(context, () async {
              await widget.onAdd!();
              if (mounted) ctrl.reload();
            }),
        ],
        header: DateRangeBar(
          from: from,
          to: to,
          onChanged: (f, t) {
            setState(() {
              from = f;
              to = t;
            });
            ctrl.reload();
          },
        ),
        load: () => widget.load(from, to),
        itemBuilder: widget.itemBuilder,
      );
}
