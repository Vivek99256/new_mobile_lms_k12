import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'c_report_ui.dart';

/// Student Homework Submission Report: who handed in which homework. Filter by class / subject / dates on the
/// server (`POST student/student_homework_submission_report`), then narrow by Submitted / Pending and search here.
class CSubmissionReportScreen extends StatefulWidget {
  const CSubmissionReportScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<CSubmissionReportScreen> createState() => _CSubmissionReportScreenState();
}

class _CSubmissionReportScreenState extends State<CSubmissionReportScreen> {
  CascadeSelection _cascade = CascadeSelection();
  DateTime? _from, _to;
  List<Map<String, dynamic>> _all = [];
  Map<String, String> _subjects = {};
  bool _loading = true;
  bool _filtersOpen = false;
  String? _error;
  String _q = '';
  String _tab = 'all'; // all | done | pending

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.args.api.post('/student/student_homework_submission_report', body: {
        if (_cascade.sectionId != null) 'grade': _cascade.sectionId,
        if (_cascade.standardId != null) 'standard': _cascade.standardId,
        if (_cascade.divisionId != null) 'division': _cascade.divisionId,
        if (_cascade.subjectId != null) 'subject': _cascade.subjectId,
        // The server filters by date only when both ends are given.
        if (_from != null && _to != null) 'from_date': ymd(_from!),
        if (_from != null && _to != null) 'to_date': ymd(_to!),
      });
      if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
      _all = rows(res['report_data']);
      _subjects = {for (final r in rows(res['subjects'])) s(r['id']): s(r['subject_name'])};
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the report. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _done(Map<String, dynamic> r) => s(r['completion_status']).toUpperCase() == 'Y';

  List<Map<String, dynamic>> get _shown {
    final q = _q.trim().toLowerCase();
    return [
      for (final r in _all)
        if ((_tab == 'all' || (_tab == 'done') == _done(r)) &&
            (q.isEmpty || '${r['student_name']} ${r['enrollment_no']} ${r['title']} ${r['std_div']}'.toLowerCase().contains(q)))
          r,
    ];
  }

  String _classLabel() {
    final parts = [_cascade.sectionName, _cascade.standardName, _cascade.divisionName, _cascade.subjectName].where((e) => (e ?? '').isNotEmpty).toList();
    return parts.isEmpty ? 'Whole school' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final done = _all.where(_done).length;
    final pct = _all.isEmpty ? 0 : (done * 100 / _all.length).round();
    final shown = _shown;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Homework Submission Report' : widget.args.item.label,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: 1 + (_loading || _error != null || shown.isEmpty ? 1 : shown.length),
          itemBuilder: (_, i) {
            if (i == 0) return _top(done, pct);
            if (_loading) return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()));
            if (_error != null) return KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _load);
            if (shown.isEmpty) {
              return const Padding(padding: EdgeInsets.only(top: 30), child: KitMessage(icon: Icons.assignment_turned_in_outlined, text: 'No homework submissions match this filter.'));
            }
            return _card(shown[i - 1]);
          },
        ),
      ),
    );
  }

  Widget _top(int done, int pct) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CHero(
          icon: Icons.assignment_turned_in_outlined,
          title: 'Homework submissions',
          subtitle: _classLabel(),
          stats: [('Total', '${_all.length}'), ('Submitted', '$done'), ('Pending', '${_all.length - done}'), ('Done', '$pct%')],
        ),
        gap(12),
        _filterCard(),
        gap(12),
        CSearchBox(hint: 'Find a student, GR or homework', onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          PillChip(label: 'All', selected: _tab == 'all', onTap: () => setState(() => _tab = 'all')),
          PillChip(label: 'Submitted', selected: _tab == 'done', onTap: () => setState(() => _tab = 'done')),
          PillChip(label: 'Pending', selected: _tab == 'pending', onTap: () => setState(() => _tab = 'pending')),
        ]),
        gap(12),
      ]);

  Widget _filterCard() => SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _filtersOpen = !_filtersOpen),
            child: Row(children: [
              const IconTile(Icons.tune_rounded, size: 32),
              const SizedBox(width: 10),
              const Expanded(child: Text('Filters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              Icon(_filtersOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Brand.ink3),
            ]),
          ),
          // Kept mounted (just hidden) so the class pickers keep their choices.
          Offstage(
            offstage: !_filtersOpen,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(children: [
                CascadeFilter(api: widget.args.api, withSubject: true, onChanged: (c) => _cascade = c),
                gap(12),
                Row(children: [
                  Expanded(child: DateField(label: 'Submission from', value: _from, onChanged: (d) => setState(() => _from = d))),
                  const SizedBox(width: 10),
                  Expanded(child: DateField(label: 'Submission to', value: _to, onChanged: (d) => setState(() => _to = d))),
                ]),
                if (_from != null || _to != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => setState(() => _from = _to = null), child: const Text('Clear dates')),
                  ),
                gap(8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: _loading
                        ? null
                        : () {
                            if ((_from == null) != (_to == null)) {
                              toast(context, 'Pick both dates, or clear them.', error: true);
                              return;
                            }
                            setState(() => _filtersOpen = false);
                            _load();
                          },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Show report'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      );

  Widget _card(Map<String, dynamic> r) {
    final done = _done(r);
    final subject = _subjects[s(r['subject_id'])] ?? '';
    final due = s(r['SUBMISSION_DATE']);
    final given = s(r['HOMEWORK_DATE']);
    final remark = s(r['teacher_remarks']).isNotEmpty ? s(r['teacher_remarks']) : s(r['submission_remarks']);
    final mobile = s(r['mobile']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PersonAvatar(url: '', name: s(r['student_name']), radius: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s(r['student_name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                Text([if (s(r['enrollment_no']).isNotEmpty) 'GR ${s(r['enrollment_no'])}', s(r['std_div'])].where((e) => e.isNotEmpty).join('  ·  '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.muted, fontSize: 12)),
              ]),
            ),
            done ? const Tag.ok('Submitted') : const Tag.warn('Pending'),
          ]),
          const SizedBox(height: 10),
          Text(s(r['title']).isEmpty ? 'Homework' : s(r['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          if (subject.isNotEmpty) CInfoLine(Icons.menu_book_outlined, subject),
          CInfoLine(Icons.event_outlined, [if (given.isNotEmpty) 'Given $given', if (due.isNotEmpty) 'Due $due'].join('   ·   ')),
          if (remark.isNotEmpty) CInfoLine(Icons.chat_bubble_outline_rounded, remark),
          if (mobile.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(onPressed: () => openUrl(context, 'tel:$mobile'), icon: const Icon(Icons.call_rounded, size: 17), label: Text(mobile)),
            ),
        ]),
      ),
    );
  }
}
