import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'student_common.dart';

/// School-information screens: one endpoint, `action` picks the page, HTML cards.
Widget schoolInfoScreen(ScreenArgs a, {required String action, String? fixedTitle, bool principal = false, bool fixedUrl = false}) =>
    SimpleList(
      args: a,
      title: fixedTitle ?? titleOf(a, action),
      url: fixedUrl ? '/schoolDetailAPI' : Sx.url(a, '/schoolDetailAPI'),
      body: {'action': action},
      emptyText: 'This information has not been added yet.',
      emptyIcon: Icons.info_outline_rounded,
      itemBuilder: (c, r, i) => KitCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (principal)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                IconBubble(icon: Icons.person_outline_rounded, accent: Brand.accent(i), size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Principal', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                    Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                ),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(child: Text(s(r['title']), textAlign: TextAlign.center, style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w800, fontSize: 17))),
            ),
          HtmlBlock(s(r['description'])),
        ]),
      ),
    );

/// Certificates the school issued, rendered from their HTML.
Widget certificateListScreen(ScreenArgs a) => SimpleList(
      args: a,
      title: 'Certificates',
      url: Sx.url(a, '/studentCertificateAPI'),
      emptyText: 'No certificates have been issued to you.',
      emptyIcon: Icons.workspace_premium_outlined,
      itemBuilder: (c, r, i) {
        final n = s(r['certificate_number']);
        final tone = n == '1' ? const Color(0xFFD4A017) : (n == '2' ? const Color(0xFF94A3B8) : const Color(0xFFB45309));
        return KitCard(
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => CertificateView(html: s(r['certificate_html']), title: s(r['certificate_type'])))),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: tone.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.workspace_premium_rounded, color: tone, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(s(r['certificate_type']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            const Icon(Icons.chevron_right_rounded, color: Brand.muted),
          ]),
        );
      },
    );

class CertificateView extends StatelessWidget {
  const CertificateView({super.key, required this.html, required this.title});
  final String html;
  final String title;

  @override
  Widget build(BuildContext context) => KitPage(
        title: title.isEmpty ? 'Certificate' : title,
        child: html.isEmpty
            ? const KitMessage(icon: Icons.description_outlined, text: 'This certificate has no content.')
            : SingleChildScrollView(padding: const EdgeInsets.all(16), child: KitCard(child: HtmlBlock(html))),
      );
}

/// Classwork gallery: attachments sent in a date range (default today).
class ClassworkScreen extends StatefulWidget {
  const ClassworkScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<ClassworkScreen> createState() => _ClassworkScreenState();
}

class _ClassworkScreenState extends State<ClassworkScreen> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  final _ctl = AsyncListController();

  String _d(DateTime d) => fmtDate(d.toIso8601String(), out: 'yyyy-MM-dd');

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Classwork gallery',
        child: AsyncList(
          key: ValueKey('${_d(_from)}-${_d(_to)}'),
          controller: _ctl,
          emptyText: 'No classwork was shared in this period.',
          emptyIcon: Icons.photo_library_outlined,
          header: Row(children: [
            Expanded(child: DateField(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
            const SizedBox(width: 10),
            Expanded(child: DateField(label: 'To', value: _to, first: _from, onChanged: (d) => setState(() => _to = d))),
          ]),
          load: () async {
            final res = await widget.args.api.get('/front_desk/send_attachment/create', query: {'from_date': _d(_from), 'to_date': _d(_to)});
            if (res['sentData'] == null && !LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
            return rows(res['sentData']);
          },
          itemBuilder: (c, r, i) => KitCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(fmtDate(r['created_at'], out: 'dd-MM-yyyy').isEmpty ? '-' : fmtDate(r['created_at'], out: 'dd-MM-yyyy'), style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
              AttachmentButton(s(r['file_path']), label: 'Open'),
            ]),
          ),
        ),
      );
}

/// WRT progress report: pick an exam type and date range, then open the report.
class WrtProgressScreen extends StatefulWidget {
  const WrtProgressScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<WrtProgressScreen> createState() => _WrtProgressScreenState();
}

class _WrtProgressScreenState extends State<WrtProgressScreen> {
  List<Opt> _exams = [];
  String? _exam;
  DateTime? _from, _to;
  bool _loadingExams = true, _searching = false, _searched = false;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    try {
      final a = widget.args;
      final std = Sx.raw(a, 'standard_id');
      // Newer token-scoped dropdown first (`id`, `name`); legacy `/result/exam_master` once if it fails.
      final exams = await Sx.newThenLegacy<List<Opt>>(
        'wrt_progress exam dropdown',
        () async {
          final res = await a.api.get('/api/result/exam-master/dropdown', query: {'standard_id': std}, withIdentity: false);
          if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
          return [for (final e in rows(res['data'])) Opt(s(e['id']), s(e['name']))];
        },
        () async {
          final res = await a.api.get('/result/exam_master', query: {'standard_id': std});
          if (!LegacyApi.ok(res)) throw ApiException(LegacyApi.messageOf(res));
          // The legacy payload capitalises its keys (`Id`, `ExamTitle`).
          return [for (final e in rows(res['data'])) Opt(s(e['Id'] ?? e['id']), s(e['ExamTitle'] ?? e['exam_title']))];
        },
      );
      if (mounted) _exams = exams;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
    if (mounted) setState(() => _loadingExams = false);
  }

  String? _fmt(DateTime? d) => d == null ? null : fmtDate(d.toIso8601String(), out: 'yyyy-MM-dd');

  Future<void> _search() async {
    if (_searching) return;
    setState(() => _searching = true);
    try {
      final res = await widget.args.api.post('/get_wrtreportAPI', body: {'from_date': _fmt(_from), 'to_date': _fmt(_to), 'exam_type': _exam});
      if (!mounted) return;
      if (LegacyApi.ok(res)) {
        final d = res['data'];
        _report = d is List ? (d.isEmpty ? null : m(d.first)) : (d is Map ? m(d) : null);
      } else {
        _report = null;
        toast(context, LegacyApi.messageOf(res), error: true);
      }
      _searched = true;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'WRT progress reports',
        child: ListView(padding: const EdgeInsets.all(16), children: [
          DropdownField(label: 'Exam type', options: _exams, value: _exam, loading: _loadingExams, onChanged: (v) => setState(() => _exam = v)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DateField(label: 'From date', value: _from, onChanged: (d) => setState(() => _from = d))),
            const SizedBox(width: 10),
            Expanded(child: DateField(label: 'To date', value: _to, first: _from, onChanged: (d) => setState(() => _to = d))),
          ]),
          const SizedBox(height: 14),
          PrimaryButton(label: 'Search', busy: _searching, onPressed: _search),
          const SizedBox(height: 16),
          if (_searched && (_report == null || s(_report!['file_name']).isEmpty && s(_report!['title']).isEmpty))
            const KitMessage(icon: Icons.search_off_rounded, text: 'No report was found for these filters.')
          else if (_report != null)
            KitCard(
              onTap: s(_report!['file_name']).isEmpty ? null : () => openUrl(context, s(_report!['file_name'])),
              child: Row(children: [
                const Icon(Icons.description_outlined, color: Brand.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(s(_report!['title']), style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w800, fontSize: 15))),
                const Icon(Icons.open_in_new_rounded, color: Brand.muted),
              ]),
            ),
        ]),
      );
}
