import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../core/config.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'student_certificate_controller.dart';

/// Student Certificate: search students, pick a template, preview the certificate, issue it,
/// and look through the certificates issued before.
class StudentCertificateScreen extends StatefulWidget {
  const StudentCertificateScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentCertificateScreen> createState() => _StudentCertificateScreenState();
}

class _StudentCertificateScreenState extends State<StudentCertificateScreen> {
  late final StudentCertificateController _con = StudentCertificateController(args: widget.args)..addListener(_onChange);
  int _tab = 0; // 0 = issue, 1 = history
  bool _changing = true; // show the search panel

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.loadTemplates();
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    await _con.searchStudents();
    if (mounted && _con.students.isNotEmpty) setState(() => _changing = false);
  }

  Future<void> _preview() async {
    final (p, msg) = await _con.preview();
    if (!mounted) return;
    if (p == null) {
      toast(context, msg, error: true);
      return;
    }
    final issued = await push<bool>(context, _CertificatePreview(con: _con, preview: p));
    if (issued == true && mounted) {
      setState(() => _tab = 1);
      _con.loadHistory(type: p.template);
    }
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const IconTile(Icons.workspace_premium_outlined, size: 46, fg: Colors.white, bg: Color(0x22FFFFFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Student certificates', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                _tab == 0
                    ? (_con.selected.isEmpty ? 'Search students, then pick who to issue to.' : '${_con.selected.length} student(s) selected')
                    : 'Certificates issued so far.',
                style: const TextStyle(color: Brand.champagne, fontSize: 12.5),
              ),
            ]),
          ),
        ]),
      );

  Widget _searchFields(CertSearch sv) => Column(children: [
        CascadeFilter(api: widget.args.api, onChanged: (c) => sv.cascade = c),
        gap(12),
        Row(children: [
          Expanded(child: TextInput(label: 'Student name', controller: sv.name)),
          const SizedBox(width: 10),
          Expanded(child: TextInput(label: 'GR no.', controller: sv.grNo)),
        ]),
        gap(12),
        Row(children: [
          Expanded(child: TextInput(label: 'Unique ID', controller: sv.uniqueId)),
          const SizedBox(width: 10),
          Expanded(child: TextInput(label: 'Mobile', controller: sv.mobile, keyboard: TextInputType.phone)),
        ]),
      ]);

  // ------------------------------------------------------------------ issue

  Widget _issue() {
    final c = _con;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.searched && !_changing)
        SoftCard(
          radius: 16,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            const IconTile(Icons.groups_outlined, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                [c.issueSearch.cascade.sectionName, c.issueSearch.cascade.standardName, c.issueSearch.cascade.divisionName].where((e) => (e ?? '').isNotEmpty).join(' · ').isEmpty
                    ? '${c.students.length} students found'
                    : '${[c.issueSearch.cascade.sectionName, c.issueSearch.cascade.standardName, c.issueSearch.cascade.divisionName].where((e) => (e ?? '').isNotEmpty).join(' · ')}  (${c.students.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
            TextButton(onPressed: () => setState(() {
              _changing = true;
              c.issueSearch.cascade = CascadeSelection(); // the pickers start blank again
            }), child: const Text('Change')),
          ]),
        )
      else
        Offstage(
          offstage: false,
          child: SoftCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Find students', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Search by class, name, unique ID, mobile or GR no.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              gap(12),
              _searchFields(c.issueSearch),
              gap(14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: c.searching ? null : _search,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(c.searching ? 'Searching…' : 'Search'),
                ),
              ),
            ]),
          ),
        ),
      if (c.issueMessage != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(c.issueMessage!, style: TextStyle(color: Brand.err, fontWeight: FontWeight.w600))),
      if (c.students.isNotEmpty) ...[
        gap(12),
        SoftCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            DropdownField(label: 'Certificate template', options: c.templates, value: c.template, loading: c.loadingTemplates, onChanged: c.setTemplate),
            if (c.templateError != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(c.templateError!, style: TextStyle(color: Brand.err, fontSize: 12.5))),
            gap(12),
            TextInput(label: 'Certificate reason', controller: c.reason, hint: 'Optional'),
          ]),
        ),
        gap(12),
        Row(children: [
          Expanded(child: Text('${c.students.length} students', style: const TextStyle(fontWeight: FontWeight.w800))),
          TextButton.icon(
            onPressed: () => c.toggleAll(!c.allSelected),
            icon: Icon(c.allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 20),
            label: const Text('Select all'),
          ),
        ]),
        for (final st in c.students)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SoftCard(
              radius: 14,
              onTap: () => c.toggle(st.id),
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              borderColor: c.selected.contains(st.id) ? Brand.primary : Brand.line,
              child: Row(children: [
                Checkbox(value: c.selected.contains(st.id), onChanged: (_) => c.toggle(st.id)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.name.isEmpty ? '-' : st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text([if (st.enrollmentNo.isNotEmpty) 'GR ${st.enrollmentNo}', st.classLabel].where((e) => e.isNotEmpty).join('  ·  '),
                        style: TextStyle(color: Brand.muted, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    ]);
  }

  // ---------------------------------------------------------------- history

  void _viewHistory(CertHistoryRow r) {
    push(context, _HtmlPage(title: r.type.isEmpty ? 'Certificate' : r.type, html: r.html));
  }

  Widget _history() {
    final c = _con;
    final list = c.visibleHistory;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SoftCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Find certificates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          gap(12),
          DropdownField(
            label: 'Certificate type',
            options: [const Opt('', 'All types'), ...c.templates],
            value: c.historyType ?? '',
            onChanged: (v) => c.setHistoryType((v ?? '').isEmpty ? null : v),
          ),
          gap(12),
          _searchFields(c.historySearch),
          gap(12),
          Row(children: [
            Expanded(child: DateField(label: 'From date', value: c.fromDate, onChanged: (d) => c.setDates(from: d))),
            const SizedBox(width: 10),
            Expanded(child: DateField(label: 'To date', value: c.toDate, onChanged: (d) => c.setDates(to: d))),
          ]),
          gap(14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: c.loadingHistory ? null : () => c.loadHistory(),
              icon: const Icon(Icons.search_rounded),
              label: Text(c.loadingHistory ? 'Loading…' : 'Search history'),
            ),
          ),
        ]),
      ),
      if (c.historyMessage != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(c.historyMessage!, style: TextStyle(color: Brand.muted, fontWeight: FontWeight.w600))),
      if (c.history.isNotEmpty) ...[
        gap(12),
        TextField(onChanged: c.setHistoryQuery, decoration: const InputDecoration(hintText: 'Filter results', prefixIcon: Icon(Icons.search_rounded))),
        gap(10),
        for (final r in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              radius: 16,
              onTap: r.html.isEmpty ? null : () => _viewHistory(r),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const IconTile(Icons.verified_outlined, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name.isEmpty ? '-' : r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text([if (r.enrollmentNo.isNotEmpty) 'GR ${r.enrollmentNo}', r.classLabel].where((e) => e.isNotEmpty).join('  ·  '),
                        style: TextStyle(color: Brand.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (r.type.isNotEmpty) Tag(r.type),
                      if (r.number.isNotEmpty) Tag.info('No. ${r.number}'),
                      if (r.createdAt.isNotEmpty) Tag.warn(fmtDate(r.createdAt)),
                    ]),
                  ]),
                ),
                if (r.html.isNotEmpty) Icon(Icons.chevron_right_rounded, color: Brand.muted),
              ]),
            ),
          ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final showBar = _tab == 0 && _con.students.isNotEmpty;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Student Certificate' : widget.args.item.label,
      bottom: showBar
          ? formBar(
              label: _con.selected.isEmpty ? 'Select students to preview' : 'Preview certificate (${_con.selected.length})',
              busy: _con.previewing,
              onPressed: _con.selected.isEmpty ? null : _preview,
            )
          : null,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        _hero(),
        gap(12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Issue'), icon: Icon(Icons.workspace_premium_outlined)),
            ButtonSegment(value: 1, label: Text('History'), icon: Icon(Icons.history_rounded)),
          ],
          selected: {_tab},
          onSelectionChanged: (v) => setState(() => _tab = v.first),
        ),
        gap(12),
        _tab == 0 ? _issue() : _history(),
      ]),
    );
  }
}

