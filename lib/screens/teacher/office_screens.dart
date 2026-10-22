import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'tk.dart';

const _green = Color(0xFF047857);
const _red = Color(0xFFDC2626);

Widget _t(String t) => Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Brand.text));

Future<void> _push(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

/// Visitor types + people to meet (also the "allocate to" list of tasks and complaints).
Future<Map<String, dynamic>> loadVisitorTypes(LegacyApi api) => postOk(api, '/get_visitorTypeAPI');

// ---------------------------------------------------------------------------------------
// Requisition
// ---------------------------------------------------------------------------------------

class RequisitionScreen extends StatelessWidget {
  const RequisitionScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final ctrl = AsyncListController();
    return ListPage(
      title: args.title.isEmpty ? 'Requisition' : args.title,
      controller: ctrl,
      emptyText: 'No requisitions yet.',
      emptyIcon: Icons.shopping_cart_outlined,
      actions: [
        addAction(context, () async {
          await _push(context, AddRequisitionScreen(args: args));
          ctrl.reload();
        }),
      ],
      load: () async => dataRows(await postOk(args.api, isAdmin(args) ? '/get_adminAllRequisitionAPI' : '/get_teacherRequisitionAPI')),
      itemBuilder: (c, r, i) {
        final approved = s(r['requisition_status']).toUpperCase() == 'APPROVED';
        return KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _t(s(r['item_name']))),
              Pill(s(r['requisition_status']).isEmpty ? 'Pending' : s(r['requisition_status']), color: approved ? _green : _red),
            ]),
            gap(4),
            KV('Req. no', s(r['requisition_no'])),
            KV('Requested by', s(r['requisition_by'])),
            KV('Date', s(r['requisition_date'])),
            KV('Quantity', '${s(r['item_qty'])} ${s(r['item_unit'])}'.trim()),
            KV('Expected', fmtDate(r['expected_delivery_time'], out: 'yyyy-MM-dd')),
            KV('Remarks', s(r['remarks'])),
            KV('Approved by', s(r['requisition_approved_by'])),
            KV('Approved qty', s(r['approved_qty'])),
            KV('Approver note', s(r['requisition_approved_remarks'])),
            KV('Approved on', s(r['requisition_approved_date'])),
          ]),
        );
      },
    );
  }
}

class AddRequisitionScreen extends StatefulWidget {
  const AddRequisitionScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AddRequisitionScreen> createState() => _AddRequisitionScreenState();
}

class _AddRequisitionScreenState extends State<AddRequisitionScreen> with BusyMixin {
  List<Opt> items = [];
  bool loading = true;
  String? item, loadError;
  final qty = TextEditingController(), unit = TextEditingController(), remarks = TextEditingController();
  DateTime expected = today();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    qty.dispose();
    unit.dispose();
    remarks.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final res = await postOk(widget.args.api, '/get_adminItemListAPI');
      if (mounted) setState(() => items = [for (final r in dataRows(res)) Opt(s(r['id']), s(r['title']))]);
    } on ApiException catch (e) {
      if (mounted) setState(() => loadError = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: 'New requisition',
      bottom: PrimaryButton(
        label: 'Save',
        busy: busy,
        onPressed: () {
          if (item == null) return toast(context, 'Please select an item.', error: true);
          if (qty.text.trim().isEmpty) return toast(context, 'Please enter the quantity.', error: true);
          if (remarks.text.trim().isEmpty) return toast(context, 'Please enter remarks.', error: true);
          submit(() async => postOk(a.api, '/add_teacherRequisitionAPI', body: {
                // The server validates this audit field; the old app looked the address up online.
                'created_ip_address': await _deviceIp(),
                'requisition_by': a.session.userId,
                'created_by': a.session.userId,
                'item_id': item,
                'item_unit': unit.text.trim(),
                'item_qty': qty.text.trim(),
                'expected_delivery_time': dts(expected),
                'remarks': remarks.text.trim(),
              }));
        },
      ),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          Text('Requisition by ${a.session.name}', style: const TextStyle(color: Brand.muted)),
          DropdownField(label: 'Item', options: items, value: item, loading: loading, onChanged: (v) => setState(() => item = v)),
          if (loadError != null) TextButton(onPressed: _load, child: Text('$loadError Tap to retry.')),
          TextInput(label: 'Quantity', controller: qty, keyboard: TextInputType.number),
          TextInput(label: 'Unit', controller: unit),
          DateField(label: 'Expected delivery date', value: expected, onChanged: (d) => setState(() => expected = d)),
          TextInput(label: 'Remarks', controller: remarks, lines: 3),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Task and complaint
// ---------------------------------------------------------------------------------------

class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final ctrl = AsyncListController();
    return ListPage(
      title: args.title.isEmpty ? 'Tasks' : args.title,
      controller: ctrl,
      emptyText: 'No tasks yet.',
      emptyIcon: Icons.task_alt_outlined,
      actions: [
        addAction(context, () async {
          await _push(context, AddAllocationScreen(args: args, complaint: false));
          ctrl.reload();
        }),
      ],
      load: () async => dataRows(await postOk(args.api, isAdmin(args) ? '/get_taskAPI' : '/get_teachertaskAPI')),
      itemBuilder: (c, r, i) {
        final done = s(r['STATUS']).toUpperCase() == 'COMPLETED';
        return KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _t(s(r['TASK_TITLE']))),
              attachmentButton(c, s(r['TASK_ATTACHMENT'])),
              Pill(s(r['STATUS']), color: done ? _green : _red),
            ]),
            if (s(r['TASK_DESCRIPTION']).isNotEmpty) Text(s(r['TASK_DESCRIPTION'])),
            gap(4),
            KV('Task by', s(r['ALLOCATOR'])),
            KV('Allocated to', s(r['ALLOCATED_TO'])),
            KV('Created', fmtDate(r['CREATED_ON'], out: 'MM-dd-yyyy')),
            KV('Updated on', fmtDate(r['TASK_DATE'], out: 'MM-dd-yyyy')),
          ]),
        );
      },
    );
  }
}

