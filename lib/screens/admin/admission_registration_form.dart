import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import '../teacher/api_migration.dart';
import 'admin_common.dart';
import '../../ui/app_loader.dart';

/// Registration edit, built from the server like the web's side drawer: dropdown options come from
/// `data_fields` (status, quota, payment mode, blood group, religion, caste, admission status),
/// the school's own standards / divisions / categories come from the same response, and the
/// school's custom registration fields are drawn automatically. Nothing is hard-coded per school.
class AdmissionRegistrationFormScreen extends StatefulWidget {
  const AdmissionRegistrationFormScreen({super.key, required this.args, required this.row});
  final ScreenArgs args;
  final Map<String, dynamic> row;

  @override
  State<AdmissionRegistrationFormScreen> createState() => _AdmissionRegistrationFormScreenState();
}

class _Spec {
  const _Spec(this.key, this.label, {this.kind = _Kind.text, this.lines = 1});
  final String key;
  final String label;
  final _Kind kind;
  final int lines;
}

enum _Kind { text, phone, number, email, date }

class _AdmissionRegistrationFormScreenState extends State<AdmissionRegistrationFormScreen> with SubmitGuard {
  static const _sections = <(String, List<_Spec>)>[
    ('Student details', [
      _Spec('first_name', 'First name'),
      _Spec('middle_name', 'Middle name'),
      _Spec('last_name', 'Last name'),
      _Spec('mobile', 'Mobile', kind: _Kind.phone),
      _Spec('email', 'Email', kind: _Kind.email),
      _Spec('date_of_birth', 'Date of birth', kind: _Kind.date),
      _Spec('age', 'Age', kind: _Kind.number),
      _Spec('place_of_birth', 'Place of birth'),
      _Spec('address', 'Address', lines: 2),
      _Spec('mother_name', "Mother's name"),
      _Spec('mother_mobile_number', "Mother's mobile", kind: _Kind.phone),
      _Spec('aadhar_number', 'Aadhar number', kind: _Kind.number),
      _Spec('previous_school_name', 'Previous school name'),
      _Spec('source_of_enquiry', 'Source of enquiry'),
      _Spec('remarks', 'Remarks', lines: 2),
      _Spec('followup_date', 'Follow-up date', kind: _Kind.date),
    ]),
    ('Admission', [
      _Spec('register_number', 'Register number'),
      _Spec('enrollment_no', 'Enrollment number'),
      _Spec('admission_date', 'Admission date', kind: _Kind.date),
    ]),
    ('Payment', [
      _Spec('amount', 'Amount', kind: _Kind.number),
      _Spec('fees_remark', 'Fees remark', lines: 2),
      _Spec('bank_name', 'Bank name'),
      _Spec('bank_branch', 'Bank branch'),
      _Spec('cheque_no', 'Cheque number'),
      _Spec('cheque_date', 'Cheque date', kind: _Kind.date),
      _Spec('date_of_payment', 'Date of payment', kind: _Kind.date),
    ]),
  ];

  final _ctl = <String, TextEditingController>{};
  final _dates = <String, DateTime?>{};
  final _pick = <String, String?>{}; // dropdown values by field key
  Map<String, dynamic> _record = {};
  List<Map<String, dynamic>> _custom = [];
  Map<String, List<Opt>> _opts = {};
  List<Opt> _standards = [];
  List<Map<String, dynamic>> _divisions = [];
  String _gender = '';
  bool _loading = true;
  String? _error;

