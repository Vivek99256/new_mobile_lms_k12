import 'package:flutter/material.dart';

import '../../ui/design.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'tk.dart';

/// t_take_attendance: pick a class and date, mark every student Present / Absent.
class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen>
    with BusyMixin {
  ClassSel sel = ClassSel();
  DateTime date = today();
  List<Map<String, dynamic>>? students;
  final Map<String, String> code = {}; // student id -> 'P' | 'A'
  bool loading = false;
  String? savedNote; // why saved marks could not be shown, if they could not
  bool hadSaved = false; // the marks on screen were loaded from a previous save
  String? error;

  Future<void> _search() async {
    setState(() {
      loading = true;
      error = null;
      students = null;
      hadSaved = false;
      savedNote = null;
      code.clear();
    });
    try {
      final results = await Future.wait([
        loadStudents(widget.args.api, sel),
        loadSavedAttendance(widget.args.api, sel, date),
      ]);
      if (mounted) {
        setState(() {
          students = results[0] as List<Map<String, dynamic>>;
          // Show what was saved before; the teacher can change it and save again.
          final saved = results[1] as SavedAttendance;
          code.addAll(saved.codes);
          hadSaved = code.isNotEmpty;
          savedNote = saved.note;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _all(String c) => setState(() {
    for (final st in students ?? const <Map<String, dynamic>>[]) {
      code[s(st['id'])] = c;
    }
  });

  Future<void> _save() async {
    final list = students ?? const <Map<String, dynamic>>[];
    await submit(
      () => postOk(
        widget.args.api,
        '/student/save_student_attendance',
        body: {
          'standard_division': '${sel.stdId}||${sel.divId}',
          'date': dts(date),
          for (final st in list)
            'student[${s(st['id'])}]': code[s(st['id'])] ?? '',
        },
      ),
      fallback: 'Attendance saved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final list = students;
    final marked = code.values.where((v) => v == 'P' || v == 'A').length;
    final present = code.values.where((v) => v == 'P').length;
    return KitPage(
      title: a.title.isEmpty ? 'Take attendance' : a.title,
      bottom: list == null || list.isEmpty
          ? null
          : Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$present present · ${marked - present} absent',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        hadSaved
                            ? 'Saved earlier · change and save to update'
                            : marked == list.length
                            ? 'Ready to save'
                            : 'Not saved yet · ${list.length - marked} unmarked',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.33,
                          fontWeight: FontWeight.w500,
                          color: Brand.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 168,
                  child: PrimaryButton(
                    label: 'Save attendance',
                    busy: busy,
                    onPressed: marked == 0 ? null : _save,
                  ),
                ),
              ],
            ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormCard(
            children: [
              ClassPicker(
                api: a.api,
                admin: isAdmin(a),
                onChanged: (c) => setState(() => sel = c),
              ),
              DateField(
                label: 'Date',
                value: date,
                onChanged: (d) => setState(() => date = d),
              ),
              PrimaryButton(
                label: 'Search',
                busy: loading,
                onPressed: sel.divId == null ? null : _search,
              ),
            ],
          ),
          gap(),
          if (error != null)
            KitMessage(
              icon: Icons.search_off_rounded,
              text: error!,
              action: 'Try again',
              onAction: _search,
            ),
          if (list != null && list.isEmpty)
            const KitMessage(
              icon: Icons.groups_outlined,
              text: 'No students found in this class.',
            ),
          if (list != null && list.isNotEmpty && savedNote != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Brand.warn0,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Brand.warn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      savedNote!,
                      style: const TextStyle(color: Brand.warn, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            gap(12),
          ],
          if (list != null && list.isNotEmpty) ...[
            Row(
              children: [
                Tag.ok('Present $present'),
                const SizedBox(width: 8),
                Tag.err('Absent ${marked - present}'),
                if (marked < list.length) ...[
                  const SizedBox(width: 8),
                  Tag.neutral('Unmarked ${list.length - marked}'),
                ],
                const Spacer(),
                Text(
                  '${sel.classLabel} · ${list.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.33,
                    fontWeight: FontWeight.w500,
                    color: Brand.ink3,
                  ),
                ),
              ],
            ),
            gap(12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _all('P'),
                    child: const Text('Mark all present'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _all('A'),
                    child: const Text('Mark all absent'),
                  ),
                ),
              ],
            ),
            gap(12),
            SoftCard(
              clip: true,
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    Container(
                      constraints: const BoxConstraints(minHeight: 64),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: i == list.length - 1
                            ? null
                            : const Border(
                                bottom: BorderSide(color: Brand.line),
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Brand.field,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              s(list[i]['roll_no']).isEmpty
                                  ? '${i + 1}'
                                  : s(list[i]['roll_no']),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Brand.ink2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s(list[i]['student_name']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'GR no. ${s(list[i]['enrollment_no'])}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.33,
                                    fontWeight: FontWeight.w500,
                                    color: Brand.ink3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _PA(
                            value: code[s(list[i]['id'])],
                            onChanged: (v) =>
                                setState(() => code[s(list[i]['id'])] = v),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PA extends StatelessWidget {
  const _PA({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(String c, Color color) {
      final on = value == c;
      return Semantics(
        button: true,
        selected: on,
        label: c == 'P' ? 'Present' : 'Absent',
        child: GestureDetector(
          onTap: () => onChanged(c),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? color : Brand.border),
            ),
            child: Text(
              c,
              style: TextStyle(
                color: on ? Colors.white : Brand.ink3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn('P', Brand.ok),
        const SizedBox(width: 4),
        btn('A', Brand.err),
      ],
    );
  }
}

/// t_teacher_dairy: lesson planning.
class LessonPlanningScreen extends StatefulWidget {
  const LessonPlanningScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<LessonPlanningScreen> createState() => _LessonPlanningScreenState();
}

class _LessonPlanningScreenState extends State<LessonPlanningScreen>
    with BusyMixin {
  ClassSel sel = ClassSel();
  DateTime date = today();
  final title = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: a.title.isEmpty ? 'Lesson planning' : a.title,
      bottom: PrimaryButton(
        label: 'Submit',
        busy: busy,
        onPressed: () {
          if (sel.stdId == null || sel.divId == null || sel.subId == null)
            return toast(
              context,
              'Select a standard, division and subject.',
              error: true,
            );
          if (title.text.trim().isEmpty)
            return toast(context, 'Please enter a title.', error: true);
          submit(
            () => postOk(
              a.api,
              '/add_teacherLessonPlanning',
              body: {
                'standard_id': sel.stdId,
                'division_id': sel.divId,
                'subject_id': sel.subId,
                'date': dts(date),
                'title': title.text.trim(),
              },
            ),
          );
        },
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormCard(
            children: [
              ClassPicker(
                api: a.api,
                admin: isAdmin(a),
                withSubject: true,
                onChanged: (c) => sel = c,
              ),
              TextInput(label: 'Title', controller: title),
              DateField(
                label: 'Date',
                value: date,
                onChanged: (d) => setState(() => date = d),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
