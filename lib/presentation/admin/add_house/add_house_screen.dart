import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, TextInputType;

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import '../../../ui/design.dart';
import '../../../ui/theme.dart';
import '../student_module/student_ui.dart';
import 'add_house_controller.dart';
import '../../../ui/app_loader.dart';

/// Add House: the list of houses with add, edit and delete.
class AddHouseScreen extends StatefulWidget {
  const AddHouseScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AddHouseScreen> createState() => _AddHouseScreenState();
}

class _AddHouseScreenState extends State<AddHouseScreen> {
  late final AddHouseController _con = AddHouseController(args: widget.args)..addListener(_onChange);

  @override
  void initState() {
    super.initState();
    _con.load();
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

  Future<void> _edit([HouseRow? row]) async {
    final name = TextEditingController(text: row?.name ?? '');
    final sort = TextEditingController(text: row?.sortOrder ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Brand.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ControllerScope(
        controllers: [name, sort],
        child: withStudentInputs(
        ctx,
        Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconTile(Icons.flag_rounded, size: 34),
              const SizedBox(width: 10),
              Text(row == null ? 'Add house' : 'Edit house', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ]),
            gap(16),
            TextInput(label: 'House name *', controller: name),
            gap(12),
            TextField(
              controller: sort,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Sort order'),
            ),
            gap(18),
            ListenableBuilder(
              listenable: _con,
              builder: (ctx, _) => PrimaryButton(
                label: row == null ? 'Add house' : 'Update house',
                busy: _con.busy,
                onPressed: () async {
                  final problem = AddHouseController.validate(name.text, sort.text);
                  if (problem != null) {
                    toast(ctx, problem, error: true);
                    return;
                  }
                  final (ok, message) = await _con.save(id: row?.id, name: name.text, sort: sort.text);
                  if (!ctx.mounted) return;
                  toast(ctx, message, error: !ok);
                  if (ok) Navigator.pop(ctx, true);
                },
              ),
            ),
          ]),
        ),
        ),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _delete(HouseRow row) async {
    final go = await confirm(context, 'Delete house?', 'Delete "${row.name}"? Students already placed in this house lose the link to it.', yes: 'Delete');
    if (!go || !mounted) return;
    final (ok, message) = await _con.delete(row.id);
    if (mounted) toast(context, message, error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final c = _con;
    final title = widget.args.item.label.isEmpty ? 'Add House' : widget.args.item.label;
    return KitPage(
      title: title,
      bottom: c.loading || c.error != null ? null : formBar(label: 'Add house', busy: false, onPressed: () => _edit()),
      child: c.loading
          ? const AppLoader()
          : c.error != null
              ? KitMessage(icon: Icons.cloud_off_outlined, text: c.error!, action: 'Try again', onAction: c.load)
              : RefreshIndicator(
                  onRefresh: c.load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                    NavyStats(stats: [('houses', '${c.houses.length}')], caption: 'Houses are used when you add students, bulk update them or shuffle them across divisions.'),
                    gap(14),
                    if (c.houses.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: KitMessage(icon: Icons.flag_outlined, text: 'No houses yet. Add the first one.')),
                    for (final h in c.houses) Padding(padding: const EdgeInsets.only(bottom: 10), child: _tile(h)),
                  ]),
                ),
    );
  }

  Widget _tile(HouseRow h) => SoftCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          const IconTile(Icons.flag_rounded, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Tag.neutral(h.sortOrder.isEmpty ? 'No sort order' : 'Order ${h.sortOrder}'),
            ]),
          ),
          IconButton(tooltip: 'Edit', onPressed: () => _edit(h), icon: const Icon(Icons.edit_outlined, color: Brand.primary)),
          IconButton(tooltip: 'Delete', onPressed: () => _delete(h), icon: Icon(Icons.delete_outline_rounded, color: Brand.err)),
        ]),
      );
}
