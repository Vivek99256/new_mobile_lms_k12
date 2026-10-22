import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'student_common.dart';

/// Parent communication: previous messages with replies, and a form to ask something new.
class ParentCommunicationScreen extends StatefulWidget {
  const ParentCommunicationScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  State<ParentCommunicationScreen> createState() => _ParentCommunicationScreenState();
}

class _ParentCommunicationScreenState extends State<ParentCommunicationScreen> {
  final _subject = TextEditingController();
  final _question = TextEditingController();
  final _list = AsyncListController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final err = _subject.text.trim().isEmpty ? 'Please enter a subject.' : (_question.text.trim().isEmpty ? 'Please enter your question.' : null);
    setState(() => _error = err);
    if (err != null) return;
    setState(() => _busy = true);
    try {
      final res = await widget.args.api.post('/add_communicationAPI', body: {'title': _subject.text.trim(), 'message': _question.text.trim()});
      if (!mounted) return;
      if (LegacyApi.ok(res)) {
        toast(context, LegacyApi.messageOf(res, 'Your message was sent.'));
        _subject.clear();
        _question.clear();
        _list.reload();
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
        title: 'Parent communication',
        child: AsyncList(
          controller: _list,
          emptyText: 'No messages yet. Ask your first question above.',
          emptyIcon: Icons.forum_outlined,
          header: KitCard(
            child: Column(children: [
              TextInput(label: 'Subject', controller: _subject),
              const SizedBox(height: 12),
              TextInput(label: 'Ask question', controller: _question, lines: 4),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
              const SizedBox(height: 12),
              PrimaryButton(label: 'Submit', busy: _busy, onPressed: _submit),
            ]),
          ),
          load: () => Sx.list(widget.args, '/studentParentcommunicationListAPI'),
          itemBuilder: (c, r, i) => KitCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s(r['title']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              Text(fmtDate(r['created_at'], out: 'yyyy-MM-dd HH:mm'), style: const TextStyle(color: Brand.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Text(s(r['message'])),
              if (s(r['reply']).isNotEmpty && s(r['reply']).toLowerCase() != 'null') ...[
                const Divider(height: 18, color: Brand.border),
                Text('Reply: ${s(r['reply'])}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                if (s(r['reply_by']).isNotEmpty) Text('By ${s(r['reply_by'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                if (s(r['reply_on']).isNotEmpty) Text('On ${s(r['reply_on'])}', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
              ],
            ]),
          ),
        ),
      );
}

/// Face-attendance reference photos: shows saved photos, lets the student retake and save.
class FaceAttendanceScreen extends StatefulWidget {
  const FaceAttendanceScreen({super.key, required this.args, this.picker});
  final ScreenArgs args;
  final ImagePicker? picker;

  @override
  State<FaceAttendanceScreen> createState() => _FaceAttendanceScreenState();
}

class _FaceAttendanceScreenState extends State<FaceAttendanceScreen> {
  List<String> _remote = [];
  final List<String> _local = [];
  bool _loading = true, _saving = false, _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.args.api.post('/get_studentCapturePhotosAPI');
      if (!mounted) return;
      if (LegacyApi.ok(res)) {
        _remote = [for (final r in rows(res['data'])) if (s(r['stu_image']).isNotEmpty) s(r['stu_image'])];
      } else {
        _remote = [];
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _capture() async {
    try {
      final x = await (widget.picker ?? ImagePicker()).pickImage(source: ImageSource.camera, maxWidth: 500, maxHeight: 500, imageQuality: 80);
      if (x == null || !mounted) return;
      setState(() {
        if (!_changed) _remote = []; // the first new photo replaces the saved set
        _local.add(x.path);
        _changed = true;
      });
    } catch (_) {
      if (mounted) toast(context, 'Could not open the camera. Check the camera permission.', error: true);
    }
  }

  Future<void> _save() async {
    if (_saving || _local.isEmpty) return;
    setState(() => _saving = true);
    try {
      final res = await widget.args.api.post('/add_studentCapturePhotosAPI', files: [for (var i = 0; i < _local.length; i++) UploadFile('stu_image[$i]', _local[i])]);
      if (!mounted) return;
      if (LegacyApi.ok(res)) {
        toast(context, LegacyApi.messageOf(res, 'Photos saved.'));
        Navigator.maybePop(context);
        return;
      }
      toast(context, LegacyApi.messageOf(res), error: true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _tile(Widget child, {VoidCallback? onRemove, bool saved = false}) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          child,
          if (saved) const Positioned(right: 6, top: 6, child: CircleAvatar(radius: 12, backgroundColor: Color(0xFF16A34A), child: Icon(Icons.check, size: 16, color: Colors.white))),
          if (onRemove != null)
            Positioned(right: 2, top: 2, child: IconButton(tooltip: 'Remove photo', style: IconButton.styleFrom(backgroundColor: const Color(0xFFE11D48), minimumSize: const Size(36, 36)), icon: const Icon(Icons.close, size: 18, color: Colors.white), onPressed: onRemove)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    return KitPage(
      title: 'Attendance photos',
      bottom: _changed && _local.isNotEmpty ? PrimaryButton(label: 'Save', busy: _saving, onPressed: _save) : null,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? KitMessage(icon: Icons.cloud_off_outlined, text: _error!, action: 'Try again', onAction: _load)
              : ListView(padding: const EdgeInsets.all(16), children: [
                  KitCard(
                    child: Row(children: [
                      PersonAvatar(url: a.session.imageUrl ?? '', name: a.session.name, radius: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.session.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text([Sx.raw(a, 'std_name'), Sx.raw(a, 'division')].where((e) => e.isNotEmpty).join(' - '), style: const TextStyle(color: Brand.muted)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Take clear photos of your face. They are used to mark your attendance.', style: TextStyle(color: Brand.muted, fontSize: 13))),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final u in _remote) _tile(Image.network(u, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Brand.border, child: Icon(Icons.broken_image_outlined))), saved: true),
                      for (var i = 0; i < _local.length; i++)
                        _tile(Image.file(File(_local[i]), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE8EDFC), child: Icon(Icons.image_outlined, color: Brand.primary, size: 40))), onRemove: () => setState(() => _local.removeAt(i))),
                      InkWell(
                        onTap: _capture,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(color: const Color(0xFFE8EDFC), borderRadius: BorderRadius.circular(16)),
                          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.photo_camera_outlined, color: Brand.primary, size: 36),
                            SizedBox(height: 6),
                            Text('Take photo', style: TextStyle(color: Brand.primary, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ]),
    );
  }
}
