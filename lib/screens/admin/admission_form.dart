import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import '../teacher/api_migration.dart';
import 'admin_common.dart';
import 'admission_list.dart';

// NOTE(admin-port, see porting notes): these lists are hard-coded for one school (copied from the old app's
// core/utils/standard.dart). Source them from the server when an endpoint exists.
const admissionStandards = <Opt>[
  Opt('31', 'NR'), Opt('32', 'JR'), Opt('33', 'SR'),
  Opt('34', '1'), Opt('35', '2'), Opt('36', '3'), Opt('37', '4'), Opt('38', '5'), Opt('39', '6'),
  Opt('40', '7'), Opt('41', '8'), Opt('42', '9'), Opt('43', '10'), Opt('44', '11'), Opt('45', '12'),
  Opt('93', 'Alumini'), Opt('2269', 'Soft Skill'), Opt('2270', 'Sports'), Opt('2271', 'Vocational Skill'),
  Opt('2272', 'Hobbies and Activities'), Opt('2273', 'Library'), Opt('2292', 'Non-Academic Skill'),
  Opt('2305', 'STEM Resources'), Opt('3476', 'SQAA'),
];

const admissionCategories = <Opt>[
  Opt('1', 'Open'), Opt('2', 'SC'), Opt('3', 'ST'), Opt('4', 'SEBC'), Opt('5', 'BC'), Opt('6', 'OBC'),
  Opt('8', 'GENERAL'), Opt('9', 'SBC'), Opt('10', 'OT'), Opt('11', 'Christian'), Opt('12', 'Muslim'),
  Opt('13', 'Jain'), Opt('14', 'Catholic'), Opt('15', 'Sikh'),
];

/// The old app's inverted ids: No = 1, Yes = 0.
const smsOptions = <Opt>[Opt('1', 'No'), Opt('0', 'Yes')];
const registrationStatuses = <Opt>[Opt('OPEN', 'Open'), Opt('CLOSE', 'Closed')];

/// Resolve a value that may be an id or a display name to the option id.
String? matchOpt(List<Opt> opts, String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  for (final o in opts) {
    if (o.id == v) return o.id;
  }
  for (final o in opts) {
    if (o.label.toLowerCase() == v.toLowerCase()) return o.id;
  }
  return null;
}

String _labelOf(List<Opt> opts, String? id) => opts.where((o) => o.id == id).firstOrNull?.label ?? '';

const _regFields = [
  ('stop_for_transport', 'Stop for transport'),
  ('counciler_name', 'Counsellor name'),
  ('last_exam_name', 'Last exam name'),
  ('last_exam_percentage', 'Last exam percentage'),
  ('father_education_qualification', 'Father education qualification'),
  ('father_occupation', 'Father occupation'),
  ('mother_education_qualification', 'Mother education qualification'),
  ('mother_occupation', 'Mother occupation'),
  ('annual_income', 'Annual income'),
  ('admission_docket_no', 'Admission docket no.'),
  ('registration_no', 'Registration no.'),
];

/// Create / edit an admission enquiry, or edit a registration. Pops with true after a save.
class AdmissionFormScreen extends StatefulWidget {
  const AdmissionFormScreen({super.key, required this.args, required this.stage, this.row});
  final ScreenArgs args;
  final AdmissionStage stage;
  final Map<String, dynamic>? row;

  @override
  State<AdmissionFormScreen> createState() => _AdmissionFormScreenState();
}

class _AdmissionFormScreenState extends State<AdmissionFormScreen> with SubmitGuard {
  final c = <String, TextEditingController>{};
  DateTime? dob;
  DateTime? followup;
  String? prevStd, admStd, category, sms = '1', status;
  String gender = '';

  bool get isReg => widget.stage == AdmissionStage.registration;
  bool get isEdit => widget.row != null;
  String get enquiryNo => s(widget.row?['enquiry_no']);