class ComplainScreen extends StatelessWidget {
  const ComplainScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final ctrl = AsyncListController();
    return ListPage(
      title: args.title.isEmpty ? 'Complaints' : args.title,
      controller: ctrl,
      emptyText: 'No complaints yet.',
      emptyIcon: Icons.report_gmailerrorred_outlined,
      actions: [
        addAction(context, () async {
          await _push(context, AddAllocationScreen(args: args, complaint: true));
          ctrl.reload();
        }),
      ],
      load: () async => dataRows(await postOk(args.api, isAdmin(args) ? '/get_complaintAPI' : '/get_teachercomplaintAPI')),
      itemBuilder: (c, r, i) {
        final done = s(r['COMPLAINT_SOLUTION']).toUpperCase() == 'COMPLETED';
        return KitCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _t(s(r['TITLE']))),
              attachmentButton(c, s(r['COMPLAINT_ATTACHMENT'])),
              if (s(r['COMPLAINT_SOLUTION']).isNotEmpty) Pill(s(r['COMPLAINT_SOLUTION']), color: done ? _green : _red),
            ]),
            if (s(r['DESCRIPTION']).isNotEmpty) Text(s(r['DESCRIPTION'])),
            gap(4),
            KV('Complaint by', s(r['COMPLAINT_BY'])),
            KV('Date', fmtDate(r['DATE'], out: 'dd-MM-yyyy')),
            if (s(r['COMPLAINT_SOLUTION_BY']).isNotEmpty) ...[
              KV('Solution by', s(r['COMPLAINT_SOLUTION_BY'])),
              KV('Solution on', fmtDate(r['CREATED_DATE'], out: 'dd-MM-yyyy')),
            ],
          ]),
        );
      },
    );
  }
}

/// Add task / add complaint: identical forms posting to different endpoints.
class AddAllocationScreen extends StatefulWidget {
  const AddAllocationScreen({super.key, required this.args, required this.complaint});
  final ScreenArgs args;
  final bool complaint;

  @override
  State<AddAllocationScreen> createState() => _AddAllocationScreenState();
}

class _AddAllocationScreenState extends State<AddAllocationScreen> with BusyMixin {
  List<Opt> people = [];
  bool loading = true;
  String? person;
  final title = TextEditingController(), desc = TextEditingController();
  DateTime date = today();
  PickedFile? file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    title.dispose();
    desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await loadVisitorTypes(widget.args.api);
      if (mounted) setState(() => people = [for (final r in rows(res['to_meet_array'])) Opt(s(r['id']), s(r['staff_name']).isEmpty ? s(r['full_name']) : s(r['staff_name']))]);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final admin = isAdmin(a);
    final url = widget.complaint ? (admin ? '/add_complaintAPI' : '/add_teachercomplaintAPI') : (admin ? '/add_taskAPI' : '/add_teachertaskAPI');
    return KitPage(
      title: widget.complaint ? 'New complaint' : 'New task',
      bottom: PrimaryButton(
        label: 'Save',
        busy: busy,
        onPressed: () {
          if (title.text.trim().isEmpty) return toast(context, 'Please enter a title.', error: true);
          if (person == null) return toast(context, 'Please select who it is allocated to.', error: true);
          submit(
            () => postOk(a.api, url, body: {
              'title': title.text.trim(),
              'description': desc.text.trim(),
              'date': dts(date),
              'allocated_to': person,
            }, files: [if (file != null) file!.asUpload('attachment')]),
          );
        },
      ),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        FormCard(children: [
          TextInput(label: 'Title', controller: title),
          TextInput(label: 'Description', controller: desc, lines: 3),
          DropdownField(label: 'Allocated to', options: people, value: person, loading: loading, onChanged: (v) => setState(() => person = v)),
          DateField(label: 'Date', value: date, onChanged: (d) => setState(() => date = d)),
          FileField(label: 'Attachment (optional)', file: file, onChanged: (f) => setState(() => file = f)),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Visitors
// ---------------------------------------------------------------------------------------

class VisitorScreen extends StatelessWidget {
  const VisitorScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => RangeListPage(
        title: args.title.isEmpty ? 'Visitors' : args.title,
        emptyText: 'No visitors in this date range.',
        emptyIcon: Icons.badge_outlined,
        onAdd: () => _push(context, AddVisitorScreen(args: args)),
        load: (from, to) async {
          final res = await postOk(args.api, isAdmin(args) ? '/get_adminVisitorListAPI' : '/get_visitorAPI', body: {'from_date': ymd(from), 'to_date': ymd(to)});
          return dataRows(res);
        },
        itemBuilder: (c, r, i) => KitCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PersonAvatar(url: s(r['visitor_photo']), name: s(r['name']), radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _t(s(r['name'])),
                KV('Contact', s(r['contact'])),
                KV('Email', s(r['email'])),
                KV('Coming from', s(r['coming_from'])),
                KV('Relation', s(r['relation'])),
                KV('Purpose', s(r['purpose'])),
                KV('Meet on', s(r['updated_at'])),
                KV('To meet', s(r['staff_name'])),
              ]),
            ),
          ]),
        ),
      );
}

