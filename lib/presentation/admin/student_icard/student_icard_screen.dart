import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_care/care_common.dart';
import 'icard_html.dart';
import 'student_icard_controller.dart';
import '../../../ui/app_loader.dart';

/// Student I-card: pick a class (and optionally a driver), choose students and a template,
/// then preview the generated cards.
class StudentIcardScreen extends StatefulWidget {
  const StudentIcardScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<StudentIcardScreen> createState() => _StudentIcardScreenState();
}

class _StudentIcardScreenState extends State<StudentIcardScreen> {
  late final StudentIcardController _con = StudentIcardController(args: widget.args)..addListener(_onChange);

  @override
  void initState() {
    super.initState();
    _con.loadMeta();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _con.removeListener(_onChange);
    _con.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_con.cascade.sectionId == null) return toast(context, 'Choose a grade first.', error: true);
    await _con.search();
  }

  Future<void> _preview() async {
    final ok = await _con.preview();
    if (!mounted) return;
    if (!ok) {
      final text = _con.error ?? _con.info;
      if (text != null) toast(context, text, error: _con.error != null);
      return;
    }
    await push<void>(context, _IcardPreviewScreen(html: _con.html!, count: _con.selected.length));
  }

  @override
  Widget build(BuildContext context) {
    final con = _con;
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Student I-card' : widget.args.item.label,
      bottom: con.students.isEmpty
          ? null
          : PrimaryButton(
              label: con.selected.isEmpty ? 'Select students to preview' : 'Preview ${con.selected.length} I-card${con.selected.length == 1 ? '' : 's'}',
              busy: con.previewing,
              onPressed: con.selected.isEmpty || con.previewing ? null : _preview,
            ),
      child: con.metaLoading
          ? const AppLoader()
          : Theme(
              data: Theme.of(context).copyWith(inputDecorationTheme: careInputTheme()),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                SoftCard(
                  radius: 20,
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Find students', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 10),
                    CascadeFilter(api: widget.args.api, onChanged: con.setCascade),
                    gap(),
                    DropdownField(label: 'Driver (optional)', options: con.drivers, value: con.driverId, onChanged: con.setDriver),
                    if (con.driverId != null)
                      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => con.setDriver(null), child: const Text('Clear driver'))),
                    gap(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: con.searching ? null : _search,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(con.searching ? 'Searching…' : 'Search students'),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                if (con.templates.isNotEmpty)
                  SoftCard(
                    radius: 20,
                    padding: const EdgeInsets.all(14),
                    child: DropdownField(
                      label: 'Template',
                      options: [for (final t in con.templates) Opt(t.value, t.label)],
                      value: con.template,
                      onChanged: con.setTemplate,
                    ),
                  ),
                const SizedBox(height: 12),
                if (con.searching) const LinearProgressIndicator(minHeight: 3),
                if (con.error != null) Text(con.error!, style: TextStyle(color: Brand.err, fontWeight: FontWeight.w600)),
                if (con.searched && !con.searching && con.students.isEmpty && con.error == null)
                  Padding(padding: const EdgeInsets.only(top: 30), child: Center(child: Text(con.info ?? 'No students found.', style: TextStyle(color: Brand.muted)))),
                if (con.students.isNotEmpty) ...[
                  CareHero(
                    count: con.students.length,
                    label: 'students',
                    chips: [Tag('${con.selected.length} selected', fg: Colors.white, bg: Colors.white24)],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: con.toggleAll,
                      icon: Icon(con.allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 18),
                      label: Text(con.allSelected ? 'Clear selection' : 'Select all'),
                    ),
                  ),
                  for (final st in con.students) Padding(padding: const EdgeInsets.only(bottom: 8), child: _studentTile(st)),
                ],
              ]),
            ),
    );
  }

  Widget _studentTile(IcardStudent st) {
    final on = _con.selected.contains(st.id);
    final cls = [st.standard, st.division].where((e) => e.isNotEmpty).join(' - ');
    return Container(
      decoration: BoxDecoration(
        color: Brand.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: on ? Brand.primary : Brand.line, width: on ? 1.5 : 1),
        boxShadow: Brand.softShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _con.toggle(st.id),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            PersonAvatar(url: '', name: st.name, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Brand.ink)),
                const SizedBox(height: 3),
                Text('GR ${st.enrollmentNo}${cls.isEmpty ? '' : '  ·  $cls'}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
              ]),
            ),
            Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: on ? Brand.primary : Brand.border),
          ]),
        ),
      ),
    );
  }
}

/// The generated I-cards, one per selected student.
class _IcardPreviewScreen extends StatelessWidget {
  const _IcardPreviewScreen({required this.html, required this.count});
  final String html;
  final int count;

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'I-card preview',
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              const IconTile(Icons.badge_outlined, size: 30),
              const SizedBox(width: 10),
              Text('$count card${count == 1 ? '' : 's'} generated', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
          ),
          IcardCards(html: html),
          Text('Printing is done from the web app; this is a preview.', textAlign: TextAlign.center, style: TextStyle(color: Brand.muted, fontSize: 12)),
        ]),
      );
}