  static const _baseFields = [
    'first_name', 'middle_name', 'last_name', 'mobile', 'email', 'age', 'address',
    'previous_school_name', 'source_of_enquiry', 'remarks',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.row ?? const <String, dynamic>{};
    for (final k in [..._baseFields, if (isReg) ..._regFields.map((e) => e.$1)]) {
      c[k] = TextEditingController(text: s(r[k]));
    }
    if (isReg && s(r['stop_for_transport']).isEmpty) c['stop_for_transport']!.text = s(r['street_name']);
    dob = DateTime.tryParse(s(r['date_of_birth']).split(' ').first);
    followup = DateTime.tryParse(s(r['followup_date']).split(' ').first);
    prevStd = matchOpt(admissionStandards, s(r['previous_standard']));
    admStd = matchOpt(admissionStandards, s(r['admission_standard']).isEmpty ? s(r['std_name']) : s(r['admission_standard']));
    category = matchOpt(admissionCategories, s(r['category']));
    sms = matchOpt(smsOptions, s(r['send_sms'])) ?? '1';
    status = matchOpt(registrationStatuses, s(r['enquiry_status']));
    final g = s(r['gender']).toUpperCase();
    gender = g.startsWith('M') ? 'M' : (g.startsWith('F') ? 'F' : '');
  }

  @override
  void dispose() {
    for (final t in c.values) {
      t.dispose();
    }
    super.dispose();
  }

  String _t(String k) => c[k]?.text.trim() ?? '';

  Future<void> _save() async {
    if (missing(context, _t('first_name'), 'Please enter the first name.')) return;
    if (missing(context, _t('mobile'), 'Please enter a mobile number.')) return;
    final api = widget.args.api;
    final common = <String, String>{
      'first_name': _t('first_name'),
      'middle_name': _t('middle_name'),
      'last_name': _t('last_name'),
      'mobile': _t('mobile'),
      'email': _t('email'),
      'date_of_birth': dob == null ? '' : ymd(dob!),
      'address': _t('address'),
      'previous_school_name': _t('previous_school_name'),
      'followup_date': followup == null ? '' : ymd(followup!),
      'remarks': _t('remarks'),
      'source_of_enquiry': _t('source_of_enquiry'),
      'send_sms': sms ?? '1',
      'age': _t('age'),
    };
    final session = widget.args.session;
    final rowId = s(widget.row?['id']);
    final editBody = <String, String>{
      ...common,
      'sub_institute_id': '${session.subInstituteId}',
      'syear': syearOf(session),
      'user_id': '${session.userId}',
      'previous_standard': prevStd ?? '',
    };
    await guarded(() async {
      final Map<String, dynamic> res;
      if (isReg) {
        final regBody = {
          ...editBody,
          'admission_standard': _labelOf(admissionStandards, admStd),
          'status': status ?? '',
          'enquiry_id': enquiryNo,
          for (final f in _regFields) f.$1: _t(f.$1),
        };
        Future<Map<String, dynamic>> legacy() => AdminHttp.put(session, '${widget.stage.path}/$enquiryNo', regBody);
        res = rowId.isEmpty
            ? await legacy()
            : await writeNewThenLegacy(
                'admission registration edit',
                () => AdminHttp.put(session, '/api/admission_registration/$rowId', {...regBody, 'enquiry_id': rowId}),
                legacy,
              );
      } else if (isEdit) {
        final body = {...editBody, 'category': category ?? '', 'admission_standard': admStd ?? ''};
        Future<Map<String, dynamic>> legacy() => AdminHttp.put(session, '${widget.stage.path}/$enquiryNo', body);
        res = rowId.isEmpty
            ? await legacy()
            : await writeNewThenLegacy(
                'admission enquiry edit',
                () => AdminHttp.put(session, '/api/admission_enquiry/$rowId', body),
                legacy,
              );
      } else {
        final legacyBody = {
          ...common,
          'previous_standard': prevStd,
          'category': category,
          'admission_standard': admStd,
          'Gender': gender,
        };
        Future<Map<String, dynamic>> legacy() => api.post(widget.stage.path, body: legacyBody);
        // The new store does not number enquiries; compute the next one from the list like the
        // web app does. If the list can't be read (or uses a non-numeric scheme) use legacy.
        String? number;
        try {
          number = await _nextEnquiryNo(api, session.mobileSyear ?? '');
        } catch (e) {
          logFallback('admission enquiry create', e);
        }
        res = number == null
            ? await legacy()
            : await writeNewThenLegacy(
                'admission enquiry create',
                () => api.post('/api/admission_enquiry', body: {
                  ...common,
                  'enquiry_no': number,
                  'previous_standard': prevStd,
                  'category': category,
                  'admission_standard': admStd,
                  'gender': gender,
                  'created_by': session.userId,
                  'created_on': DateTime.now().toString().split('.').first,
                }),
                legacy,
              );
      }
      if (!mounted) return;
      if (report(res, ok: isEdit ? 'Updated.' : 'Enquiry added.')) Navigator.pop(context, true);
    });
  }

