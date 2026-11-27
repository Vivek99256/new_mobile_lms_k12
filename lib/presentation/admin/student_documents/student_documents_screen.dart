import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'student_documents_controller.dart';
import '../../../ui/app_loader.dart';

/// Student Documents: how complete each student's document set is, with class filters,
/// status tabs, search, and a per-student list of what is on file and what is missing.
class StudentDocumentsScreen extends StatefulWidget {
  const StudentDocumentsScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentDocumentsScreen> createState() => _StudentDocumentsScreenState();
}

class _StudentDocumentsScreenState extends State<StudentDocumentsScreen> {
  late final StudentDocumentsController _con = StudentDocumentsController(args: widget.args)..addListener(_onChange);
  bool _filters = false;
  int _limit = 60;

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _con.load();
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Color _color(DocStatus st) => switch (st) { DocStatus.complete => Brand.ok, DocStatus.partial => Brand.warn, DocStatus.missing => Brand.err };
  String _label(DocStatus st) => switch (st) { DocStatus.complete => 'Complete', DocStatus.partial => 'Pending', DocStatus.missing => 'Missing' };

  void _detail(StudentDocRow r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.card,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .65,
        maxChildSize: .92,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Row(children: [
            PersonAvatar(url: '', name: r.name, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text([if (r.enrollmentNo.isNotEmpty) 'GR ${r.enrollmentNo}', r.classLabel].where((e) => e.isNotEmpty).join('  ·  '),
                    style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
          gap(14),
          if (r.missingNames.isNotEmpty) ...[
            Text('Missing (${r.missingNames.length})', style: TextStyle(fontWeight: FontWeight.w800, color: Brand.err)),
            gap(8),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final n in r.missingNames) Tag.err(n)]),
            gap(16),
          ],
          Text('On file (${r.haveNames.length})', style: TextStyle(fontWeight: FontWeight.w800, color: Brand.ok)),
          gap(8),
          if (r.haveNames.isEmpty)
            Text('No documents submitted yet.', style: TextStyle(color: Brand.muted))
          else
            Wrap(spacing: 6, runSpacing: 6, children: [for (final n in r.haveNames) Tag.ok(n)]),
        ]),
      ),
    );
  }

  Widget _stat(String label, DocStatus st) {
    final on = _con.statusFilter == st;
    final c = _color(st);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _con.setStatus(st),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text('${_con.count(st)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: on ? c : Colors.white)),
            Text(label, style: TextStyle(fontSize: 11.5, color: on ? Brand.ink2 : Brand.champagne)),
          ]),
        ),
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Document compliance', style: TextStyle(color: Brand.champagne, fontSize: 12.5)),
                CountUp(value: _con.complianceRate, builder: (v) => Text('$v%', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800))),
                Text('${_con.all.length} students  ·  ${_con.docTypeCount} document types', style: const TextStyle(color: Brand.champagne, fontSize: 12)),
              ]),
            ),
            const IconTile(Icons.folder_copy_outlined, size: 46, fg: Colors.white, bg: Color(0x22FFFFFF)),
          ]),
          gap(12),
          Row(children: [_stat('Complete', DocStatus.complete), const SizedBox(width: 8), _stat('Pending', DocStatus.partial), const SizedBox(width: 8), _stat('Missing', DocStatus.missing)]),
        ]),
      );

  Widget _filterCard() => SoftCard(
        radius: 16,
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          CascadeFilter(api: widget.args.api, onChanged: _con.setCascade),
          gap(12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _con.loading
                  ? null
                  : () async {
                      await _con.load();
                      if (mounted) setState(() => _filters = false);
                    },
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Apply filter'),
            ),
          ),
        ]),
      );

  Widget _row(StudentDocRow r) {
    final c = _color(r.status);
    final pct = r.total == 0 ? 0.0 : r.have / r.total;
    return SoftCard(
      radius: 16,
      onTap: () => _detail(r),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        PersonAvatar(url: '', name: r.name, radius: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name.isEmpty ? '-' : r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text([if (r.enrollmentNo.isNotEmpty) 'GR ${r.enrollmentNo}', r.classLabel].where((e) => e.isNotEmpty).join('  ·  '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted, fontSize: 12)),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: Brand.field, color: c),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${r.have}/${r.total}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          switch (r.status) {
            DocStatus.complete => Tag.ok('Complete'),
            DocStatus.partial => Tag.warn('Pending'),
            DocStatus.missing => Tag.err('Missing'),
          },
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _con.visible;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Student Documents' : widget.args.item.label,
      actions: [
        IconButton(
          tooltip: 'Filter by class',
          icon: Icon(_filters ? Icons.filter_alt_off_outlined : Icons.filter_alt_outlined),
          onPressed: () => setState(() => _filters = !_filters),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _con.load,
        child: _con.loading && _con.all.isEmpty
            ? ListView(children: const [SizedBox(height: 200), const AppLoader()])
            : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                if (_con.error != null)
                  KitMessage(icon: Icons.error_outline, text: _con.error!, action: 'Try again', onAction: _con.load)
                else ...[
                  _hero(),
                  if (_filters) ...[gap(12), _filterCard()],
                  gap(12),
                  TextField(
                    onChanged: _con.setQuery,
                    decoration: const InputDecoration(hintText: 'Search name or GR no.', prefixIcon: Icon(Icons.search_rounded)),
                  ),
                  gap(10),
                  if (_con.statusFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        PillChip(label: 'Showing ${_label(_con.statusFilter!)}', selected: true, onTap: () => _con.setStatus(_con.statusFilter), leading: Icons.close_rounded),
                        const SizedBox(width: 8),
                        Text('${list.length} students', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                      ]),
                    ),
                  if (list.isEmpty)
                    const KitMessage(icon: Icons.folder_off_outlined, text: 'No students match these filters.')
                  else
                    ...[
                      for (final r in list.take(_limit)) Padding(padding: const EdgeInsets.only(bottom: 8), child: _row(r)),
                      if (list.length > _limit)
                        TextButton(onPressed: () => setState(() => _limit += 60), child: Text('Show more (${list.length - _limit} left)')),
                    ],
                ],
              ]),
      ),
    );
  }
}
