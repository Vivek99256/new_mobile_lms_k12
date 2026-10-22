import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/legacy_api.dart';
import '../../ui/theme.dart';
import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';
import 'camera_helper.dart';

/// Reference photos of one student. The first new photo replaces the stored set; Save
/// uploads the new set.
class StudentAttendancePhotosScreen extends StatefulWidget {
  const StudentAttendancePhotosScreen({super.key, required this.args, required this.student, this.sectionName = ''});
  final ScreenArgs args;
  final Map<String, dynamic> student;
  final String sectionName;

  @override
  State<StudentAttendancePhotosScreen> createState() => _StudentAttendancePhotosScreenState();
}

class _StudentAttendancePhotosScreenState extends State<StudentAttendancePhotosScreen> with SubmitGuard {
  List<String> saved = [];
  final fresh = <String>[];
  bool loading = true;
  String? error;

  LegacyApi get api => widget.args.api;
  String get _sid => s(widget.student['id']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await api.post('/get_studentCapturePhotosAPI', body: {'student_id': _sid});
      if (!mounted) return;
      setState(() => saved = [for (final r in rows(res['data'])) if (s(r['stu_image']).isNotEmpty) s(r['stu_image'])]);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    final p = await takePhoto(context);
    if (p == null || !mounted) return;
    setState(() {
      if (fresh.isEmpty) saved = [];
      fresh.add(p);
    });
  }

  Future<void> _save() async {
    await guarded(() async {
      final res = await api.post('/add_studentCapturePhotosAPI',
          body: {'student_id': _sid},
          files: [for (var i = 0; i < fresh.length; i++) UploadFile('stu_image[$i]', fresh[i])]);
      if (!mounted) return;
      if (report(res, ok: 'Photos saved.')) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.student;
    final cls = [s(st['standard_name']), s(st['division_name'])].where((e) => e.isNotEmpty).join(' - ');
    return KitPage(
      title: 'Student attendance photos',
      bottom: fresh.isEmpty ? null : formBar(label: 'Save photos', busy: busy, onPressed: _save),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? KitMessage(icon: Icons.cloud_off_outlined, text: error!, action: 'Try again', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    KitCard(
                      child: Row(children: [
                        PersonAvatar(url: s(st['student_image']), name: s(st['student_name']), radius: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s(st['student_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('Roll No. ${s(st['roll_no'])}  |  $cls', style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                            if (widget.sectionName.isNotEmpty) Text(widget.sectionName, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                          ]),
                        ),
                      ]),
                    ),
                    gap(16),
                    SectionLabel(fresh.isEmpty ? 'Stored photos' : 'New photos (replace the stored set)'),
                    if (saved.isEmpty && fresh.isEmpty)
                      const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('No reference photos yet. Add some below.', style: TextStyle(color: Brand.muted))),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        for (final u in saved) PhotoTile(url: u),
                        for (var i = 0; i < fresh.length; i++) PhotoTile(path: fresh[i], onRemove: () => setState(() => fresh.removeAt(i))),
                        AddPhotoTile(onTap: _add, label: saved.isEmpty ? 'Add photo' : 'Replace photos'),
                      ],
                    ),
                  ]),
                ),
    );
  }
}