  Widget _text(String key, String label, {TextInputType? kb, int lines = 1}) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: TextInput(label: label, controller: c[key]!, keyboard: kb, lines: lines));

  @override
  Widget build(BuildContext context) => KitPage(
        title: isEdit ? 'Update ${isReg ? 'registration' : 'enquiry'}' : 'Add enquiry',
        bottom: formBar(label: isEdit ? 'Update' : 'Save', busy: busy, onPressed: _save),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (isEdit) ...[
            InputDecorator(decoration: const InputDecoration(labelText: 'Enquiry number'), child: Text(enquiryNo)),
            gap(),
          ],
          _text('first_name', 'First name'),
          _text('middle_name', 'Middle name'),
          _text('last_name', 'Last name'),
          _text('mobile', 'Mobile', kb: TextInputType.phone),
          _text('email', 'Email', kb: TextInputType.emailAddress),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: DateField(label: 'Date of birth', value: dob, onChanged: (d) => setState(() => dob = d), last: DateTime.now())),
          _text('age', 'Age', kb: TextInputType.number),
          _text('address', 'Address', lines: 2),
          _text('previous_school_name', 'Previous school name'),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownField(label: 'Previous standard', options: admissionStandards, value: prevStd, onChanged: (v) => setState(() => prevStd = v))),
          _text('source_of_enquiry', 'Source of enquiry'),
          _text('remarks', 'Remarks', lines: 2),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: DateField(label: 'Follow-up date', value: followup, onChanged: (d) => setState(() => followup = d))),
          if (!isReg) Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownField(label: 'Category', options: admissionCategories, value: category, onChanged: (v) => setState(() => category = v))),
          if (isReg) Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownField(label: 'Status', options: registrationStatuses, value: status, onChanged: (v) => setState(() => status = v))),
          if (!isEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<String>(
                emptySelectionAllowed: true,
                segments: const [ButtonSegment(value: 'M', label: Text('Male')), ButtonSegment(value: 'F', label: Text('Female'))],
                selected: gender.isEmpty ? <String>{} : {gender},
                onSelectionChanged: (v) => setState(() => gender = v.isEmpty ? '' : v.first),
              ),
            ),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownField(label: 'Send SMS', options: smsOptions, value: sms, onChanged: (v) => setState(() => sms = v))),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownField(label: 'Admission standard', options: admissionStandards, value: admStd, onChanged: (v) => setState(() => admStd = v))),
          if (isReg) ...[
            const SectionLabel('Registration details'),
            for (final f in _regFields) _text(f.$1, f.$2),
          ],
        ]),
      );
}

/// Next enquiry number: max numeric `enquiry_no` + 1, or `<syear>001` for the first one. Returns
/// null when existing numbers use a non-numeric scheme (the server's own numbering must be used).
Future<String?> _nextEnquiryNo(LegacyApi api, String syear) async {
  final res = await getNew(api, '/api/admission_enquiry');
  var maxNo = 0;
  for (final r in rows(res['data'])) {
    final raw = s(r['enquiry_no']);
    if (raw.isEmpty) continue;
    final n = int.tryParse(raw);
    if (n == null) return null;
    if (n > maxNo) maxNo = n;
  }
  if (maxNo > 0) return '${maxNo + 1}';
  if (syear.isEmpty) throw ApiException('no academic year for the enquiry number');
  return '${syear}001';
}