  String get _id => s(widget.row['id']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Opt> _fromDataFields(Map<String, dynamic> df, String key) {
    final raw = df[key];
    if (raw is! List) return [];
    final out = <Opt>[];
    for (final o in raw.whereType<Map>()) {
      final value = s(o['display_value'] ?? o['display_text']);
      final label = s(o['display_text'] ?? o['display_value']);
      if (value.isNotEmpty && label.isNotEmpty) out.add(Opt(value, label));
    }
    return out;
  }

  List<Opt> _fromList(dynamic list, List<String> labelKeys) {
    if (list is! List) return [];
    final out = <Opt>[];
    for (final o in list.whereType<Map>()) {
      final id = s(o['id']);
      var label = '';
      for (final k in labelKeys) {
        label = s(o[k]);
        if (label.isNotEmpty) break;
      }
      if (id.isNotEmpty && label.isNotEmpty) out.add(Opt(id, label));
    }
    return out;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await getNew(widget.args.api, '/api/admission_registration/$_id/edit');
      final rec = res['editData'];
      if (rec is! Map) throw ApiException('Registration details were not found.');
      _record = Map<String, dynamic>.from(rec);
      _custom = rows(res['custom_fields']);
      final df = res['data_fields'] is Map ? Map<String, dynamic>.from(res['data_fields'] as Map) : <String, dynamic>{};

      List<Opt> pick(String key, List<Opt> fallback) {
        final fromServer = _fromDataFields(df, key);
        return fromServer.isNotEmpty ? fromServer : fallback;
      }

      _opts = {
        'status': pick('status', const [Opt('OPEN', 'Open'), Opt('CLOSE', 'Close')]),
        'admission_status': pick('admission_status', const [Opt('YES', 'Yes'), Opt('NO', 'No')]),
        'student_quota': pick('student_quota', _fromList(res['category'], ['title', 'name'])),
        'payment_mode': pick('payment_mode', const []),
        'blood_group': pick('blood_group', _fromList(res['bloodgroup_data'], ['bloodgroup', 'blood_group', 'name'])),
        'religion': pick('religion', _fromList(res['religion_data'], ['religion_name', 'religion', 'name'])),
        'cast': pick('cast', _fromList(res['caste_data'], ['caste_name', 'cast', 'name'])),
      };
      _standards = _fromList(res['standard'], ['name']);
      _divisions = rows(res['division']);

      for (final sec in _sections) {
        for (final f in sec.$2) {
          final v = s(_record[f.key]);
          if (f.kind == _Kind.date) {
            _dates[f.key] = DateTime.tryParse(v.split(' ').first);
          } else {
            _ctl[f.key] = TextEditingController(text: v);
          }
        }
      }
      if (s(_record['register_number']).isEmpty && s(res['next_register_number']).isNotEmpty) {
        _ctl['register_number']!.text = s(res['next_register_number']);
      }
      for (final f in _custom) {
        final name = s(f['field_name']);
        if (name.isNotEmpty) _ctl[name] = TextEditingController(text: s(_record[name]));
      }
      for (final k in _opts.keys) {
        _pick[k] = _match(_opts[k]!, s(_record[k]));
      }
      _pick['status'] ??= _match(_opts['status']!, 'CLOSE');
      _pick['previous_standard'] = _match(_standards, s(_record['previous_standard']));
      _pick['admission_standard'] = _match(_standards, s(_record['admission_standard']));
      _pick['admission_division'] = _match(_divisionOpts(_pick['admission_standard']), s(_record['admission_division']));
      final g = s(_record['gender']).toUpperCase();
      _gender = g.startsWith('M') ? 'M' : (g.startsWith('F') ? 'F' : '');
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load this registration. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// An id or a display label, matched to an option id (or kept as-is so a stored value is never lost).
  String? _match(List<Opt> opts, String raw) {
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

  List<Opt> _divisionOpts(String? standardId) => [
        for (final d in _divisions)
          if (standardId == null || s(d['standard_id']).isEmpty || s(d['standard_id']) == standardId) Opt(s(d['id']), s(d['name'])),
      ];

  Future<void> _save() async {
    final session = widget.args.session;
    final body = <String, String>{
      'type': 'API',
      'sub_institute_id': '${session.subInstituteId}',
      'syear': syearOf(session),
      'user_id': '${session.userId}',
      'enquiry_id': s(_record['enquiry_id']).isEmpty ? _id : s(_record['enquiry_id']),
    };
    void put(String key, String value) {
      // Like the web: blank fields are not sent, so saved values are never wiped by accident.
      if (value.trim().isNotEmpty) body[key] = value.trim();
    }

    for (final e in _ctl.entries) {
      put(e.key, e.value.text);
    }
    for (final e in _dates.entries) {
      if (e.value != null) put(e.key, ymd(e.value!));
    }
    for (final e in _pick.entries) {
      put(e.key, e.value ?? '');
    }
    put('gender', _gender);
    if (s(_record['enquiry_no']).isNotEmpty) put('enquiry_no', s(_record['enquiry_no']));

    await guarded(() async {
      final res = await AdminHttp.put(session, '/api/admission_registration/$_id', body);
      if (!mounted) return;
      if (report(res, ok: 'Registration updated.')) Navigator.pop(context, true);
    });
  }

  Widget _field(_Spec f) {
    Widget child;
    switch (f.kind) {
      case _Kind.date:
        child = DateField(label: f.label, value: _dates[f.key], onChanged: (d) => setState(() => _dates[f.key] = d));
      default:
        child = TextInput(
          label: f.label,
          controller: _ctl[f.key]!,
          lines: f.lines,
          keyboard: switch (f.kind) {
            _Kind.phone => TextInputType.phone,
            _Kind.number => TextInputType.number,
            _Kind.email => TextInputType.emailAddress,
            _ => null,
          },
        );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
  }

  Widget _drop(String label, String key, List<Opt> opts, {ValueChanged<String?>? onChanged}) => opts.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownField(
            label: label,
            options: opts,
            value: _pick[key],
            onChanged: onChanged ?? (v) => setState(() => _pick[key] = v),
          ),
        );

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Update registration',
        bottom: _loading || _error != null ? null : formBar(label: 'Save changes', busy: busy, onPressed: _save),
        child: _loading
            ? const AppLoader()
            : _error != null
                ? KitMessage(icon: Icons.error_outline, text: _error!, action: 'Retry', onAction: _load)
                : ListView(padding: const EdgeInsets.all(16), children: [
                    InputDecorator(decoration: const InputDecoration(labelText: 'Enquiry number'), child: Text(s(_record['enquiry_no']))),
                    gap(),
                    const SectionLabel('Student details'),
                    for (final f in _sections[0].$2.take(5)) _field(f),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SegmentedButton<String>(
                        emptySelectionAllowed: true,
                        segments: const [ButtonSegment(value: 'M', label: Text('Male')), ButtonSegment(value: 'F', label: Text('Female'))],
                        selected: _gender.isEmpty ? <String>{} : {_gender},
                        onSelectionChanged: (v) => setState(() => _gender = v.isEmpty ? '' : v.first),
                      ),
                    ),
                    for (final f in _sections[0].$2.skip(5)) _field(f),
                    _drop('Previous standard', 'previous_standard', _standards),
                    _drop('Blood group', 'blood_group', _opts['blood_group'] ?? const []),
                    _drop('Religion', 'religion', _opts['religion'] ?? const []),
                    _drop('Caste', 'cast', _opts['cast'] ?? const []),
                    const SectionLabel('Admission'),
                    _drop('Admission standard', 'admission_standard', _standards, onChanged: (v) {
                      setState(() {
                        _pick['admission_standard'] = v;
                        _pick['admission_division'] = null;
                      });
                    }),
                    _drop('Division', 'admission_division', _divisionOpts(_pick['admission_standard'])),
                    _drop('Student quota', 'student_quota', _opts['student_quota'] ?? const []),
                    for (final f in _sections[1].$2) _field(f),
                    _drop('Admission confirmed', 'admission_status', _opts['admission_status'] ?? const []),
                    _drop('Status', 'status', _opts['status'] ?? const []),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Saving as Open moves this record to Admission Confirmation.', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
                    ),
                    const SectionLabel('Payment'),
                    _drop('Payment mode', 'payment_mode', _opts['payment_mode'] ?? const []),
                    for (final f in _sections[2].$2) _field(f),
                    if (_custom.any((f) => s(f['field_name']).isNotEmpty)) ...[
                      const SectionLabel('Custom registration fields'),
                      for (final f in _custom)
                        if (s(f['field_name']).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextInput(label: s(f['field_label']).isEmpty ? s(f['field_name']) : s(f['field_label']), controller: _ctl[s(f['field_name'])]!),
                          ),
                    ],
                  ]),
      );
}
