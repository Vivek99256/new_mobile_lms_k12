import 'package:flutter/material.dart' show Icons;

import '../../../screens/kit/kit.dart';
import 'fees_master_spec.dart';

List<Opt> _fromMap(dynamic v) {
  if (v is Map) return [for (final e in v.entries) Opt('${e.key}', s(e.value).isEmpty ? '${e.key}' : s(e.value))];
  if (v is List) {
    return [
      for (final x in v)
        if (x is Map && s(x['id']).isNotEmpty) Opt(s(x['id']), s(x['name']).isEmpty ? s(x['id']) : s(x['name']))
        else if (x is! Map && s(x).isNotEmpty) Opt(s(x), s(x)),
    ];
  }
  return [];
}

/// Fees Late Master: the date from which a late fine applies. Add can cover several standards at once.
final feesLateMasterSpec = FeesMasterSpec(
  title: 'Late fee rule',
  icon: Icons.timer_outlined,
  subtitle: 'From when a late fine is charged.',
  resource: 'fees_late_master',
  rowTitle: (r) => 'Std ${s(r['standard'])} · ${s(r['late_date'])}',
  loadOptions: (api) async {
    final res = await api.get('/fees/fees_late_master/create');
    return {
      'standards': _fromMap(res['standard_list']),
      'fine_types': _fromMap(res['fine_types']),
      'months': _fromMap(res['fees_month']),
    };
  },
  fields: const [
    MField('standard_id', 'Standards', kind: MKind.multi, options: 'standards', required: true, addOnly: true, section: 'Applies to'),
    MField('fees_month', 'Fees month', kind: MKind.dropdown, options: 'months', required: true, addOnly: true, section: 'Applies to'),
    MField('late_date', 'Late fee start date', kind: MKind.date, required: true, section: 'Late fee rule'),
    MField('fine_type', 'Fine type', kind: MKind.dropdown, options: 'fine_types', required: true, section: 'Late fee rule'),
    MField('status', 'Active', kind: MKind.toggle, initial: '1', section: 'Late fee rule'),
  ],
);

/// Other Fees Title: extra fee heads (transport, books…).
final otherFeesTitleSpec = FeesMasterSpec(
  title: 'Other fees title',
  icon: Icons.label_important_outline,
  subtitle: 'Extra fee heads such as transport or books.',
  resource: 'other_fees_title',
  rowTitle: (r) => s(r['display_name']),
  fields: const [
    MField('display_name', 'Display name', required: true),
    MField('amount', 'Amount', kind: MKind.number, required: true),
    MField('sort_order', 'Sort order', kind: MKind.number),
    MField('include_imprest', 'Include imprest', kind: MKind.dropdown, options: 'yesno', initial: 'N'),
    MField('status', 'Active', kind: MKind.toggle, initial: '1'),
  ],
  loadOptions: (api) async => {
        'yesno': [const Opt('Y', 'Yes'), const Opt('N', 'No')],
      },
);

/// New Fees Title: like the web, a title can be added or deleted but not edited.
final feesTitleSpec = FeesMasterSpec(
  title: 'Fees title',
  icon: Icons.label_outline,
  subtitle: 'A fee head shown on receipts.',
  resource: 'fees_title',
  canEdit: false,
  rowTitle: (r) => s(r['display_name']).isNotEmpty ? s(r['display_name']) : s(r['fees_title']),
  loadOptions: (api) async {
    final res = await api.get('/fees/fees_title/create');
    final d = res['data'];
    final dd = d is Map && d['data'] is Map ? (d['data'] as Map)['ddTtitle'] : (d is Map ? d['ddTtitle'] : null);
    return {'titles': _fromMap(dd)};
  },
  fields: const [
    MField('fees_title_id', 'Fees title', kind: MKind.dropdown, options: 'titles', required: true),
    MField('display_name', 'Display name', required: true),
    MField('cumulative_name', 'Cumulative name'),
    MField('append_name', 'Append name'),
    MField('sort_order', 'Sort order', kind: MKind.number),
    MField('mandatory', 'Mandatory', kind: MKind.toggle),
  ],
);

