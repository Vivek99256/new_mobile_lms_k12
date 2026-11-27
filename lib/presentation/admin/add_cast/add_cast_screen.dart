import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_common/student_common.dart';
import '../student_module/student_ui.dart' show ControllerScope;
import 'add_cast_controller.dart';
import '../../../ui/app_loader.dart';

/// Add Cast: the list of castes of the school with add, edit and delete.
class AddCastScreen extends StatefulWidget {
  const AddCastScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AddCastScreen> createState() => _AddCastScreenState();
}

class _AddCastScreenState extends State<AddCastScreen> {
  late final AddCastController _con = AddCastController(args: widget.args)..addListener(_onChange);

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

  Future<void> _form([CastRow? row]) async {
    final title = TextEditingController(text: row?.title ?? '');
    final order = TextEditingController(text: row?.sortOrder ?? _con.nextOrder);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Brand.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => ControllerScope(
        controllers: [title, order],
        child: Theme(
        data: Theme.of(c).copyWith(inputDecorationTheme: studentInputTheme()),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, MediaQuery.viewInsetsOf(c).bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconTile(Icons.groups_2_outlined, size: 34),
              const SizedBox(width: 10),
              Text(row == null ? 'Add cast' : 'Edit cast', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            gap(16),
            TextInput(label: 'Cast name *', controller: title),
            gap(12),
            TextInput(label: 'Sort order', controller: order, keyboard: TextInputType.number),
            gap(16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () {
                  if (title.text.trim().isEmpty) {
                    toast(c, 'Cast name is required.', error: true);
                    return;
                  }
                  if (_con.titleExists(title.text, exceptId: row?.id)) {
                    toast(c, 'This cast already exists.', error: true);
                    return;
                  }
                  Navigator.pop(c, true);
                },
                child: Text(row == null ? 'Add cast' : 'Save changes'),
              ),
            ),
          ]),
        ),
        ),
      ),
    );
    final name = title.text, so = order.text;
    if (ok != true || !mounted) return;
    final (done, message) = await _con.save(id: row?.id, title: name, sortOrder: so);
    if (mounted) toast(context, message, error: !done);
  }

  Future<void> _delete(CastRow row) async {
    final yes = await confirm(context, 'Delete cast?', '"${row.title}" will be removed from the list.', yes: 'Delete');
    if (!yes || !mounted) return;
    final (done, message) = await _con.delete(row);
    if (mounted) toast(context, message, error: !done);
  }

  Widget _tile(CastRow c) => SoftCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Brand.tint, borderRadius: BorderRadius.circular(10)),
            child: Text(c.sortOrder.isEmpty ? '-' : c.sortOrder, style: TextStyle(color: Brand.primaryDark, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
          IconButton(tooltip: 'Edit', onPressed: () => _form(c), icon: Icon(Icons.edit_outlined, color: Brand.primaryDark)),
          IconButton(tooltip: 'Delete', onPressed: () => _delete(c), icon: Icon(Icons.delete_outline_rounded, color: Brand.err)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_con.loading && _con.casts.isEmpty) {
      body = const AppLoader();
    } else if (_con.error != null && _con.casts.isEmpty) {
      body = KitMessage(icon: Icons.cloud_off_outlined, text: _con.error!, action: 'Try again', onAction: _con.load);
    } else {
      body = RefreshIndicator(
        onRefresh: _con.load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          StudentHero(
            title: 'Cast master',
            subtitle: 'Castes offered when admitting students.',
            icon: Icons.groups_2_outlined,
            stats: [('Total casts', '${_con.casts.length}')],
          ),
          if (_con.casts.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: KitMessage(icon: Icons.groups_2_outlined, text: 'No casts added yet.')),
          for (final c in _con.casts) Padding(padding: const EdgeInsets.only(bottom: 10), child: _tile(c)),
        ]),
      );
    }
    return KitPage(
      title: widget.args.item.label.isEmpty ? 'Add Cast' : widget.args.item.label,
      bottom: _con.loading && _con.casts.isEmpty ? null : formBar(label: 'Add cast', busy: _con.saving, onPressed: () => _form()),
      child: body,
    );
  }
}