/// Wide certificate HTML: scrolls sideways and down on a phone.
class _HtmlPage extends StatelessWidget {
  const _HtmlPage({required this.title, required this.html, this.bottom});
  final String title;
  final String html;
  final Widget? bottom;

  /// Opens the system print dialog (print, or Save as PDF / share) with the certificate laid out on A4.
  Future<void> _print(BuildContext context) async {
    final doc = '<html><head><meta charset="utf-8"><style>@page{size:A4;margin:10mm}body{margin:0;font-family:sans-serif}</style></head><body>$html</body></html>';
    try {
      await Printing.layoutPdf(
        name: title,
        format: PdfPageFormat.a4,
        // ignore: deprecated_member_use
        onLayout: (format) => Printing.convertHtml(format: format, html: doc, baseUrl: AppConfig.apiBase),
      );
    } on MissingPluginException {
      if (context.mounted) toast(context, 'Printing needs the app to be rebuilt once (stop it and run again, not hot reload).', error: true);
    } catch (e) {
      if (context.mounted) toast(context, "Couldn't print: $e", error: true);
    }
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: title,
        bottom: bottom,
        actions: [IconButton(tooltip: 'Print / Save as PDF', icon: const Icon(Icons.print_rounded), onPressed: () => _print(context))],
        // The certificate is laid out for an A4 sheet (about 794px). Shrink that sheet to the phone's width so the
        // whole page is visible, and let the user pinch to zoom in and drag around.
        child: LayoutBuilder(builder: (context, box) {
          const sheet = 794.0;
          final w = box.maxWidth;
          return InteractiveViewer(
            constrained: false,
            minScale: 1,
            maxScale: 4,
            boundaryMargin: EdgeInsets.zero,
            child: SizedBox(
              width: w,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  child: ColoredBox(
                    color: Colors.white,
                    child: SizedBox(width: sheet, child: Padding(padding: const EdgeInsets.all(24), child: HtmlWidget(html))),
                  ),
                ),
              ),
            ),
          );
        }),
      );
}

/// Preview of the generated certificates, with the confirm-and-issue action.
class _CertificatePreview extends StatelessWidget {
  const _CertificatePreview({required this.con, required this.preview});
  final StudentCertificateController con;
  final CertPreview preview;

  Future<void> _issue(BuildContext context) async {
    final n = preview.insertIds.split(',').where((e) => e.trim().isNotEmpty).length;
    final ok = await confirm(
      context,
      'Issue certificate?',
      'This will issue "${preview.template}" to $n student(s) and record it in the certificate history. This cannot be undone.',
      yes: 'Issue',
    );
    if (!ok || !context.mounted) return;
    final (done, msg) = await con.issue(preview);
    if (!context.mounted) return;
    toast(context, msg, error: !done);
    if (done) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: con,
        builder: (context, _) => _HtmlPage(
          title: 'Certificate preview',
          html: preview.html,
          bottom: formBar(label: 'Issue certificate', busy: con.issuing, onPressed: con.issuing ? null : () => _issue(context)),
        ),
      );
}
