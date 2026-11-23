import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'student_shuffling_controller.dart';

/// Student Shuffling (house automation): spreads the students of a standard evenly over its divisions, house by house and boys / girls separately.
class StudentShufflingScreen extends StatefulWidget {
  const StudentShufflingScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentShufflingScreen> createState() => _StudentShufflingScreenState();
}

class _StudentShufflingScreenState extends State<StudentShufflingScreen> {
  late final StudentShufflingController _con = StudentShufflingController(args: widget.args)..addListener(_onChange);

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final c = _con;
    final p = c.preview;
    final std = c.cascade.standardName ?? 'this standard';
    final go = await confirm(
      context,
      'Shuffle $std now?',
      c.optionalSubjects
          ? 'Students of $std will be moved between divisions by their optional subjects. This changes their divisions immediately and cannot be undone.'
          : 'About ${p == null ? 'all' : p.boys + p.girls} students of $std will be redistributed across its divisions. This changes their divisions immediately and cannot be undone.',
      yes: 'Shuffle',
    );
    if (!go || !mounted) return;
    final err = await c.apply();
    if (!mounted) return;
    if (err != null) {
      toast(context, err, error: true);
    } else {
      toast(context, c.result?.message ?? 'Students shuffled.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _con;
    final title = widget.args.item.label.isEmpty ? 'Student Shuffling' : widget.args.item.label;
    final p = c.preview;
    final canApply = p != null && !c.applying && (p.divisions.isNotEmpty || !p.estimated);
    return KitPage(
      title: title,
      bottom: p == null ? null : formBar(label: 'Apply shuffle', busy: c.applying, onPressed: canApply ? _apply : null, color: Brand.err),
      child: withStudentInputs(
        context,
        ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          SoftCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Choose what to shuffle', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              CascadeFilter(api: widget.args.api, withDivision: false, onChanged: c.setCascade),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Students have optional subjects', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text('Group by optional subject instead of equal split', style: TextStyle(fontSize: 12)),
                value: c.optionalSubjects,
                onChanged: c.setOptional,
              ),
              gap(8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: c.hasStandard && !c.previewing ? c.loadPreview : null,
                  icon: c.previewing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.visibility_outlined),
                  label: Text(c.previewing ? 'Preparing preview…' : 'Preview shuffle'),
                ),
              ),
            ]),
          ),
          gap(14),
          if (c.error != null) ...[Notice(c.error!, kind: NoticeKind.error), gap(12)],
          if (c.result != null) _result(c.result!),
          if (p != null) ..._preview(p),
        ]),
      ),
    );
  }

  List<Widget> _preview(ShufflePreview p) => [
        NavyStats(
          stats: [('boys', '${p.boys}'), ('girls', '${p.girls}'), ('divisions', '${p.divisions.length}'), ('houses', '${p.houseCount}')],
          caption: p.standardName.isEmpty ? null : 'Preview for ${p.standardName}. Nothing has changed yet.',
        ),
        gap(12),
        if (!p.estimated)
          const Notice('With optional subjects, students are grouped by their subject, so the new split cannot be previewed. Today\'s division sizes are shown.', kind: NoticeKind.warn)
        else
          const Notice('Estimated split. Each division may differ by one student from the final result.', kind: NoticeKind.info),
        if (p.skipped > 0) ...[
          gap(10),
          Notice('${p.skipped} student${p.skipped == 1 ? '' : 's'} without a house or a Male / Female gender will not be moved.', kind: NoticeKind.warn),
        ],
        if (p.estimated && p.divisions.isEmpty) ...[
          gap(10),
          const Notice('This standard has no divisions to shuffle into.', kind: NoticeKind.error),
        ],
        gap(12),
        for (final d in p.divisions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              radius: 18,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const IconTile(Icons.groups_2_outlined, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Division ${d.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  Text('${d.before}', style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
                  if (p.estimated) ...[
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 16, color: Brand.muted)),
                    Text('${d.after}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Brand.primaryDark)),
                  ],
                ]),
                if (d.houses.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final h in d.houses) Tag.neutral('${h.house}  ${h.boys}B ${h.girls}G')]),
                ],
              ]),
            ),
          ),
      ];

  Widget _result(ShuffleResult r) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Notice(r.message, kind: NoticeKind.ok),
          gap(10),
          NavyStats(stats: [('boys', r.boys), ('girls', r.girls), ('divisions', r.divisions)], caption: 'Result of the shuffle, as saved.'),
          gap(10),
          for (final row in r.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Division ${s(row['division'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final h in r.houseNames) Tag.neutral('$h  ${s(row['${h}_b'])}B ${s(row['${h}_g'])}G'),
                  ]),
                ]),
              ),
            ),
        ]),
      );
}
