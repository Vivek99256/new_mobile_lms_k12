import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';
import 'inward_outward_form.dart';

/// Inward and outward registers share one implementation.
enum RegisterKind { inward, outward }

extension RegisterKindInfo on RegisterKind {
  bool get isInward => this == RegisterKind.inward;
  String get word => isInward ? 'Inward' : 'Outward';
  String get path => isInward ? '/inward_outward/add_inward' : '/inward_outward/add_outward';
  String get numberKey => isInward ? 'inward_number' : 'outward_number';
  String get dateKey => isInward ? 'inward_date' : 'outward_date';
}

/// t_inward / t_outward: list with add, edit and delete (with confirmation).
class RegisterListScreen extends StatefulWidget {
  const RegisterListScreen({super.key, required this.args, required this.kind});
  final ScreenArgs args;
  final RegisterKind kind;

  @override
  State<RegisterListScreen> createState() => _RegisterListScreenState();
}

class _RegisterListScreenState extends State<RegisterListScreen> {
  final ctl = AsyncListController();
  RegisterKind get kind => widget.kind;

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await widget.args.api.get(kind.path);
    if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
    return rows(res['data']);
  }

  Future<void> _open(Map<String, dynamic>? row) async {
    final saved = await push<bool>(context, RegisterFormScreen(args: widget.args, kind: kind, row: row));
    if (saved == true) await ctl.reload();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await confirm(context, 'Delete ${kind.word.toLowerCase()} entry?', 'This removes entry #${s(row[kind.numberKey])}. This cannot be undone.', yes: 'Delete');
    if (!ok || !mounted) return;
    try {
      final res = await AdminHttp.delete(widget.args.session, '${kind.path}/${s(row['id'])}');
      if (!mounted) return;
      final good = statusOf(res) != '0';
      toast(context, LegacyApi.messageOf(res, good ? 'Deleted.' : 'Could not delete.'), error: !good);
      if (good) await ctl.reload();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: widget.args.item.label.isEmpty ? kind.word : widget.args.item.label,
        actions: [
          TextButton.icon(
            onPressed: () => _open(null),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
        child: AsyncList(
          controller: ctl,
          load: _load,
          emptyText: 'No ${kind.word.toLowerCase()} entries yet.',
          emptyIcon: kind.isInward ? Icons.move_to_inbox_outlined : Icons.outbox_outlined,
          itemBuilder: (c, r, i) => KitCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${i + 1}. ${s(r['place_id'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                IconButton(
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => _open(r),
                  icon: const Icon(Icons.edit_outlined, color: Brand.primary),
                ),
                IconButton(
                  tooltip: 'Delete',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => _delete(r),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                ),
              ]),
              Text('#${s(r[kind.numberKey])}', style: const TextStyle(color: Brand.muted)),
              if (s(r['attachment']).isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: EdgeInsets.zero),
                  onPressed: () => openUrl(context, s(r['attachment'])),
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: Text(s(r['attachment']).split('/').last, overflow: TextOverflow.ellipsis),
                ),
              KV('Subject', s(r['title'])),
              KV('Description', s(r['description'])),
              KV('File', s(r['file_name'])),
              KV('File location', s(r['file_location_id'])),
              KV('${kind.word} date', fmtDate(s(r[kind.dateKey]).isEmpty ? r['outward_date'] : r[kind.dateKey], out: 'dd-MM-yyyy')),
              if (kind.isInward) KV('Academic year', s(r['acedemic_year'])),
            ]),
          ),
        ),
      );
}