class AddVisitorScreen extends StatefulWidget {
  const AddVisitorScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<AddVisitorScreen> createState() => _AddVisitorScreenState();
}

class _AddVisitorScreenState extends State<AddVisitorScreen> with BusyMixin {
  List<Opt> types = [], staff = [];
  bool loading = true;
  String? type, toMeet;
  bool prior = false;
  final name = TextEditingController(), contact = TextEditingController(), email = TextEditingController();
  final from = TextEditingController(), relation = TextEditingController(), purpose = TextEditingController(), idCard = TextEditingController();
  DateTime date = today();
  TimeOfDay? time;
  PickedFile? photo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [name, contact, email, from, relation, purpose, idCard]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await loadVisitorTypes(widget.args.api);
      if (!mounted) return;
      setState(() {
        types = [for (final r in rows(res['visitor_type_data'])) Opt(s(r['id']), s(r['title']))];
        staff = [for (final r in rows(res['to_meet_array'])) Opt(s(r['id']), s(r['staff_name']).isEmpty ? s(r['full_name']) : s(r['staff_name']))];
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'New visitor',
        bottom: PrimaryButton(
          label: 'Save',
          busy: busy,
          onPressed: () {
            if (name.text.trim().isEmpty) return toast(context, 'Please enter the visitor name.', error: true);
            if (toMeet == null) return toast(context, 'Please select who the visitor is meeting.', error: true);
            submit(() => postOk(widget.args.api, '/add_visitorAPI', body: {
                  'appointment_type': prior ? 'Prior' : 'Direct',
                  'visitor_type': type,
                  'name': name.text.trim(),
                  'contact': contact.text.trim(),
                  'email': email.text.trim(),
                  'coming_from': from.text.trim(),
                  'to_meet': toMeet,
                  'relation': relation.text.trim(),
                  'purpose': purpose.text.trim(),
                  'visitor_idcard': idCard.text.trim(),
                  'meet_date': dts(date),
                  'in_time': time == null ? '' : '${time!.hour}:${time!.minute}',
                }, files: [if (photo != null) photo!.asUpload('file_name')]));
          },
        ),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          FormCard(children: [
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('Direct')), ButtonSegment(value: true, label: Text('Prior'))],
              selected: {prior},
              onSelectionChanged: (v) => setState(() => prior = v.first),
            ),
            DropdownField(label: 'Visitor type', options: types, value: type, loading: loading, onChanged: (v) => setState(() => type = v)),
            TextInput(label: 'Visitor name', controller: name),
            TextInput(label: 'Contact', controller: contact, keyboard: TextInputType.phone),
            TextInput(label: 'Email', controller: email, keyboard: TextInputType.emailAddress),
            TextInput(label: 'Coming from', controller: from),
            DropdownField(label: 'To meet', options: staff, value: toMeet, loading: loading, onChanged: (v) => setState(() => toMeet = v)),
            TextInput(label: 'Relation with', controller: relation),
            TextInput(label: 'Purpose', controller: purpose, lines: 3),
            TextInput(label: 'ID card number', controller: idCard),
            FileField(label: 'Visitor photo', file: photo, onChanged: (f) => setState(() => photo = f)),
            DateField(label: 'Meet date', value: date, onChanged: (d) => setState(() => date = d)),
            TimeField(label: 'Check-in time', value: time, onChanged: (t) => setState(() => time = t)),
          ]),
        ]),
      );
}

/// The device's first non-loopback IPv4 address (what the requisition audit field needs).
Future<String> _deviceIp() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final i in interfaces) {
      if (i.addresses.isNotEmpty) return i.addresses.first.address;
    }
  } catch (_) {}
  return '0.0.0.0';
}
