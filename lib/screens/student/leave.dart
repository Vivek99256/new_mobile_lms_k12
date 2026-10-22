import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'student_common.dart';

/// Leave application: apply form and status list in two tabs.
class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key, required this.args, this.picker});
  final ScreenArgs args;
  final ImagePicker? picker;

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> with SingleTickerProviderStateMixin {
  static const reasons = ['Sick Leave', 'Full Leave', 'Half Leave', 'Short Leave'];
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _status = AsyncListController();
  final _desc = TextEditingController();
  DateTime? _from, _to;
  String? _reason;
  String? _photoPath;
  bool _busy = false;
  String? _formError;

  @override
  void dispose() {
    _tabs.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Camera'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Gallery'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (src == null) return;
    try {
      final x = await (widget.picker ?? ImagePicker()).pickImage(source: src, maxWidth: 500, maxHeight: 500, imageQuality: 50);
      if (x != null && mounted) setState(() => _photoPath = x.path);
    } catch (_) {
      if (mounted) toast(context, 'Could not open the camera or gallery.', error: true);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final err = _from == null
        ? 'Please select from date.'
        : _to == null
            ? 'Please select to date.'
            : _reason == null
                ? 'Please select the reason for leave.'
                : _desc.text.trim().isEmpty
                    ? 'Please enter the description.'
                    : null;
    setState(() => _formError = err);
    if (err != null) return;
    setState(() => _busy = true);
    try {
      final res = await widget.args.api.post(
        '/front_desk/leave_application/add_leave_application',
        body: {
          'message': _desc.text.trim(),
          'apply_date': fmtDate(DateTime.now().toIso8601String(), out: 'yyyy-MM-dd'),
          'from_date': fmtDate(_from!.toIso8601String(), out: 'yyyy-MM-dd'),
          'to_date': fmtDate(_to!.toIso8601String(), out: 'yyyy-MM-dd'),
          'title': _reason,
        },
        files: [if (_photoPath != null) UploadFile('attechment', _photoPath!)],
      );
      if (!mounted) return;
      if (LegacyApi.ok(res)) {
        toast(context, 'Leave request sent.');
        setState(() {
          _from = null;
          _to = null;
          _reason = null;
          _photoPath = null;
          _desc.clear();
        });
        _status.reload();
        _tabs.animateTo(1);
      } else {
        toast(context, LegacyApi.messageOf(res), error: true);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Leave application',
        child: Column(children: [
          Material(color: Colors.white, child: TabBar(controller: _tabs, tabs: const [Tab(text: 'Apply'), Tab(text: 'Status')])),
          Expanded(child: TabBarView(controller: _tabs, children: [_form(), _statusList()])),
        ]),
      );

  Widget _form() {
    final today = DateTime.now();
    return ListView(padding: const EdgeInsets.all(16), children: [
      DateField(label: 'From date', value: _from, first: DateTime(today.year, today.month, today.day), onChanged: (d) => setState(() {
            _from = d;
            _to = null;
          })),
      const SizedBox(height: 12),
      if (_from == null)
        const InputDecorator(decoration: InputDecoration(labelText: 'To date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 20)), child: Text('Choose from date first', style: TextStyle(color: Brand.muted)))
      else
        DateField(label: 'To date', value: _to, first: _from, onChanged: (d) => setState(() => _to = d)),
      const SizedBox(height: 12),
      DropdownField(label: 'Reason of leave', options: [for (final r in reasons) Opt(r, r)], value: _reason, onChanged: (v) => setState(() => _reason = v)),
      const SizedBox(height: 12),
      TextInput(label: 'Description of leave', controller: _desc, lines: 5),
      const SizedBox(height: 12),
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pick,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Attachment (optional)',
            suffixIcon: _photoPath == null ? const Icon(Icons.add_a_photo_outlined) : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _photoPath = null)),
          ),
          child: Text(_photoPath == null ? 'Add a photo' : 'attachment.jpg', style: TextStyle(color: _photoPath == null ? Brand.muted : Brand.text)),
        ),
      ),
      if (_formError != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_formError!, style: const TextStyle(color: Color(0xFFB91C1C)))),
      const SizedBox(height: 18),
      PrimaryButton(label: 'Apply leave', busy: _busy, onPressed: _submit),
    ]);
  }

  Widget _statusList() => AsyncList(
        controller: _status,
        emptyText: 'You have not applied for any leave yet.',
        emptyIcon: Icons.event_busy_outlined,
        load: () => Sx.list(widget.args, '/studentLeaveApplicationAPI'),
        itemBuilder: (c, r, i) {
          final st = s(r['status']);
          final low = st.toLowerCase();
          final (icon, color, label) = st.isEmpty
              ? (Icons.hourglass_top_rounded, const Color(0xFFF59E0B), 'Pending')
              : low.startsWith('approve')
                  ? (Icons.check_circle_rounded, const Color(0xFF16A34A), st)
                  : (Icons.cancel_rounded, const Color(0xFFE11D48), st);
          return KitCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text('${fmtDate(r['from_date'], out: 'dd MMM')} to ${fmtDate(r['to_date'], out: 'dd MMM yyyy')}', style: const TextStyle(color: Brand.primary, fontWeight: FontWeight.w600)),
              Text('Applied ${fmtDate(r['apply_date'], out: 'yyyy-MM-dd')}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
              if (s(r['message']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Note: ${s(r['message'])}', maxLines: 3, overflow: TextOverflow.ellipsis)),
              if (s(r['reply']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Reply: ${s(r['reply'])}', style: const TextStyle(color: Color(0xFF16A34A)))),
              if (s(r['reply_on']).isNotEmpty) Text(s(r['reply_on']), style: const TextStyle(color: Brand.muted, fontSize: 12)),
            ]),
          );
        },
      );
}
