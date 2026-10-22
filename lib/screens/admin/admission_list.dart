import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import '../teacher/api_migration.dart';
import 'admin_common.dart';
import 'admission_form.dart';

enum AdmissionStage { enquiry, registration, confirmation }

extension AdmissionStageInfo on AdmissionStage {
  String get path => switch (this) {
        AdmissionStage.enquiry => '/admission/admission_enquiry',
        AdmissionStage.registration => '/admission/admission_registration',
        AdmissionStage.confirmation => '/admission/admission_confirmation',
      };
  /// Newer endpoint (rows 76-78). Confirmations use the registration list query.
  String get apiPath => switch (this) {
        AdmissionStage.enquiry => '/api/admission_enquiry',
        AdmissionStage.registration || AdmissionStage.confirmation => '/api/admission_registration',
      };
  String get title => switch (this) {
        AdmissionStage.enquiry => 'Admission enquiry',
        AdmissionStage.registration => 'Admission registration',
        AdmissionStage.confirmation => 'Admission confirmation',
      };
  String get emptyText => switch (this) {
        AdmissionStage.enquiry => 'No admission enquiries yet.',
        AdmissionStage.registration => 'No admission registrations yet.',
        AdmissionStage.confirmation => 'No confirmed admissions yet.',
      };
}

/// t_enquiry / t_registration / t_confirmation: the admission pipeline lists.
/// Enquiries can be added and edited, registrations edited; confirmations are read-only
/// because the old create/edit screen for them was broken.
class AdmissionListScreen extends StatefulWidget {
  const AdmissionListScreen({super.key, required this.args, required this.stage});
  final ScreenArgs args;
  final AdmissionStage stage;

  @override
  State<AdmissionListScreen> createState() => _AdmissionListScreenState();
}

class _AdmissionListScreenState extends State<AdmissionListScreen> {
  final ctl = AsyncListController();

  Future<List<Map<String, dynamic>>> _load() => readNewThenLegacy(
        'admission ${widget.stage.name} list',
        () async => adaptAdmissionRows(rows((await getNew(widget.args.api, widget.stage.apiPath))['data'])),
        () async {
          final res = await widget.args.api.get(widget.stage.path);
          if (statusOf(res) == '0') throw ApiException(LegacyApi.messageOf(res));
          return rows(res['data']);
        },
      );

  Future<void> _open(Map<String, dynamic>? row) async {
    final saved = await push<bool>(
      context,
      AdmissionFormScreen(args: widget.args, stage: widget.stage, row: row),
    );
    if (saved == true) await ctl.reload();
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    return KitPage(
      title: widget.args.item.label.isEmpty ? stage.title : widget.args.item.label,
      actions: [
        if (stage == AdmissionStage.enquiry)
          TextButton.icon(
            onPressed: () => _open(null),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
      ],
      child: AsyncList(
        controller: ctl,
        load: _load,
        emptyText: stage.emptyText,
        emptyIcon: Icons.how_to_reg_outlined,
        itemBuilder: (c, r, i) => AdmissionCard(
          index: i + 1,
          row: r,
          onEdit: stage == AdmissionStage.confirmation ? null : () => _open(r),
        ),
      ),
    );
  }
}

class AdmissionCard extends StatelessWidget {
  const AdmissionCard({super.key, required this.index, required this.row, this.onEdit});
  final int index;
  final Map<String, dynamic> row;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final name = [r['first_name'], r['middle_name'], r['last_name']].map(s).where((e) => e.isNotEmpty).join(' ');
    return KitCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('$index. $name', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, color: Brand.primary),
            ),
        ]),
        if (s(r['enquiry_no']).isNotEmpty) Text('#${s(r['enquiry_no'])}', style: const TextStyle(color: Brand.muted)),
        if (s(r['mobile']).isNotEmpty)
          InkWell(
            onTap: () => openUrl(context, 'tel:${s(r['mobile'])}'),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(s(r['mobile']), style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w600))),
          ),
        if (s(r['email']).isNotEmpty) Text(s(r['email']), style: const TextStyle(color: Brand.primary, decoration: TextDecoration.underline)),
        gap(6),
        KV('Enquiry', fmtDate(r['created_on'], out: 'dd-MM-yyyy')),
        KV('Follow-up', fmtDate(r['followup_date'], out: 'dd-MM-yyyy')),
        KV('Birthdate', fmtDate(r['date_of_birth'], out: 'dd-MM-yyyy')),
        KV('Age', s(r['age']).isEmpty ? '' : '${s(r['age'])} years'),
        KV('Previous school', s(r['previous_school_name'])),
        KV('Previous std', s(r['previous_standard'])),
        KV('Admission std', s(r['std_name']).isNotEmpty ? s(r['std_name']) : s(r['admission_standard'])),
        KV('Status', s(r['enquiry_status'])),
        KV('Remarks', s(r['remarks'])),
      ]),
    );
  }
}

/// The new `api/admission_enquiry` list returns raw table rows (no standard join): fill in
/// `std_name` from the standard id so the card reads the same as before. Rows keep their numeric
/// `id`, which the new PUT routes use instead of the enquiry number.
List<Map<String, dynamic>> adaptAdmissionRows(List<Map<String, dynamic>> list) => [
      for (final r in list)
        {
          ...r,
          if (s(r['std_name']).isEmpty)
            'std_name': admissionStandards.where((o) => o.id == s(r['admission_standard'])).firstOrNull?.label ?? s(r['admission_standard']),
        }
    ];