/// Fees Circular Master: the bank details printed on a fee circular, per class.
const feesCircularMasterSpec = FeesMasterSpec(
  title: 'Circular master',
  icon: Icons.account_balance_outlined,
  subtitle: 'Bank details printed on the fee circular.',
  resource: 'fees_circular_master',
  needsClass: true,
  fields: [
    MField('bank_name', 'Bank name', required: true, section: 'Bank'),
    MField('address_line1', 'Address line 1', required: true, section: 'Address'),
    MField('address_line2', 'Address line 2', required: true, section: 'Address'),
    MField('account_no', 'Account no', required: true, section: 'Bank'),
    MField('paid_collection', 'Paid collection', required: true, section: 'Bank'),
    MField('shift', 'Shift', required: true, section: 'Form'),
    MField('form_no', 'Form no', required: true, section: 'Form'),
    MField('branch', 'Branch', required: true, section: 'Bank'),
  ],
);

/// Fees Config Master: the school's fee receipt / NACH settings. (The bank logo image is still uploaded on the web.)
final feesConfigMasterSpec = FeesMasterSpec(
  title: 'Fees config',
  icon: Icons.settings_suggest_outlined,
  subtitle: 'Receipt, challan and NACH settings.',
  resource: 'fees_config_master',
  bare: true,
  rowTitle: (r) => s(r['institute_name']),
  loadOptions: (api) async => {
        'yesno': [const Opt('1', 'Yes'), const Opt('0', 'No')],
        'receipt': [const Opt('A5', 'A5'), const Opt('A5DB', 'A5 Double'), const Opt('A4', 'A4'), const Opt('A4DB', 'A4 Double')],
        'challan': [const Opt('template_1', 'Template 1'), const Opt('template_2', 'Template 2'), const Opt('template_3', 'Template 3'), const Opt('template_4', 'Template 4')],
        'nach': [const Opt('saving', 'Saving account'), const Opt('current', 'Current account'), const Opt('cash', 'Cash / Credit')],
      },
  fields: const [
    MField('institute_name', 'Institute name', required: true, section: 'Institute'),
    MField('pan_no', 'PAN number', required: true, section: 'Institute'),
    MField('account_to_be_credited', 'Account to be credited', required: true, section: 'Institute'),
    MField('cms_client_code', 'CMS client code', required: true, section: 'Institute'),
    MField('late_fees_amount', 'Late fees amount', kind: MKind.number, required: true, section: 'Fees & notifications'),
    MField('send_sms', 'Send SMS when fees are paid', kind: MKind.dropdown, options: 'yesno', section: 'Fees & notifications'),
    MField('send_email', 'Send email when fees are paid', kind: MKind.dropdown, options: 'yesno', required: true, section: 'Fees & notifications'),
    MField('auto_head_counting', 'Auto head counting', kind: MKind.dropdown, options: 'yesno', section: 'Fees & notifications'),
    MField('show_month', 'Show month on receipt', kind: MKind.toggle, section: 'Fees & notifications'),
    MField('fees_receipt_template', 'Fees receipt template', kind: MKind.dropdown, options: 'receipt', required: true, section: 'Receipt templates'),
    MField('fees_bank_challan_template', 'Bank challan template', kind: MKind.dropdown, options: 'challan', required: true, section: 'Receipt templates'),
    MField('fees_receipt_note', 'Fees receipt note', lines: 3, section: 'Receipt templates'),
    MField('nach_account_type', 'NACH account type', kind: MKind.dropdown, options: 'nach', required: true, section: 'NACH'),
    MField('nach_registration_charge', 'NACH registration charge', kind: MKind.number, required: true, section: 'NACH'),
    MField('nach_transaction_charge', 'NACH transaction charge', kind: MKind.number, required: true, section: 'NACH'),
    MField('nach_failed_charge', 'NACH failed charge', kind: MKind.number, required: true, section: 'NACH'),
  ],
);

