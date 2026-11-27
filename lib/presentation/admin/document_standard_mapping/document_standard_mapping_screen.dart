import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import 'document_standard_mapping_controller.dart';
import '../../../ui/app_loader.dart';

/// Standardized Document Type: which student document types are required for which standards.
class DocumentStandardMappingScreen extends StatefulWidget {
  const DocumentStandardMappingScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<DocumentStandardMappingScreen> createState() => _DocumentStandardMappingScreenState();
}

class _DocumentStandardMappingScreenState extends State<DocumentStandardMappingScreen> {
  late final DocumentStandardMappingController _con = DocumentStandardMappingController(args: widget.args)..addListener(_onChange);

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

  Future<void> _open([DocMapping? m]) async {
    final saved = await push<bool>(context, _MappingForm(con: _con, existing: m));
    if (saved == true) _con.load();
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Required documents', style: TextStyle(color: Brand.champagne, fontSize: 12.5)),
              CountUp(value: _con.items.length, builder: (v) => Text('$v mapped', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
              const Text('Document types and the standards that must submit them', style: TextStyle(color: Brand.champagne, fontSize: 12)),
            ]),
          ),
          const IconTile(Icons.rule_folder_outlined, size: 46, fg: Colors.white, bg: Color(0x22FFFFFF)),
        ]),
      );

  Widget _card(DocMapping m) {
    final stds = m.standardList;
    return SoftCard(
      radius: 16,
      onTap: () => _open(m),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconTile(Icons.description_outlined, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text(m.documentType, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
          Tag.info('${stds.length} std'),
          Icon(Icons.chevron_right_rounded, color: Brand.muted),
        ]),
        if (m.grades.isNotEmpty) ...[
          gap(8),
          Text(m.grades, style: TextStyle(color: Brand.muted, fontSize: 12)),
        ],
        gap(8),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final n in stds.take(12)) Tag(n), if (stds.length > 12) Tag.info('+${stds.length - 12}')]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _con.visible;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Standardized Document Type' : widget.args.item.label,
      bottom: formBar(label: 'Add mapping', busy: false, onPressed: () => _open()),
      child: RefreshIndicator(
        onRefresh: _con.load,
        child: _con.loading && _con.items.isEmpty
            ? ListView(children: const [SizedBox(height: 200), const AppLoader()])
            : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                if (_con.error != null)
                  KitMessage(icon: Icons.error_outline, text: _con.error!, action: 'Try again', onAction: _con.load)
                else ...[
                  _hero(),
                  gap(12),
                  TextField(onChanged: _con.setQuery, decoration: const InputDecoration(hintText: 'Search document or standard', prefixIcon: Icon(Icons.search_rounded))),
                  gap(10),
                  if (list.isEmpty)
                    const KitMessage(icon: Icons.folder_off_outlined, text: 'No document mappings yet. Tap "Add mapping" to create one.')
                  else
                    for (final m in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: _card(m)),
                ],
              ]),
      ),
    );
  }
}

/// Add / edit form: choose a document type and tick the standards (grouped by grade).
class _MappingForm extends StatefulWidget {
  const _MappingForm({required this.con, this.existing});
  final DocumentStandardMappingController con;
  final DocMapping? existing;

  @override
  State<_MappingForm> createState() => _MappingFormState();
}

class _MappingFormState extends State<_MappingForm> {
  bool _loading = true;
  String? _error;
  List<Opt> _types = [];
  List<GradeStandards> _grades = [];
  String? _type;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.documentTypeId;
    _selected.addAll(widget.existing?.standardIds ?? const {});
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([widget.con.documentTypes(), widget.con.gradesWithStandards()]);
      if (!mounted) return;
      setState(() {
        _types = r[0] as List<Opt>;
        _grades = r[1] as List<GradeStandards>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load document types and standards. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final editing = widget.existing != null;
    final ok = await confirm(
      context,
      editing ? 'Save changes?' : 'Add mapping?',
      editing
          ? 'The ticked standards will be added to this document type. Standards already mapped stay mapped.'
          : 'This document type will be required for the ${_selected.length} selected standard(s).',
      yes: 'Save',
    );
    if (!ok || !mounted) return;
    final (done, msg) = await widget.con.save(documentTypeId: _type ?? '', standardIds: _selected, editingId: widget.existing?.documentTypeId);
    if (!mounted) return;
    toast(context, msg, error: !done);
    if (done) Navigator.pop(context, true);
  }

  Widget _gradeBlock(GradeStandards g) {
    final ids = g.standards.map((e) => e.id).toSet();
    final all = ids.every(_selected.contains);
    final count = ids.where(_selected.contains).length;
    return SoftCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
          if (count > 0) Tag.info('$count/${ids.length}'),
          TextButton(
            onPressed: () => setState(() => all ? _selected.removeAll(ids) : _selected.addAll(ids)),
            child: Text(all ? 'Clear' : 'Select all'),
          ),
        ]),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final o in g.standards)
            FilterChip(
              label: Text(o.label),
              selected: _selected.contains(o.id),
              onSelected: (v) => setState(() => v ? _selected.add(o.id) : _selected.remove(o.id)),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return KitPage(
      title: editing ? 'Edit mapping' : 'Add mapping',
      bottom: _loading || _error != null ? null : formBar(label: 'Save', busy: widget.con.busy, onPressed: _save),
      child: _loading
          ? const AppLoader()
          : _error != null
              ? KitMessage(icon: Icons.error_outline, text: _error!, action: 'Try again', onAction: _init)
              : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                  SoftCard(
                    radius: 16,
                    padding: const EdgeInsets.all(14),
                    child: DropdownField(
                      label: 'Document type',
                      options: _types,
                      value: _type,
                      enabled: !editing,
                      onChanged: (v) => setState(() => _type = v),
                    ),
                  ),
                  gap(14),
                  Row(children: [
                    const Expanded(child: SectionLabel('Standards')),
                    Tag.info('${_selected.length} selected'),
                  ]),
                  if (editing)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Ticking more standards adds them. Saving cannot un-map a standard that is already mapped.', style: TextStyle(color: Brand.muted, fontSize: 12)),
                    ),
                  for (final g in _grades) Padding(padding: const EdgeInsets.only(bottom: 8), child: _gradeBlock(g)),
                ]),
    );
  }
}