/// Fees Receipt Book Master: a receipt book's numbering and bank lines, and which classes and fee heads it covers.
/// The server stores one row per standard x fee head, so the list shows one card per receipt book. Edit replaces the
/// book's rows (like the web). The two logo images are still uploaded on the web.
final feesReceiptBookMasterSpec = FeesMasterSpec(
  title: 'Receipt book',
  icon: Icons.menu_book_outlined,
  subtitle: 'Numbering, bank lines and the classes it covers.',
  resource: 'fees_receipt_book_master',
  bare: true,
  idKey: 'receipt_id',
  updateViaStore: true,
  rowTitle: (r) => s(r['receipt_line_1']),
  extraBody: (editing) => {'submit': editing ? 'Update' : 'Save'},
  loadOptions: (api) async {
    final create = await api.get('/fees/fees_receipt_book_master/create');
    final sections = await api.post('/get_adminAcademicSection');
    return {
      'heads': [
        for (final r in rows(create['feeHeadList']))
          if (s(r['id']).isNotEmpty) Opt(s(r['id']), s(r['display_name']).isNotEmpty ? s(r['display_name']) : s(r['fees_title'])),
      ],
      'grades': [
        for (final r in rows(sections['data']))
          if (s(r['id']).isNotEmpty) Opt(s(r['id']), s(r['title']).isNotEmpty ? s(r['title']) : s(r['short_name'])),
      ],
      'standards': const [],
      '_defaults': [Opt('receipt_id', s(create['receipt_id']))],
    };
  },
  loadDependent: (api, name, parents) async {
    final seen = <String, Opt>{};
    for (final g in parents) {
      final res = await api.post('/get_adminStandard', body: {'grade_id': g});
      for (final r in rows(res['data'])) {
        final id = s(r['id']);
        if (id.isEmpty || seen.containsKey(id)) continue;
        seen[id] = Opt(id, s(r['name']).isNotEmpty ? s(r['name']) : s(r['short_name']));
      }
    }
    return seen.values.toList();
  },
  loadRecord: (api, row) async {
    final res = await api.get('/fees/fees_receipt_book_master/${s(row['receipt_id'])}/edit');
    return m(m(res['data'])['record']);
  },
  fields: const [
    MField('receipt_id', 'Receipt book no', required: true, readOnly: true, section: 'Receipt lines'),
    MField('receipt_line_1', 'Receipt line 1 (institute name)', required: true, section: 'Receipt lines'),
    MField('receipt_line_2', 'Receipt line 2 (address)', section: 'Receipt lines'),
    MField('receipt_line_3', 'Receipt line 3', section: 'Receipt lines'),
    MField('receipt_line_4', 'Receipt line 4', section: 'Receipt lines'),
    MField('receipt_prefix', 'Receipt prefix', section: 'Numbering'),
    MField('receipt_postfix', 'Receipt postfix', section: 'Numbering'),
    MField('account_number', 'Account number', section: 'Bank details'),
    MField('pan', 'PAN', section: 'Bank details'),
    MField('branch', 'Branch', section: 'Bank'),
    MField('sort_order', 'Sort order', kind: MKind.number, section: 'Numbering'),
    MField('last_receipt_number', 'Last receipt number', kind: MKind.number, section: 'Numbering'),
    MField('grade', 'Grades', kind: MKind.multi, options: 'grades', required: true, recordKey: 'grade_id', section: 'Coverage'),
    MField('standard', 'Standards', kind: MKind.multi, options: 'standards', required: true, recordKey: 'standard_id', dependsOn: 'grade', section: 'Coverage'),
    MField('fees_head_id', 'Fee heads', kind: MKind.multi, options: 'heads', required: true, section: 'Coverage'),
  ],
);
